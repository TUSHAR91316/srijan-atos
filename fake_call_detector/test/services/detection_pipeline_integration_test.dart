import 'dart:convert';

import 'package:fake_call_detector/models/call_event.dart';
import 'package:fake_call_detector/services/detection_service.dart';
import 'package:fake_call_detector/services/detection_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryDetectionStore implements DetectionStore {
  final List<Map<String, dynamic>> _callLogs = <Map<String, dynamic>>[];
  final Map<String, List<List<double>>> _voiceSamples = <String, List<List<double>>>{};

  @override
  Future<void> addVoiceEmbeddingSample(
    String phoneNumber,
    List<double> embedding,
    double quality, {
    int maxSamples = 8,
  }) async {
    final entries = _voiceSamples.putIfAbsent(phoneNumber, () => <List<double>>[]);
    entries.insert(0, List<double>.from(embedding));
    if (entries.length > maxSamples) {
      entries.removeRange(maxSamples, entries.length);
    }
  }

  @override
  Future<int> getRecentCallCount(String phoneNumber, Duration window) async {
    final cutoff = DateTime.now().subtract(window);
    return _callLogs.where((e) {
      final ts = DateTime.tryParse(e['timestamp'] as String? ?? '');
      return e['phone_number'] == phoneNumber && ts != null && ts.isAfter(cutoff);
    }).length;
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentCallsForNumber(String phoneNumber, int limit) async {
    final rows = _callLogs.where((e) => e['phone_number'] == phoneNumber).toList(growable: false);
    return rows.take(limit).toList(growable: false);
  }

  @override
  Future<List<List<double>>> getVoiceEmbeddingSamples(String phoneNumber) async {
    return List<List<double>>.from(_voiceSamples[phoneNumber] ?? const <List<double>>[]);
  }

  @override
  Future<int> insertRiskLog({
    required CallEvent event,
    required int score,
    required double probability,
    required String reasons,
    required String signalBreakdown,
    required double? voiceSimilarity,
    required int? durationSeconds,
  }) async {
    _callLogs.insert(0, {
      'phone_number': event.phoneNumber,
      'timestamp': event.timestamp.toIso8601String(),
      'threat_score': score,
      'reasons': reasons,
      'signal_breakdown': signalBreakdown,
      'voice_similarity': voiceSimilarity,
      'duration_seconds': durationSeconds,
    });
    return _callLogs.length;
  }
}

void main() {
  group('Detection pipeline integration', () {
    test('enrolls trusted voice and lowers risk for matching embedding', () async {
      final store = _InMemoryDetectionStore();
      final service = DetectionService(
        trustedNumbers: const <String>['+919876543210'],
        detectionStore: store,
      );

      final first = await service.analyzeIncomingCall(
        CallEvent.fromMap({
          'event': 'incoming_call',
          'phoneNumber': '+919876543210',
          'voiceEmbedding': List<double>.filled(1024, 0.1),
          'snrDb': 22.0,
          'antiSpoofScore': 0.1,
        }),
      );

      final second = await service.analyzeIncomingCall(
        CallEvent.fromMap({
          'event': 'incoming_call',
          'phoneNumber': '+919876543210',
          'voiceEmbedding': List<double>.filled(1024, 0.1),
          'snrDb': 21.0,
          'antiSpoofScore': 0.1,
        }),
      );

      expect(first.score, lessThan(60));
      expect(second.score, lessThan(first.score + 15));
      expect((await store.getVoiceEmbeddingSamples('+919876543210')).isNotEmpty, isTrue);
    });

    test('raises spoof risk for near-match number and mismatched voice', () async {
      final store = _InMemoryDetectionStore();
      await store.addVoiceEmbeddingSample(
        '+919876543210',
        List<double>.filled(1024, 0.2),
        1.0,
      );

      final service = DetectionService(
        trustedNumbers: const <String>['+919876543210'],
        detectionStore: store,
      );

      final risk = await service.analyzeIncomingCall(
        CallEvent.fromMap({
          'event': 'incoming_call',
          'phoneNumber': '+919876543211',
          'voiceEmbedding': List<double>.filled(1024, -0.2),
          'snrDb': 20.0,
          'antiSpoofScore': 0.8,
        }),
      );

      expect(risk.score, greaterThanOrEqualTo(60));
      expect(risk.reasons.join(' '), contains('spoof'));
    });

    test('handles no audio embedding and records voice-unavailable signal', () async {
      final store = _InMemoryDetectionStore();
      final service = DetectionService(
        trustedNumbers: const <String>['+919876543210'],
        detectionStore: store,
      );

      final risk = await service.analyzeIncomingCall(
        CallEvent.fromMap({
          'event': 'incoming_call',
          'phoneNumber': '+919876543210',
        }),
      );

      expect(risk.reasons.join(' '), contains('No usable voice segment'));
      expect(risk.signals['voice_unavailable'], 1.0);

      final fallbackRisk = await service.analyzeIncomingCall(
        CallEvent.fromMap({
          'event': 'incoming_call',
          'phoneNumber': '+919876543210',
          'voiceSimilarity': 0.78,
        }),
      );
      expect(fallbackRisk.signals['voice_unavailable'], 0.0);

      final history = await store.getRecentCallsForNumber('+919876543210', 5);
      final decodedSignals = history
          .map((row) => jsonDecode(row['signal_breakdown'] as String) as Map<String, dynamic>)
          .toList(growable: false);
      expect(
        decodedSignals.any((row) => ((row['voice_unavailable'] as num?)?.toDouble() ?? 0.0) == 1.0),
        isTrue,
      );
    });
  });
}
