# Security Architecture & Threat Model: Secure IoE Remote Door Access

## 1. Authentication Architecture

Authentication proves the identity of the human operator accessing the system.
- **Client Identification**: The Flutter application collects credentials (academic email and password) over an encrypted TLS connection.
- **Backend Verification**: Passwords are never verified client-side. The backend verifies credentials using slow hashing algorithms (Argon2id or bcrypt with high work factor).
- **Session Tokens**: Upon successful authentication, the backend issues a signed, cryptographically random JSON Web Token (JWT) access token with a strict expiration window (e.g., 15 minutes) and an HTTP-only/secure refresh token with rotation.
- **Explicit Invalidation**: Secure logout triggers backend token revocation and immediately purges all keys from the client platform keystore.

---

## 2. Biometric Authentication

### Operating-System Bound Security
The application specifically utilizes the **platform biometric subsystem** (`BiometricPrompt` on Android, `LocalAuthentication` / `LAContext` on iOS):
- **Zero Sensor Direct Access**: The Flutter application never touches the fingerprint scanner hardware directly.
- **Zero Template Transmission**: Fingerprint minutiae, optical scans, and 3D facial mesh templates remain inside the hardware **Secure Enclave / Trusted Execution Environment (TEE)** of the mobile phone.
- **Zero Biometric Database**: No biometric images or templates are collected, stored, or transmitted over the network.
- **Boolean Outcome Verification**: The application only receives high-level platform status: `SUCCESS`, `FAILURE`, `USER_CANCELLED`, `NOT_ENROLLED`, or `LOCKED_OUT`.

### Critical Biometric Clarification
> **WARNING**: Native mobile biometric authentication proves only that the physical phone holder matches the fingerprint registered on that specific handset. **It does NOT authorize door access.** Biometric confirmation on the phone is simply an additional authentication factor before command transmission; the backend server remains the sole authority for device authorization.

---

## 3. Authorization Model (Authentication vs. Authorization)

Authentication ("Who are you?") is strictly isolated from Authorization ("What are you allowed to do?"):
- **Role-Based Access Control (RBAC)**: Users are assigned privileges (e.g., `student`, `lab_technician`, `faculty_admin`).
- **Access Control Lists (ACL)**: Each physical door node (`deviceId`) maintains an explicit permissions matrix.
- **Server-Side Enforcement**: Even if a user successfully passes phone biometric authentication, the backend validates whether that specific user account holds `canOpen` or `canClose` permissions for that specific perimeter at that specific time of day.
- **Untrusted Client**: The client application UI reflects permissions to improve UX, but all requests are re-evaluated on the server. Tampering with client-side boolean flags will result in an immediate `403 Forbidden` from the API.

---

## 4. Token Handling & Lifecycle

- **Short-Lived Access Tokens**: Mitigates the risk of token interception.
- **Token Rotation**: Refresh tokens are single-use. Every refresh invalidates the previous refresh token.
- **Token Redaction**: Tokens are automatically scrubbed by `AppLogger` before any log write to prevent unintentional exposure in logcat or console output.
- **Header Injection**: Tokens are transmitted exclusively through standard `Authorization: Bearer <token>` headers over HTTPS.

---

## 5. Platform Secure Storage

All sensitive session identifiers, access tokens, and refresh tokens are stored using the operating system's hardware-backed key repository:
- **Android**: Handled via `FlutterSecureStorage` using `Android KeyStore` with RSA-OAEP key wrapping and hardware-backed AES-256 GCM encryption.
- **iOS**: Handled via iOS `Keychain Services` with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- **Prohibited Storage**: Plaintext `SharedPreferences`, SQLite databases, and unencrypted files are strictly banned for token and credential persistence.

---

## 6. Network Security

- **Transport Layer Security (TLS)**: All REST endpoints and MQTT communication require TLS 1.3 with strong cipher suites.
- **Android Network Security Config**: Enforces strict system certificate validation and cleartext traffic blocking (`cleartextTrafficPermitted="false"`). Local IP exceptions are strictly constrained to development intranet subnets.
- **Certificate Pinning Ready**: The architecture supports SHA-256 certificate pinning on the `HttpApiClient` layer for production deployments.

---

## 7. Device Authentication

Physical door latch controllers (ESP32) must be authenticated by the backend before receiving or acknowledging commands:
- **Unique Hardware Identity**: Every ESP32 possesses a unique factory-burned MAC address and a cryptographically generated node identity key.
- **Mutual Authentication (mTLS)**: The ESP32 authenticates to the backend broker using an X.509 client certificate stored in the ESP32 encrypted flash partition, or via pre-shared HMAC secret tokens.
- **No Public Endpoints**: The ESP32 does not run an open HTTP server on the public Internet. It connects outbound to the secure broker/gateway.

---

## 8. Remote Command Security

Direct communication between the mobile client and the physical ESP32 is explicitly prohibited:
- **No Direct App-to-ESP32 Path**: The mobile application NEVER connects directly to the ESP32.
- **Mediated Dispatch**: Commands must pass through the authenticated backend gateway.
- **End-to-End Command Structure**:
  ```json
  {
    "deviceId": "esp32_lab_door_01",
    "command": "OPEN",
    "requestId": "f81d4fae-7dec-11d0-a765-00a0c91e6bf6",
    "timestamp": "2026-10-06T07:30:00.000Z",
    "authenticationContext": "biometric_os_verified"
  }
  ```

---

## 9. Replay Attack Protection

To prevent an attacker from capturing an `OPEN` packet and replaying it to unlock the door at a later time:
1. **Cryptographic Nonce (`requestId`)**: Every command payload generates a unique UUID v4. The backend maintains an in-memory cache of recently processed request IDs (using Redis or ring cache) and rejects duplicates.
2. **Timestamp Window**: Payloads carry a UTC ISO8601 timestamp. The backend verifies that `|now - timestamp| < 60 seconds`. Commands outside this tolerance window are rejected immediately.
3. **Firmware Sequence Checking**: The backend increments a monotonic counter per device. The ESP32 drops any command whose sequence number is not strictly greater than the last executed command.

---

## 10. Audit Logging & Security Events

Security events are immutably logged for forensic accountability:
- **Logged Events**: Login attempts, failed authentications, biometric cancellations, door OPEN/CLOSE dispatches, authorization rejections, offline command drops.
- **Log Attributes**: Timestamp, User ID, Device ID, Operation, Result, Authentication Method, Request ID Nonce, Failure Reason.
- **Redaction Policy**: Passwords, full Authorization headers, cryptographic private keys, and biometric template data are systematically filtered and never written to logs.

---

## 11. Threat Model

| Threat | Attack Vector | Mitigation in Architecture |
| :--- | :--- | :--- |
| **Reverse Engineered APK** | Attacker modifies client code to skip biometric check or bypass role check | Backend verifies JWT and independently enforces device authorization. Client-side checks are purely for UX. |
| **Network Sniffing / Man-In-The-Middle** | Attacker intercepts Wi-Fi traffic in college lab | Strict TLS 1.3 encryption on all channels; certificate validation. |
| **Replay Attack** | Attacker captures valid OPEN HTTP request and re-sends it later | Request UUID nonce cache and strict 60-second UTC timestamp validation window. |
| **Physical ESP32 Tampering** | Attacker clips serial RX/TX pins or attempts to flash rogue firmware | ESP32 Flash Encryption & Secure Boot v2 enabled; limits switches provide physical state confirmation. |
| **Rogue Wi-Fi Access Point** | Fake lab Wi-Fi attempting DNS spoofing | Outbound TLS verification against root certificate authorities. |
| **Rapid Double Triggering** | User or automated script spams OPEN/CLOSE buttons | Client debouncing (<1500ms) + backend per-device command locking. |

---

## 12. Security Enforcement: Client vs. Backend

| Security Responsibility | Client (Flutter) | Backend API |
| :--- | :---: | :---: |
| Password verification | ❌ | ✅ |
| Role-Based Authorization (RBAC) | ❌ | ✅ |
| Device access permissions | ❌ | ✅ |
| Replay attack validation | ❌ | ✅ |
| Rate limiting & abuse protection | ❌ | ✅ |
| Biometric hardware prompt | ✅ | ❌ |
| Secure storage of access tokens | ✅ | ❌ |
| Request nonce generation | ✅ | ✅ (Validates) |
| UI state safety interlocks | ✅ | ❌ |

---

## 13. What the ESP32 is Trusted & NOT Trusted to Do

### What the ESP32 IS Trusted To Do:
1. Actuate the PWM signal controlling the physical servo motor when receiving an authentic, verified command from the backend.
2. Accurately report digital reed switch / limit switch status (whether the bolt is physically thrown or retracted).
3. Transmit periodic heartbeat telemetry packets.

### What the ESP32 is NOT Trusted To Do:
1. **Never decides user permissions**: The ESP32 does not manage user accounts, passwords, or access control matrices.
2. **Never accepts commands from arbitrary clients**: The ESP32 will drop any packet not originating from the trusted backend broker.
3. **Never connects to the public Internet without encryption**: All communications are encrypted and authenticated.
4. **Physical failure fails safe**: In the event of a power outage or microcontroller crash, the mechanical lock default state is spring-loaded **LOCKED** (fail-secure).
