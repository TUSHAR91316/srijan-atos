# Fake Call Detector

Privacy-first fake/spoofed call detection for Android, built with Flutter + Kotlin native integration.

All analysis is designed to run on-device. No call metadata or audio is sent to external servers.

## Project Structure

- `fake_call_detector/`: Main Flutter app (active project)
- `FakeCallDetector_Android/`: Earlier native Android prototype

## Current Capabilities

- Incoming call event relay through Android `CallScreeningService`
- Flutter dashboard with live threat state and capture controls
- Native audio capture service scaffold (speakerphone + mic workaround path)
- CI checks for pull requests (format, analyze, tests, coverage artifact)
- Security hardening baseline:
  - release signing guard (no debug release signing)
  - masked phone logging in debug only
  - permission + call-screening role gate before capture
  - reduced Android permission surface

## Tech Stack

- Flutter (Dart) UI
- Android Kotlin for telecom/audio integration
- GitHub Actions for CI

## Local Setup

### Prerequisites

- Flutter SDK `>= 3.10.4`
- Android Studio
- Android device/emulator (Android 10+ recommended)

### Run the app

```bash
cd fake_call_detector
flutter pub get
flutter run
```

### Run quality checks

```bash
cd fake_call_detector
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

## Release Signing Setup (Required for production builds)

1. Create a keystore file (`.jks` or `.keystore`).
2. Copy `fake_call_detector/android/key.properties.example` to:
   `fake_call_detector/android/key.properties`
3. Fill real values in `key.properties`:
   - `storeFile`
   - `storePassword`
   - `keyAlias`
   - `keyPassword`
4. Build release:

```bash
cd fake_call_detector
flutter build apk --release
```

If signing values are missing, release build fails intentionally.

## Pull Request Workflow

For PRs to `main`, `master`, or `develop`, GitHub Actions runs:

- formatting check
- static analysis
- test suite with coverage
- coverage artifact upload (`lcov.info`)

## Security

Please report vulnerabilities using the process in `.github/SECURITY.md`.
