# Bluetooth Attendance Tracker

Production-ready Flutter attendance app that uses BLE proximity for zero-friction student detection.

## Quick Start (Android First)

- Install Flutter (stable), Android SDK, and an Android 8.0+ physical device.
- From project root, run `flutter pub get`.
- Configure Firebase for Android:
  - Create a Firebase project.
  - Add Android app package and place `google-services.json` in `android/app/`.
  - Enable Firestore and Email/Password Auth in Firebase Console.
- Run `flutter run` on a physical Android device (BLE advertising/scanning is not reliable on emulators).
- Open app:
  - Create institution accounts (Admin/Teacher/Student) from auth screen.
  - Student device: sign in, register roll + name, enable readiness toggle.
  - Teacher device: sign in, select class, tap Start Attendance, then Mark & Save.

## iOS Notes

- Add iOS app in Firebase and place `GoogleService-Info.plist` in `ios/Runner/`.
- Enable Bluetooth background modes in Xcode capabilities:
  - Uses Bluetooth LE accessories.
  - Acts as a Bluetooth LE accessory.
- Run on a physical iPhone (BLE background behavior varies by iOS version/power mode).

## Permissions

The app asks for Bluetooth and nearby device permissions (and location where required by Android version).

Important Android note:

- For BLE discovery reliability, keep both Bluetooth ON and Location Services ON (device-level toggle), in addition to granting permissions.

## Architecture

- State management: Riverpod 2.0
- Local persistence: Hive
- Cloud sync: Firebase Firestore + Firebase Auth (email/password baseline)
- BLE: flutter_blue_plus (teacher scan + student advertise broadcast payload)
