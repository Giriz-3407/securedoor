# Secure IoE Remote Door Access

An Internet of Everything (IoE) engineering mobile application built with Flutter to securely control and monitor physical door locking mechanisms via an ESP32 microcontroller and servo motor.

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [End-to-End System Architecture](#end-to-end-system-architecture)
3. [Features](#features)
4. [Technology Stack](#technology-stack)
5. [Folder Structure](#folder-structure)
6. [Setup Instructions](#setup-instructions)
7. [Running the Project](#running-the-project)
8. [Environment Configuration](#environment-configuration)
9. [Android Setup & Permissions](#android-setup--permissions)
10. [Biometric Authentication Behavior](#biometric-authentication-behavior)
11. [Mock Mode & Demo Features](#mock-mode--demo-features)
12. [Project Demonstration Walkthrough](#project-demonstration)
13. [Backend Integration Guide](#backend-integration-guide)
14. [Future ESP32 Integration](#future-esp32-integration)
15. [Security Architecture Summary](#security-architecture-summary)

---

## Project Overview

The primary purpose of this engineering project is **REMOTE CONTROL OF A PHYSICAL DEVICE** (mechanical door latch actuated by a servo motor driven by an ESP32 microcontroller).

The security and authentication system is a critical supporting feature, ensuring that:
- Physical door latch operations are treated as high-security, sensitive events.
- Device operating system biometric authentication (fingerprint/face recognition) gates physical dispatches.
- Client applications cannot bypass authorization checks.
- Duplicate or replayed commands are rejected.
- Physical device states are clearly distinguished from command transmission states.

---

## End-to-End System Architecture

```
Flutter Mobile App
       ↓ (HTTPS TLS 1.3 / JWT + Nonce)
Backend API Gateway
       ↓ (MQTT over TLS / mTLS)
ESP32 Microcontroller Node
       ↓ (PWM Signal)
Servo Motor Actuator
       ↓ (Mechanical Coupling)
Physical Door Latch
```

For complete architectural details, see [ARCHITECTURE.md](file:///c:/Users/Girish/Desktop/ioe%20project/ARCHITECTURE.md).  
For the complete security model and threat analysis, see [SECURITY.md](file:///c:/Users/Girish/Desktop/ioe%20project/SECURITY.md).

---

## Features

- **Session Authentication**: Secure academic login with encrypted credential storage.
- **Registered Perimeter Overview**: Real-time list of assigned door nodes with connectivity and latch indicators.
- **Physical Device Telemetry**:
  - Node connectivity (Online / Offline)
  - Mechanical latch state (Locked / Unlocked / Transitioning)
  - Door strike position (Closed / Open / Unknown)
  - Hardware firmware version & local node IP
- **Biometric Protection**: Hardware-backed fingerprint / Face ID confirmation before any OPEN or CLOSE command.
- **Accidental Actuation Prevention**: Confirmation modal, debouncing (<1500ms), and in-flight operation locking.
- **Offline Safety Interlock**: Completely disables remote commands when an ESP32 heartbeat is absent, preventing phantom actuation signals.
- **State Progression Feedback**: Clear distinction between:
  1. `Sending Command`
  2. `Server Acknowledged`
  3. `ESP32 Actuating Servo`
  4. `Physical State Confirmed`
- **Security Audit Trail**: Real-time chronological activity log recording timestamps, request IDs, operations, and authentication methods.
- **Instant Demo Mode**: Fully functional mock repository layer allowing comprehensive demonstration on any emulator or physical phone without cloud servers.

---

## Technology Stack

- **Framework**: Flutter 3.47+ (Dart 3.13+)
- **State Management**: Flutter Riverpod 3.x (`NotifierProvider`, `Notifier`)
- **Biometric Authentication**: `local_auth` (OS-level Android BiometricPrompt & iOS LocalAuthentication)
- **Secure Key Storage**: `flutter_secure_storage` (Android KeyStore AES-GCM & iOS Keychain)
- **Networking**: `http` with centralized `ApiClient` abstraction
- **Cryptography & Utilities**: `uuid` (UUID v4 cryptographic request nonces), `intl`
- **Testing**: `flutter_test` unit and widget test suites

---

## Monorepo Project Structure

```text
securedoor/
├── frontend/             # Flutter mobile client application
│   ├── lib/              # Clean Architecture (Domain, Data, Presentation)
│   ├── android/          # Android native platform code & permissions
│   ├── ios/              # iOS platform configuration
│   └── pubspec.yaml      # Flutter dependencies & assets
│
├── backend/              # Node.js + Express + WebSockets + MongoDB Atlas server
│   ├── server.js         # REST API & real-time hardware WebSocket broker
│   ├── package.json      # Node.js dependencies
│   └── .env.example      # Environment variables template
│
├── firmware/             # ESP32 Embedded Microcontroller Firmware
│   └── esp32_door_lock/  # Arduino IDE project
│       └── esp32_door_lock.ino
│
├── ARCHITECTURE.md       # Complete system architecture specification
├── SECURITY.md           # Cryptographic & physical threat model
└── README.md             # Project documentation
```

### Mobile App (`frontend/lib/`) Architecture

```
frontend/lib/
│   │   ├── data/            # AccessControlRepositoryImpl & MockAccessControlRepository
│   │   └── presentation/    # CommandController, CommandConfirmationSheet, ProgressDialog
│   │
│   └── activity/
│       ├── domain/          # ActivityLog, OperationStatus, ActivityRepository
│       ├── data/            # ActivityRepositoryImpl & MockActivityRepository
│       └── presentation/    # ActivityNotifier, ActivityLogScreen
│
├── shared/
│   └── widgets/             # StatusPill, DoorGraphicWidget, MockBanner
└── main.dart                # Application entrypoint & ProviderScope
```

---

## Setup Instructions

### Prerequisites
1. Flutter SDK 3.24+ installed and configured on your system.
2. Android Studio / VS Code with Flutter extension.
3. For Android build: Android SDK Platform 34+, Java JDK 17.

### Installation
Clone or navigate to the project directory:
```bash
cd "c:\Users\Girish\Desktop\ioe project"
flutter pub get
```

Run static analysis and tests:
```bash
flutter analyze
flutter test
```

---

## Running the Project

### Running in Mock/Demo Mode (Default)
Runs immediately without any backend or ESP32 hardware required:
```bash
flutter run
```

### Running in Production/Backend Connected Mode
Pass your backend API URL and disable mock mode:
```bash
flutter run --dart-define=MOCK_MODE=false --dart-define=API_BASE_URL=https://api.yourdomain.com/v1
```

---

## Environment Configuration

A configuration template is provided in [.env.example](file:///c:/Users/Girish/Desktop/ioe%20project/.env.example).

| Variable | Description | Default |
| :--- | :--- | :--- |
| `ENV` | Environment name (`development`, `testing`, `production`) | `development` |
| `API_BASE_URL` | Base URL for REST backend | `https://api.secure-access.internal/v1` |
| `MOCK_MODE` | Boolean flag toggling mock repositories | `true` |

---

## Android Setup & Permissions

The Android application is configured under the **Principle of Least Privilege**:
- **Permissions Declared in `AndroidManifest.xml`**:
  ```xml
  <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
  <uses-permission android:name="android.permission.INTERNET"/>
  ```
  *(Zero unnecessary permissions: NO camera, NO microphone, NO contacts, NO background location).*
- **`MainActivity.kt`**: Extends `FlutterFragmentActivity` to support Android `BiometricPrompt`.
- **Minimum SDK**: Configured with `minSdk = 23` in `android/app/build.gradle.kts` to guarantee hardware Keystore and BiometricPrompt support.
- **Network Security**: `android/app/src/main/res/xml/network_security_config.xml` enforces strict TLS with isolated intranet support for local laboratory Wi-Fi testing.

---

## Biometric Authentication Behavior

The app uses the phone's native biometric capabilities:
- **Never collects or stores raw fingerprint or facial data.**
- Triggers the OS `BiometricPrompt` dialog when an operator requests sensitive operations (`OPEN` or `CLOSE`).
- Returns only high-level status: `SUCCESS`, `FAILURE`, or `USER_CANCELLED`.
- Biometrics verify the phone holder's identity, while the **backend independently verifies whether the user is authorized** to operate that specific door.

---

## Mock Mode & Demo Features

When `MOCK_MODE=true`, the app provides four demonstration profiles:

1. **LAB DOOR 01**:
   - Status: Online, Locked, Closed.
   - Permissions: Full Open/Close access.
   - Used to demonstrate: Normal biometric authorization, servo actuation stages, and transition to Open/Unlocked.
2. **RESEARCH LAB 02**:
   - Status: Online, Unlocked, Open.
   - Permissions: Full Open/Close access.
   - Used to demonstrate: Closing and locking the latch.
3. **SERVER ROOM ACCESS**:
   - Status: **Offline**.
   - Used to demonstrate: Safety interlock. Disables OPEN/CLOSE and protects against commands to unreachable hardware.
4. **RESTRICTED ARCHIVE**:
   - Status: Online, Locked.
   - Permissions: **Unauthorized** (`canOpen: false`).
   - Used to demonstrate: Backend authorization rejection (`403 Forbidden`).

---

## Project Demonstration Walkthrough

### Demonstration Phase A: Remote Command Flow (App → Physical Latch)
```
1. Operator launches app & logs in with Operator Profile.
2. Operator selects "LAB DOOR 01" (Online, Locked).
3. Operator taps "OPEN".
4. App presents Safety Confirmation Dialog:
   "Confirm Door Operation: LAB DOOR 01 (Requires device biometric verification)".
5. Operator confirms → OS Biometric Prompt appears ("Authenticate to open LAB DOOR 01").
6. Operator touches fingerprint sensor.
7. Biometric verification succeeds on handset.
8. App enters Command Execution Pipeline:
   - "Sending command to secure server..." (POST with UUID nonce + timestamp)
   - "Server verified authorization. Forwarding to ESP32..."
   - "ESP32 pulse active. Physical servo latch actuating..." (PWM signal rotated to 90°)
   - "Physical latch state verified!" (Reed switch contact confirmed)
9. Graphic changes to Green/Unlocked, and audit record is committed to Activity Log.
```

### Demonstration Phase B: Telemetry & State Reporting (ESP32 → App)
```
1. Physical door limit sensor detects bolt movement or manual key override.
2. ESP32 publishes updated status payload over MQTT:
   { "deviceId": "esp32_lab_door_01", "latchState": "LOCKED", "doorState": "CLOSED" }
3. Backend ingests payload and updates database.
4. Mobile application refreshes status via REST or WebSocket.
5. Mobile UI updates in real time.
```

---

## Backend Integration Guide

To connect the application to your production or cloud backend:

1. **Implement Backend Endpoints**:
   - `POST /auth/login`: Accepts email/password, returns `{ "accessToken": "...", "refreshToken": "...", "user": {...} }`.
   - `GET /auth/me`: Validates Bearer token and returns current user info.
   - `POST /auth/logout`: Revokes session token.
   - `GET /devices`: Returns list of registered devices for the authenticated user.
   - `GET /devices/:id`: Returns single device telemetry.
   - `POST /devices/:id/command`: Accepts `DoorCommandPayload` JSON and dispatches to ESP32.
   - `GET /activity-logs`: Returns audit history.
2. **Switch Flutter to Production Mode**:
   Set `MOCK_MODE=false` in `AppConfig` or compile with:
   ```bash
   flutter run --dart-define=MOCK_MODE=false --dart-define=API_BASE_URL=https://your-api.com/v1
   ```

No changes to UI or presentation controllers are needed.

---

## Future ESP32 Integration

1. **Hardware Assembly**:
   - Connect Servo Signal (Orange/Yellow) to ESP32 **GPIO 18** (PWM channel 0).
   - Connect Limit Switch COM to **GND** and NO to **GPIO 19** (configured with internal pull-up `INPUT_PULLUP`).
   - Power servo with dedicated 5V 2A regulator; tie common grounds together.
2. **Firmware Sketch Essentials**:
   - Connect to campus Wi-Fi with WPA2-Enterprise or WPA2-PSK.
   - Connect to MQTT broker with TLS on port 8883.
   - On incoming command, verify timestamp (< 60s) and HMAC signature.
   - Trigger servo sweep (`servo.write(0)` for locked, `servo.write(90)` for unlocked).
   - Read GPIO 19 limit switch and publish confirmation to `ioe/devices/{id}/status`.

---

## Security Architecture Summary

For full details, consult [SECURITY.md](file:///c:/Users/Girish/Desktop/ioe%20project/SECURITY.md).
- **Client is Untrusted**: Reverse engineering the APK cannot grant unauthorized door access; the backend re-verifies every permission.
- **Tokens are Hardware-Protected**: Zero plaintext credential storage; uses Android KeyStore and iOS Keychain.
- **Replay Proof**: Unique UUID v4 nonces and UTC timestamps for each command.
- **Safe Production Logging**: Centralized `AppLogger` scrubs authorization headers, passwords, and tokens from logs.
