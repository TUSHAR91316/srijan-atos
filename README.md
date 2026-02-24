# Fake Call Defender (On-Device Scam Detection)

A privacy-first mobile application that works entirely on the device to detect fake or spoofed calls claiming to originate from known or trusted contacts. 

Built as a submission for the Unstop Hackathon problem statement: **Detect Fake Calls from Well-Known Contacts**.

## 🛡️ Core Features & Constraints Met

The primary guardrail of this project is absolute privacy: **No call data, audio, or metadata leaves the device.**

*   **100% Local Processing:** Unlike traditional caller ID apps that upload address books or ping cloud servers, this app intercepts calls using Android's native `CallScreeningService`.
*   **Metadata Verification Engine:** Analyzes incoming caller IDs against saved contacts, looking for formatting anomalies, unexpected international codes disguised as local ones, or suspicious calling frequencies.
*   **Edge AI Ready (TFLite):** Architected to support local TensorFlow Lite models for real-time acoustic analysis (Liveness Detection) to detect AI-generated voices/deepfakes without recording the call audio to storage.

## 🏗️ Architecture Stack
*   **Platform:** Native Android (Kotlin)
*   **API:** `CallScreeningService` API (Requires Android 10+ / API Level 29)
*   **Machine Learning:** TensorFlow Lite (TFLite) for Edge AI models
*   **Storage:** Room Database (SQLite) for maintaining encrypted, local call logs and contact trust hashes.

## 🚀 Getting Started (Android Studio)

1.  Clone this repository or download the source code.
2.  Open **Android Studio**.
3.  Select **Open an existing Project**.
4.  Navigate to the `FakeCallDetector` directory (`f:\Project\Hackathon project\srijan atos\FakeCallDetector`) and select it.
5.  Wait for Gradle to sync the dependencies.
6.  Connect a physical Android device (Android 10+ recommended) via USB debugging or start an Android Emulator.
7.  Click the **Run 'app'** button (`Shift + F10`).

## ⚙️ How to Test
1.  Launch the app on your device.
2.  Click **Enable Local Screening**.
3.  The OS will prompt you to set "Fake Call Defender" as your default Caller ID & Spam App. **Accept this prompt**.
4.  Once enabled, use another phone (or an emulator control panel) to place a call mimicking a spoofed number (e.g., using international prefixes like `+44` for testing the dummy heuristic).
5.  The app will instantly block the call or flag it via the local Android Logcat logs without ever connecting to the internet
