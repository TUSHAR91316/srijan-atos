import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/call_event.dart';
import '../services/detection_service.dart';
import '../services/native_bridge.dart';

enum ThreatLevel { safe, warning, danger }

class DashboardState {
  const DashboardState({
    this.latestEvent = 'Monitoring for incoming calls…',
    this.callerNumber = '',
    this.latestReason = '',
    this.latestReasons = const <String>[],
    this.trustedContactCount = 0,
    this.isAudioCapturing = false,
    this.threatLevel = ThreatLevel.safe,
    this.riskProbability = 0,
  });

  final String latestEvent;
  final String callerNumber;
  final String latestReason;
  final List<String> latestReasons;
  final int trustedContactCount;
  final bool isAudioCapturing;
  final ThreatLevel threatLevel;
  final double riskProbability;

  DashboardState copyWith({
    String? latestEvent,
    String? callerNumber,
    String? latestReason,
    List<String>? latestReasons,
    int? trustedContactCount,
    bool? isAudioCapturing,
    ThreatLevel? threatLevel,
    double? riskProbability,
  }) {
    return DashboardState(
      latestEvent: latestEvent ?? this.latestEvent,
      callerNumber: callerNumber ?? this.callerNumber,
      latestReason: latestReason ?? this.latestReason,
      latestReasons: latestReasons ?? this.latestReasons,
      trustedContactCount: trustedContactCount ?? this.trustedContactCount,
      isAudioCapturing: isAudioCapturing ?? this.isAudioCapturing,
      threatLevel: threatLevel ?? this.threatLevel,
      riskProbability: riskProbability ?? this.riskProbability,
    );
  }
}

class DashboardController extends StateNotifier<DashboardState> {
  DashboardController() : super(const DashboardState()) {
    _loadTrustedNumbers();
    _listenToCallEvents();
  }

  DetectionService _detectionService = DetectionService(trustedNumbers: const <String>[]);
  StreamSubscription<CallEvent>? _callEventSubscription;

  Future<void> _loadTrustedNumbers() async {
    final trustedNumbers = await NativeBridge.getTrustedNumbers();
    _detectionService = DetectionService(trustedNumbers: trustedNumbers);

    state = state.copyWith(
      trustedContactCount: trustedNumbers.length,
      latestReason: trustedNumbers.isEmpty
          ? 'Grant Contacts permission to improve spoof detection.'
          : state.latestReason,
    );
  }

  Future<void> refreshTrustedNumbers() async {
    await _loadTrustedNumbers();
  }

  void _listenToCallEvents() {
    _callEventSubscription = NativeBridge.callEventsStream.listen(
      (event) async {
        final risk = await _detectionService.analyzeIncomingCall(event);

        state = state.copyWith(
          callerNumber: event.phoneNumber,
          latestEvent: 'Incoming call detected (${event.eventName})',
          latestReason: risk.reasons.first,
          latestReasons: risk.reasons,
          riskProbability: risk.probability,
          threatLevel: _scoreToThreatLevel(risk.score),
        );

        await toggleAudioCapture(true);
      },
      onError: (dynamic error) {
        state = state.copyWith(
          latestEvent: 'Monitoring error: $error',
          threatLevel: ThreatLevel.safe,
        );
      },
    );
  }

  Future<void> toggleAudioCapture(bool start) async {
    final success = start
        ? await NativeBridge.startAudioCapture()
        : await NativeBridge.stopAudioCapture();

    if (!success) {
      state = state.copyWith(
        isAudioCapturing: false,
        latestReason: start
            ? 'Audio capture unavailable (permission denied or device restriction)'
            : state.latestReason,
      );
      return;
    }

    if (!start) {
      state = const DashboardState();
      return;
    }

    state = state.copyWith(isAudioCapturing: true);
  }

  ThreatLevel _scoreToThreatLevel(int score) {
    if (score >= 60) return ThreatLevel.danger;
    if (score >= 30) return ThreatLevel.warning;
    return ThreatLevel.safe;
  }

  @override
  void dispose() {
    _callEventSubscription?.cancel();
    super.dispose();
  }
}

final dashboardProvider = StateNotifierProvider<DashboardController, DashboardState>(
  (ref) => DashboardController(),
);
