import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/call_event.dart';
import '../services/native_bridge.dart';
import '../services/detection_service.dart';

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
    _init();
  }

  StreamSubscription<CallEvent>? _callEventSubscription;
  DetectionService? _detectionService;
  Timer? _pollingTimer;

  Future<void> _init() async {
    await _loadTrustedNumbers();
    _listenToCallEvents();
  }

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
        if (_detectionService == null) return;
        
        final risk = await _detectionService!.analyzeIncomingCall(event);
        
        state = state.copyWith(
          callerNumber: event.phoneNumber,
          latestEvent: 'Incoming call detected (\${event.eventName})',
          latestReason: risk.reasons.first,
          latestReasons: risk.reasons,
          riskProbability: risk.probability,
          threatLevel: _scoreToThreatLevel(risk.score),
        );

        await toggleAudioCapture(true);
      },
      onError: (dynamic error) {
        state = state.copyWith(
          latestEvent: 'Monitoring error: \$error',
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
            ? 'Audio capture unavailable'
            : state.latestReason,
      );
      return;
    }

    state = state.copyWith(isAudioCapturing: start);

    if (start) {
      _startPolling();
    } else {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!state.isAudioCapturing || _detectionService == null) {
        timer.cancel();
        return;
      }
      
      final signals = await NativeBridge.getLatestAudioSignals();
      if (signals == null) return;

      final event = CallEvent(
        eventName: "audio_analysis_update",
        phoneNumber: state.callerNumber.isEmpty ? "Unknown" : state.callerNumber,
        timestamp: DateTime.now(),
        antiSpoofScore: signals['antiSpoofScore'],
        snrDb: signals['snrDb'],
        voiceSimilarity: signals['voiceSimilarity'],
        voiceUsable: signals['voiceUsable'] == 1.0,
      );

      final risk = state.callerNumber.isEmpty 
          ? _detectionService!.analyzeAudioOnly(event) 
          : await _detectionService!.analyzeIncomingCall(event, saveLog: false);
      
      if (state.isAudioCapturing) {
        state = state.copyWith(
          latestEvent: 'Live Audio Analysis',
          latestReason: risk.reasons.first,
          latestReasons: risk.reasons,
          riskProbability: risk.probability,
          threatLevel: _scoreToThreatLevel(risk.score),
        );
      }
    });
  }

  ThreatLevel _scoreToThreatLevel(int score) {
    if (score >= 60) return ThreatLevel.danger;
    if (score >= 30) return ThreatLevel.warning;
    return ThreatLevel.safe;
  }

  @override
  void dispose() {
    _callEventSubscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }
}

final dashboardProvider = StateNotifierProvider<DashboardController, DashboardState>(
  (ref) => DashboardController(),
);
