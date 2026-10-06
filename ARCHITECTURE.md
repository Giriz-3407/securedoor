# System Architecture: Secure IoE Remote Door Access

## 1. High-Level System Overview

The **Secure IoE Remote Door Access** platform is an Internet of Everything (IoE) engineering system designed to remotely control and monitor physical door locking mechanisms with enterprise-grade security.

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Mobile Client                     │
│  - Android BiometricPrompt / iOS LocalAuthentication         │
│  - FlutterSecureStorage (KeyStore / Keychain AES-GCM)        │
│  - Clean Architecture & Riverpod Notifier State Flow         │
└──────────────────────────────┬──────────────────────────────┘
                               │ HTTPS (TLS 1.3)
                               │ Bearer JWT + X-Request-Id Nonce
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                   Secure Backend API Gateway                │
│  - Token Authentication & Expiration Verification            │
│  - Role-Based Access Control (RBAC) Device Authorization     │
│  - Request Idempotency & Replay Window Filter (< 60s)        │
│  - Immutable Audit & Security Activity Logging               │
└──────────────────────────────┬──────────────────────────────┘
                               │ MQTT over TLS (mTLS) / WSS
                               │ Cryptographically Signed Command
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 ESP32 Physical IoT Node                      │
│  - Secure Boot & Hardware Crypto Acceleration                │
│  - Pre-shared Hardware HMAC / ED25519 Signature Verification │
│  - Heartbeat Telemetry & State Reporting Loop                │
└──────────────────────────────┬──────────────────────────────┘
                               │ Hardware Pulse-Width Modulation (PWM)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│             Servo Motor & Mechanical Door Latch             │
│  - High-Torque Servo Actuator                                │
│  - Limit Switch / Reed Switch Optical Position Feedback      │
│  - Physical Door Strike Latch                                │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Flutter Mobile Application Architecture

The mobile application is structured around **Clean Architecture** principles and **Domain-Driven Design (DDD)**, dividing concerns into three isolated layers:

```
lib/
├── core/
│   ├── config/               # AppConfig, Environment resolution, Mock flags
│   ├── constants/            # App constants, secure storage keys, timeouts
│   ├── errors/               # Domain Failure hierarchy (Auth, Network, Biometric, etc.)
│   ├── logging/              # Centralized sanitizer logger (redacts PII/tokens)
│   ├── networking/           # ApiClient, HTTP client abstraction, error status mappers
│   ├── providers/            # Riverpod Dependency Injection registry
│   ├── security/             # OS BiometricService abstraction & local_auth adapter
│   ├── storage/              # SecureStorageService (EncryptedSharedPreferences / Keychain)
│   ├── theme/                # High-contrast engineering UI styling
│   └── utils/                # Result<T> functional algebraic error wrapper
│
├── features/
│   ├── authentication/
│   │   ├── domain/           # User model, LoginCredentials, AuthRepository interface
│   │   ├── data/             # AuthRepositoryImpl (REST API) & MockAuthRepository
│   │   └── presentation/     # AuthNotifier, LoginScreen, biometric unlock
│   │
│   ├── devices/
│   │   ├── domain/           # Device, DoorState, LatchState, DeviceRepository interface
│   │   ├── data/             # DeviceRepositoryImpl & MockDeviceRepository
│   │   └── presentation/     # DeviceListNotifier, DeviceListScreen, DeviceDetailScreen
│   │
│   ├── access_control/
│   │   ├── domain/           # DoorCommandPayload, ExecutionStage, AccessControlRepository
│   │   ├── data/             # AccessControlRepositoryImpl & MockAccessControlRepository
│   │   └── presentation/     # CommandController, CommandConfirmationSheet, ProgressDialog
│   │
│   └── activity/
│       ├── domain/           # ActivityLog, OperationStatus, ActivityRepository interface
│       ├── data/             # ActivityRepositoryImpl & MockActivityRepository
│       └── presentation/     # ActivityNotifier, ActivityLogScreen
│
└── shared/
    └── widgets/              # StatusPill, DoorGraphicWidget, MockBanner, Dialogs
```

### Key Architectural Rules
1. **No UI-Coupled Business Logic**: Widgets only consume state and dispatch intents to Riverpod `Notifier` classes.
2. **Result Functional Type**: Methods in repository layers return `Result<T>` (`Success<T>` or `Error<T>`), guaranteeing zero uncaught exceptions propagating up the UI stack.
3. **Pluggable Repositories**: The system can switch between `Mock` repositories and production `REST/API` repositories at startup using `AppConfig.isMockMode`.

---

## 3. Remote Command Lifecycle & UX Safety State Machine

Accidental operations on physical doors carry real-world safety hazards. The application mandates a multi-stage execution pipeline:

```
[ User Taps OPEN/CLOSE ]
           │
           ▼
[ Accidental Double-Tap Debounce Check (<1500ms) ]
           │
           ▼
[ Offline Guard: Is Target Device Online? ]
           ├── NO  ──► Abort & Alert: "Device Offline. Remote command rejected."
           │
           └── YES
                ▼
[ User Safety Confirmation Modal ]
           │
           ▼
[ Mobile OS BiometricPrompt (Fingerprint / Face Unlock) ]
           ├── CANCELLED / FAILED ──► Abort & Reset State
           │
           └── SUCCESS (OS Verified)
                ▼
[ Generate Secure Payload: UUID v4 Nonce + UTC Timestamp ]
                ▼
[ STAGE 1: Sending Command to Backend API ]
                ▼
[ STAGE 2: Server Acknowledged & Authorization Verified ]
                ▼
[ STAGE 3: ESP32 Actuating Physical Servo Latch ]
                ▼
[ STAGE 4: Physical Reed Switch / Limit Sensor Confirmed ]
                ▼
[ Audit Log Created & Device State UI Refresh ]
```

---

## 4. Hardware Node & ESP32 Integration Model

The physical door latch actuation is driven by an ESP32 microcontroller:

### Hardware Specifications
- **Controller**: ESP32-WROOM-32 (Dual Core 240 MHz, Wi-Fi 802.11 b/g/n, Bluetooth v4.2 BR/EDR and BLE).
- **Actuator**: High-Torque Metal-Gear Servo (MG996R or DS3218) operating at 5V.
- **Physical Feedback**: Digital Magnetic Reed Switch / Microswitch on the door strike plate to detect physical bolt engagement.
- **Power Subsystem**: Independent 5V 2A regulator for the servo motor with common ground to prevent voltage drops on the ESP32 logic rail during motor in-rush current.

### ESP32 Firmware Communication Modes
1. **MQTT over TLS**:
   - ESP32 subscribes to `ioe/devices/{deviceId}/commands`.
   - ESP32 publishes periodic heartbeats and state transitions to `ioe/devices/{deviceId}/status`.
2. **Validation on ESP32**:
   - Validates command timestamp against its NTP-synchronized real-time clock (rejects older than 60 seconds).
   - Validates cryptographic HMAC signature generated by the trusted backend.
   - Executes PWM pulse: `1000 µs` (Locked) to `2000 µs` (Unlocked).
   - Confirms limit switch contact before reporting `CONFIRMED` back to the backend.

---

## 5. Mock vs. Production Switching

To allow engineering students to demonstrate the application without setting up cloud infrastructure and physical motors:

| Feature | Mock Mode (`MOCK_MODE=true`) | Production Mode (`MOCK_MODE=false`) |
| :--- | :--- | :--- |
| **Authentication** | `MockAuthRepository` (local mock tokens) | `AuthRepositoryImpl` (POST `/auth/login`) |
| **Device Listing** | `MockDeviceRepository` (pre-configured nodes) | `DeviceRepositoryImpl` (GET `/devices`) |
| **Remote Commands**| `MockAccessControlRepository` (simulated PWM transit) | `AccessControlRepositoryImpl` (POST `/devices/{id}/command`) |
| **Audit Logs** | `MockActivityRepository` (in-memory ring buffer) | `ActivityRepositoryImpl` (GET `/activity-logs`) |
| **Biometric Auth** | OS Native prompt if available, fallback simulation | OS Native `LocalAuthentication` prompt |
| **Visual Banner** | Amber "DEMO / LAB SIMULATION MODE" banner | Clean production UI |

Switching requires only setting the compile-time flag:
```bash
flutter run --dart-define=MOCK_MODE=false --dart-define=API_BASE_URL=https://api.yourdomain.com/v1
```
No Flutter UI or business logic needs to be modified.
