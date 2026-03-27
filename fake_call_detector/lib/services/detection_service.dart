import 'dart:convert';
import 'dart:math';

import '../models/call_event.dart';
import 'database_service.dart';
import 'biometric_calibration.dart';
import 'detection_store.dart';
import 'voice_biometric_service.dart';

class RiskAssessment {
  const RiskAssessment({
    required this.probability,
    required this.score,
    required this.reasons,
    required this.signals,
  });

  final double probability;
  final int score;
  final List<String> reasons;
  final Map<String, double> signals;
}

class DetectionService {
  DetectionService({
    required List<String> trustedNumbers,
    DetectionStore? detectionStore,
  })  : _trustedNumbers = trustedNumbers,
        _detectionStore = detectionStore ?? SqlDetectionStore(DatabaseService()),
        _voiceBiometricService = VoiceBiometricService(
          detectionStore ?? SqlDetectionStore(DatabaseService()),
        );

  final List<String> _trustedNumbers;
  final DetectionStore _detectionStore;
  final VoiceBiometricService _voiceBiometricService;

  Future<RiskAssessment> analyzeIncomingCall(CallEvent event, {bool saveLog = true}) async {
    final normalized = _normalizePhone(event.phoneNumber);
    final digitsOnly = _digitsOnly(normalized);
    final trustedDigits = _trustedNumbers.map(_digitsOnly).where((n) => n.isNotEmpty).toList(growable: false);

    final exactTrustedMatch = trustedDigits.contains(digitsOnly);
    final minDistanceRatio = _minLevenshteinRatio(digitsOnly, trustedDigits);
    final nearMatchSpoof = !exactTrustedMatch && minDistanceRatio <= 0.15;

    final recentHourCount = digitsOnly.isEmpty
        ? 0
        : await _detectionStore.getRecentCallCount(event.phoneNumber, const Duration(hours: 1));

    final recentHistory = digitsOnly.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _detectionStore.getRecentCallsForNumber(event.phoneNumber, 50);

    final voiceIdentityScore = await _voiceBiometricService.verifyIdentity(
      event.phoneNumber,
      event.voiceEmbedding,
    );

    if (event.voiceEmbedding != null && exactTrustedMatch) {
      final isBootstrapEnrollment = voiceIdentityScore == null;
      final isReliableUpdate = (voiceIdentityScore ?? 0) >= kVoiceEnrollmentUpdateThreshold;
      if (isBootstrapEnrollment || isReliableUpdate) {
        await _voiceBiometricService.enrollSample(
          event.phoneNumber,
          event.voiceEmbedding!,
          voiceIdentityScore ?? 1.0,
          event.snrDb,
        );
      }
    }

    final timeOfDayAnomaly = _timeOfDayAnomaly(event.timestamp, recentHistory);
    final durationAnomaly = _durationAnomaly(event.durationSeconds, recentHistory);
    final firstTimeCaller = recentHistory.isEmpty ? 1.0 : 0.0;

    final contactConfidence = exactTrustedMatch
        ? 1.0
        : nearMatchSpoof
            ? 0.2
            : 0.0;

    final effectiveVoiceScore = voiceIdentityScore ?? event.voiceSimilarity;
    final voiceMismatch = effectiveVoiceScore == null
        ? 0.0
        : (1.0 - effectiveVoiceScore.clamp(0.0, 1.0));
    final voiceUnavailable = (event.voiceEmbedding == null && event.voiceSimilarity == null) ? 1.0 : 0.0;
    final antiSpoof = (event.antiSpoofScore ?? 0.0).clamp(0.0, 1.0);
    final snrPenalty = ((12.0 - (event.snrDb ?? 12.0)) / 12.0).clamp(0.0, 1.0);

    final frequencyAnomaly = min(1.0, recentHourCount / 4.0);
    final unknownSignal = event.isUnknownNumber ? 1.0 : 0.0;
    final internationalSignal = normalized.startsWith('+') ? 1.0 : 0.0;
    final malformedSignal = digitsOnly.length < 10 ? 1.0 : 0.0;

    final signals = <String, double>{
      'unknown': unknownSignal,
      'international': internationalSignal,
      'malformed': malformedSignal,
      'near_spoof': nearMatchSpoof ? 1.0 : 0.0,
      'contact_confidence': contactConfidence,
      'frequency_anomaly': frequencyAnomaly,
      'time_of_day_anomaly': timeOfDayAnomaly,
      'duration_anomaly': durationAnomaly,
      'first_time_caller': firstTimeCaller,
      'voice_mismatch': voiceMismatch,
      'voice_unavailable': voiceUnavailable,
      'anti_spoof': antiSpoof,
      'snr_penalty': snrPenalty,
    };

    final probability = _predictProbability(signals);
    final score = (probability * 100).round().clamp(0, 100);

    final reasons = _explain(signals, exactTrustedMatch);

    if (saveLog) {
      await _detectionStore.insertRiskLog(
        event: event,
        score: score,
        probability: probability,
        reasons: jsonEncode(reasons),
        signalBreakdown: jsonEncode(signals),
        voiceSimilarity: effectiveVoiceScore,
        durationSeconds: event.durationSeconds,
      );
    }

    return RiskAssessment(
      probability: probability,
      score: score,
      reasons: reasons,
      signals: signals,
    );
  }

  RiskAssessment analyzeAudioOnly(CallEvent event) {
    final antiSpoof = (event.antiSpoofScore ?? 0.0).clamp(0.0, 1.0);
    // Be more lenient with SNR. Default threshold was 12dB, let's make it 8dB.
    final snrPenalty = ((8.0 - (event.snrDb ?? 8.0)) / 8.0).clamp(0.0, 1.0);

    final signals = <String, double>{
      'anti_spoof': antiSpoof,
      'snr_penalty': snrPenalty,
    };

    // We use a non-linear threshold for the demo. 
    // This keeps normal voice safely bounded, but allows obvious fakes (anti_spoof > 0.7) to jump past 80% risk.
    double spoofPenalty = signals['anti_spoof']! > 0.70 ? 6.5 : (signals['anti_spoof']! * 1.5);
    double noisePenalty = signals['snr_penalty']! > 0.60 ? 3.0 : (signals['snr_penalty']! * 1.0);

    final z = -4.0 + spoofPenalty + noisePenalty;
    final probability = 1.0 / (1.0 + exp(-z));
    final score = (probability * 100).round().clamp(0, 100);

    print("LIVE AUDIO STATS: antiSpoof: \${antiSpoof.toStringAsFixed(2)}, snrDb: \${event.snrDb?.toStringAsFixed(1) ?? 'N/A'}, snrPenalty: \${snrPenalty.toStringAsFixed(2)}, risk: $score%");

    final reasons = <String>[];
    if (signals['anti_spoof']! >= 0.45) reasons.add('Spectral analysis strongly suggests synthetic/replay audio');
    else if (signals['anti_spoof']! >= 0.3) reasons.add('Audio exhibits mild robotic/synthetic spectral artifacts');
    
    if (signals['snr_penalty']! >= 0.5) reasons.add('High noise levels reducing confidence');
    
    if (reasons.isEmpty) reasons.add('Live human voice detected safely');

    return RiskAssessment(
      probability: probability,
      score: score,
      reasons: reasons,
      signals: signals,
    );
  }

  double _predictProbability(Map<String, double> s) {
    // Rebalanced so an unknown caller with fake audio crosses the threshold nicely
    final z =
        -3.5 +
        1.5 * s['unknown']! +
        0.5 * s['international']! +
        1.0 * s['malformed']! +
        1.0 * s['near_spoof']! +
        0.5 * s['frequency_anomaly']! +
        0.2 * s['time_of_day_anomaly']! +
        0.2 * s['duration_anomaly']! +
        0.5 * s['first_time_caller']! +
        2.0 * s['voice_mismatch']! +
        (s['anti_spoof']! > 0.70 ? 4.0 : 0.5) +  // Huge spike if fake audio is explicitly detected
        1.0 * s['snr_penalty']! +
        0.5 * s['voice_unavailable']! -
        3.0 * s['contact_confidence']!;

    return 1.0 / (1.0 + exp(-z));
  }

  List<String> _explain(Map<String, double> signals, bool exactTrustedMatch) {
    final reasons = <String>[];

    if (signals['near_spoof']! > 0.5) {
      reasons.add('Number is very close to a trusted contact and may be spoofed');
    }
    if (signals['frequency_anomaly']! >= 0.75) {
      reasons.add('Abnormal call frequency detected in the last hour');
    }
    if (signals['time_of_day_anomaly']! >= 0.7) {
      reasons.add('Call timing is unusual compared to historical behavior');
    }
    if (signals['duration_anomaly']! >= 0.7) {
      reasons.add('Call duration pattern deviates from historical behavior');
    }
    if (signals['voice_mismatch']! >= 0.6) {
      reasons.add('Voice fingerprint does not match trusted profile');
    }
    if (signals['voice_unavailable']! > 0.5) {
      reasons.add('No usable voice segment available for biometric verification');
    }
    if (signals['anti_spoof']! >= 0.6) {
      reasons.add('Spectral anti-spoof checks indicate synthetic or replay characteristics');
    }
    if (signals['snr_penalty']! >= 0.5) {
      reasons.add('Low SNR audio reduces confidence in caller authenticity');
    }
    if (signals['unknown']! > 0.5) {
      reasons.add('Caller identity is hidden or unknown');
    }
    if (signals['malformed']! > 0.5) {
      reasons.add('Caller number format is malformed');
    }
    if (signals['international']! > 0.5) {
      reasons.add('International dialing pattern increases spoof risk');
    }
    if (exactTrustedMatch) {
      reasons.add('Exact trusted contact match lowers risk');
    }

    if (reasons.isEmpty) {
      reasons.add('No high-risk signals detected');
    }
    return reasons;
  }

  double _timeOfDayAnomaly(DateTime timestamp, List<Map<String, dynamic>> history) {
    if (history.length < 3) return 0.5;
    final hour = timestamp.hour;
    final historyHours = history
        .map((row) => DateTime.tryParse(row['timestamp']?.toString() ?? ''))
        .whereType<DateTime>()
        .map((d) => d.hour)
        .toList(growable: false);
    if (historyHours.isEmpty) return 0.5;

    final avg = historyHours.reduce((a, b) => a + b) / historyHours.length;
    final diff = (hour - avg).abs();
    return (diff / 12.0).clamp(0.0, 1.0);
  }

  double _durationAnomaly(int? durationSeconds, List<Map<String, dynamic>> history) {
    if (durationSeconds == null || history.length < 3) return 0.0;

    final durations = history
        .map((row) => row['duration_seconds'])
        .whereType<int>()
        .where((value) => value > 0)
        .toList(growable: false);

    if (durations.length < 3) return 0.0;

    final avg = durations.reduce((a, b) => a + b) / durations.length;
    final ratio = ((durationSeconds - avg).abs() / max(avg, 1.0));
    return ratio.clamp(0.0, 1.0);
  }

  double _minLevenshteinRatio(String incoming, List<String> trusted) {
    if (incoming.isEmpty || trusted.isEmpty) return 1.0;
    var minRatio = 1.0;
    for (final number in trusted) {
      if (number.isEmpty) continue;
      final distance = _levenshtein(incoming, number);
      final ratio = distance / max(incoming.length, number.length);
      if (ratio < minRatio) {
        minRatio = ratio;
      }
    }
    return minRatio;
  }

  int _levenshtein(String a, String b) {
    final matrix = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );

    for (var i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }

    return matrix[a.length][b.length];
  }

  String _normalizePhone(String value) => value.replaceAll(RegExp(r'[\s\-()]'), '');

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');
}
