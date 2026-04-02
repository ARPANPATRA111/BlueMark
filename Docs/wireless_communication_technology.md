# Wireless Communication Technology in BlueMark

## 1) Problem Statement

Manual attendance is slow, error-prone, and easy to manipulate when done with paper sheets, QR screenshots, or one-time codes.

What this app is trying to achieve:

- Mark classroom attendance automatically with minimal friction.
- Avoid long queues and repeated manual entry.
- Work even when internet is unstable.
- Keep attendance data tenant-scoped and role-controlled.
- Give both teacher and student live visibility of attendance state.

In simple terms:

- Student phone says "I am here" over short-range wireless.
- Teacher phone listens and collects nearby student identities.
- Teacher confirms and saves.
- Data syncs safely to cloud and appears in student timeline.

---

## 2) Why BLE Is Used (Wireless Choice)

The app uses Bluetooth Low Energy (BLE) as the primary wireless channel because it is:

- Available on almost all phones.
- Low power compared to classic Bluetooth.
- Suitable for short-range presence detection in classrooms.
- Fast enough for repeated scan/advertise cycles.

The app does not rely on phone-to-phone pairing. It uses BLE advertisement packets, which are lightweight broadcast frames.

---

## 3) End-to-End Application Architecture

### 3.1 Student Side

- Registers profile (roll number, name, optional photo).
- Enables readiness toggle.
- Starts BLE advertising through native bridge.
- Receives attendance status updates from cloud.

### 3.2 Teacher Side

- Starts attendance session for a class.
- Scans BLE broadcasts in real time.
- Reviews detected list, applies manual corrections.
- Saves attendance and closes active session.

### 3.3 Admin and Tenant Layer

- Tenant-scoped user and class management.
- Role-based access model (`admin`, `teacher`, `student`).
- Firestore rules + indexes support multi-tenant boundaries.

### 3.4 Local + Cloud Data Strategy

- Local first: Hive is used for profile, sessions, directory, and attendance buffer.
- Cloud sync: Firestore + Firebase Auth.
- If network is unavailable, attendance is still saved locally and retried later.

---

## 4) BLE Protocol Design (Core Wireless Technology)

## 4.1 Wireless Identifiers

- Service UUID: `0000A77E-0000-1000-8000-00805F9B34FB`
- Manufacturer ID: `0x0A77`
- Payload prefix: `BAT:`

## 4.2 Payload Format

Current payload format:

`BAT:<ROLL>|<SLOT>|<SIGNATURE>`

Where:

- `ROLL`: normalized student roll number (uppercase).
- `SLOT`: time slot in base-36 (`now / 20 seconds`).
- `SIGNATURE`: first 10 chars of SHA-256 over `ROLL|SLOT|SECURITY_KEY`.

This provides short-lived tokens and basic anti-replay behavior.

## 4.3 Verification Logic

Teacher-side decoding:

1. Extract manufacturer data bytes.
2. Decode string payload.
3. Validate signature with shared security key.
4. Accept slot within tolerance window (default tolerance: 1 slot).
5. If signed payload fails and fallback is enabled, parse legacy roll format.

## 4.4 Native Advertising Bridge

The app uses Flutter MethodChannel `attendance_ble_advertiser`:

- Dart asks native layer to start/stop advertising and fetch runtime status.
- Android runs a foreground service (`BleAdvertiseService`) for higher reliability.
- iOS uses `CBPeripheralManager` for advertising and state callbacks.

---

## 5) Detailed Runtime Flow

## 5.1 Student Readiness Flow

1. Student enables readiness.
2. Permission checks run (Bluetooth, location requirements on Android, notifications).
3. BLE advertising starts.
4. Health polling runs every 5 seconds.
5. If advertiser is down for consecutive checks, app auto-restarts advertising.

## 5.2 Teacher Scanning Flow

1. Teacher starts session and scan.
2. Scanner filters by manufacturer data and RSSI threshold.
3. Each packet is decoded and verified.
4. Detected map is updated by roll number.
5. Stale entries are removed after timeout window.
6. UI refreshes every 3 seconds with diagnostics.

## 5.3 Save and Sync Flow

1. Teacher confirms final list (auto + manual edits).
2. Attendance record is saved locally with audit entries.
3. Session is closed.
4. Sync pushes records to Firestore collections.
5. Student timeline/status streams update in real time.

---

## 6) Reliability Engineering in Wireless Layer

### 6.1 Noise and Distance Handling

- RSSI threshold is configurable (`minRssi`).
- Stale detection removes disappeared devices after configurable timeout.
- Max tracked student cap avoids unbounded memory growth.

### 6.2 Recovery Behavior

- Student advertiser health monitor auto-recovers failures.
- Teacher scan attempts recovery if scanning unexpectedly stops.
- Local-first save prevents data loss when internet drops.

### 6.3 Platform Constraints (Important)

Android:

- BLE scanning requires Bluetooth ON and Location Services ON.
- Runtime permission alone is not always sufficient.
- Foreground service improves background advertiser survival.

iOS:

- BLE behavior in background is stricter and system-managed.
- Advertising can be reduced/throttled depending on OS power state.

---

## 7) Security Model for Wireless + Data

### 7.1 Current Security Controls

- Signed BLE payload using shared key + rolling slot.
- Tenant-scoped Firestore collections.
- Role-based restrictions for admin/teacher/student operations.
- Session-aware attendance updates.

### 7.2 Current Security Gaps

- Shared key model is static unless manually rotated in settings.
- Signature length is intentionally short for payload size constraints.
- No backend nonce challenge yet.
- No device attestation gate yet.

### 7.3 Planned Security Hardening

- SSO/federation and MFA controls.
- Server-issued nonce challenge for stronger anti-replay.
- Device trust checks (Play Integrity / DeviceCheck).
- Tamper-evident audit chain.

---

## 8) Cloud and Collection-Level Data View

Main Firestore paths (tenant-scoped):

- `users/{uid}`
- `tenants/{tenantId}/students/{roll}`
- `tenants/{tenantId}/attendance/{recordId}`
- `tenants/{tenantId}/attendance_receipts/{receiptId}`
- `tenants/{tenantId}/active_sessions/{classId}`

Data lifecycle:

- Local create first.
- Cloud sync second.
- Student timeline stream consumes receipt records.

---

## 9) Product Progress Status

## 9.1 Implemented and Working

- BLE student advertising and teacher scanning.
- Signed payload decode/verify path.
- Session creation, duplicate-warning flow, and close-session flow.
- Manual override support in teacher review sheet.
- Offline-first attendance buffer with later sync.
- Real-time student status/timeline updates.
- Multi-tenant role-aware Firebase structure.

## 9.2 Partially Implemented / Operationally Sensitive

- Security key is configurable but requires disciplined rotation.
- BLE reliability depends on OEM battery/location policies.
- Cloud sync retries exist, but failure observability can be improved.

## 9.3 Next Progress Milestones

- Enterprise identity and stronger auth controls.
- Nonce-based attendance handshake.
- Better admin observability and analytics.
- Broader hardware-matrix reliability testing.

---

## 10) Practical Deployment Guidance

For stable classroom operation:

- Use physical devices (not emulators).
- Keep Bluetooth ON on both student and teacher devices.
- Keep Android Location Services ON for scanner devices.
- Disable aggressive battery restrictions for this app.
- Test with real classroom density before institution-wide rollout.

---

## 11) Credential Safety Incident Handling (Current)

A Firebase Android config file (`google-services.json`) was exposed previously in a public commit.

Remediation direction in repository:

- Track-safe template is provided at `android/app/google-services.example.json`.
- Real `android/app/google-services.json` is now intended to be local-only.
- Git ignore rules were hardened to block this and related credential files.

Operational reminder:

- Any leaked API/service credential must be rotated or revoked in Google Cloud/Firebase Console.
- History rewrite and force-push are required to remove leaked artifacts from public commit history.

---

## 12) Quick Glossary

- BLE: Bluetooth Low Energy, short-range low-power wireless.
- RSSI: Signal strength indicator used for proximity filtering.
- Manufacturer Data: BLE payload section used here for roll token transport.
- Rolling Slot: Time window used to produce short-lived signatures.
- Tenant: Institution-level data partition.
- Receipt: Student-facing attendance record generated during sync.
