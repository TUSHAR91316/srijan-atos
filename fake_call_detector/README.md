# 📱 Fake Call Detector

An **on-device AI-powered Android app** built with **Flutter + Kotlin** that detects fake and spoofed incoming calls in real time — with zero data leaving the device.

> 🏆 Built for the **Srijan ATOS Hackathon 2026**

---

## ✨ Features

| Feature | Description |
|---|---|
| 📞 **Call Interception** | Uses `CallScreeningService` to evaluate every incoming call before it rings |
| 🎤 **Non-Root Audio Workaround** | Forces speakerphone + captures MIC to analyse call audio on Android 10+ without root |
| 🧠 **On-Device AI** | Pluggable TFLite model slot for AI/deepfake voice detection |
| 🔒 **100% Private** | All analysis runs locally — no cloud, no telemetry |
| 🌙 **Premium Dark UI** | Material 3 dark theme with live threat-level pulse animations |

---

## 🏗️ Architecture

```
Flutter (Dart)
├── lib/main.dart               # App entry, Material 3 theme
├── lib/screens/dashboard.dart  # Real-time threat dashboard UI
└── lib/services/native_bridge.dart  # Platform channel wrapper

Android (Kotlin)
├── MainActivity.kt             # MethodChannel + EventChannel setup
├── CallScreeningServiceImpl.kt # Intercepts calls, relays to Flutter
└── AudioCaptureService.kt      # Speakerphone + MIC capture workaround
```

---

## 🛠️ Non-Rooted Audio Capture Workaround

Android 10+ blocks direct call audio capture (`VOICE_CALL`, `VOICE_DOWNLINK`) without root. This app uses a clever workaround:

1. When a call is answered, the app forces **Speakerphone** ON via `AudioManager`.
2. The device's **Microphone** picks up both the outgoing and incoming audio.
3. The PCM audio buffer is streamed locally into the **TFLite AI engine** for analysis.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `>=3.10.4`
- Android device running **Android 10+**
- The app must be granted the **"Caller ID & Spam"** role (Settings → Apps → Phone → Caller ID & Spam)

### Run
```bash
flutter pub get
flutter run            # debug
flutter build apk --release  # production
```

### Permissions Required
- `READ_CONTACTS` — to verify if a caller is in your contacts
- `READ_CALL_LOG` — for post-call anomaly analysis
- `RECORD_AUDIO` — for the speakerphone + MIC capture workaround
- `MODIFY_AUDIO_SETTINGS` — to force speakerphone mode
- `BIND_SCREENING_SERVICE` — to intercept calls via `CallScreeningService`

---

## 📦 Download

A pre-built release APK is available at:
```
fake_call_detector/build/app/outputs/flutter-apk/app-release.apk
```

---

## 🧪 Testing

1. Install the APK on a physical Android 10+ device.
2. Grant all required permissions.
3. Set the app as the **Default Caller ID & Spam** app.
4. Call the device from another phone — the dashboard will detect the call and engage the audio analysis workaround automatically.

---

## 📄 License

This project was created for hackathon purposes. All on-device processing ensures user privacy is preserved at all times.
