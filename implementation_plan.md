# Fake Call Detection Application Plan

The objective is to build a mobile application that works entirely on the device to detect fake or spoofed calls claiming to originate from known or trusted contacts, with the strict constraint that no call data, audio, or metadata leaves the device.

## Proposed Approach & Tech Stack

Given the deep system integration required to intercept and analyze calls before they ring (or as they ring), **Native Android (Kotlin)** is the recommended platform. Android provides the `CallScreeningService` API, which allows apps to evaluate incoming calls and block them or provide caller ID information without sending data off-device. iOS has `CallKit`, but it is much more restrictive regarding real-time call analysis.

**Tech Stack:**
- **Platform:** Android (Kotlin)
- **Call API:** `CallScreeningService` for receiving incoming call broadcasts.
- **On-Device ML / Heuristics:** TensorFlow Lite (TFLite) or simple heuristic algorithms deployed locally to evaluate calls.
- **Local Storage:** Room Database (SQLite) for storing contact trust scores or localized call logs without syncing to any cloud.

## Implementation Steps

### 1. App Setup & Permissions
- Create a new Android project.
- Request necessary permissions: `READ_CONTACTS`, `READ_CALL_LOG` (optional, for post-call analysis), and role request for `ROLE_CALL_SCREENING`.

### 2. Contact Verification Engine
- Build a local service that securely hashes or accesses local contacts to establish a baseline of "known/trusted" numbers.
- Implement heuristic checks:
  - Is the incoming number strictly matching a saved contact or is it a slight variation (e.g., different country code but same local digits)?
  - STIR/SHAKEN validation (if exposed by the carrier to the API level in modern Android versions, though often limited).
  - Calling pattern anomalies (e.g., getting a call from a known contact via an unusual network type or hidden caller ID anomalies).

### 3. Audio Analysis (Stretch Goal)
- If the problem statement implies detecting *deepfakes/AI voices* of known contacts during a call (rather than just spoofed caller ID), we would need to capture device audio locally via `AudioRecord` (if permitted by Android's strict call recording policies) and run a lightweight TFLite model to detect AI-generated voice artifacts. *Note: Android heavily restricts call audio recording on modern APIs for privacy reasons, so this may require specific workarounds or accessibility services.*

### 4. UI/UX
- A simple dashboard showing recent blocked/flagged calls.
- Settings to adjust the sensitivity of the AI/heuristics.
- In-call UI overlays (if possible) warning the user "This call mimics a known contact but seems suspicious."

## User Review Required

> [!IMPORTANT]
> Since audio recording during calls is heavily restricted on modern Android versions (Android 10+), detecting *voice deepfakes* of known contacts locally is technically challenging without rooting or relying on complex workarounds. 
> 
> Does the challenge expect you to analyze the **Caller ID/Network metadata** to detect spoofing, or does it expect you to analyze the **actual audio/voice of the caller** in real-time to detect AI voices?

## Verification Plan
1. **Automated Tests:** Unit tests for the heuristic engine (mocking incoming intent bundles).
2. **Manual Verification:** Build the APK, install it on a physical test device. Use an online SIP/VoIP service to call the device while spoofing a local contact's number (many ethical hacking services allow this for testing) to confirm the app intercepts and flags it.
