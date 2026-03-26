import 'dart:math';

import 'biometric_calibration.dart';
import 'detection_store.dart';

class VoiceBiometricService {
  VoiceBiometricService(this._store);

  final DetectionStore _store;

  Future<double?> verifyIdentity(String phoneNumber, List<double>? liveEmbedding) async {
    if (liveEmbedding == null || liveEmbedding.isEmpty) {
      return null;
    }

    final enrolled = await _store.getVoiceEmbeddingSamples(phoneNumber);
    if (enrolled.isEmpty) {
      return null;
    }

    final normalizedLive = _normalizeEmbedding(liveEmbedding);

    final similarities = enrolled
        .where((sample) => sample.length == liveEmbedding.length)
      .map((sample) => _cosineSimilarity(normalizedLive, _normalizeEmbedding(sample)))
        .toList(growable: false);

    if (similarities.isEmpty) {
      return null;
    }

    similarities.sort((a, b) => b.compareTo(a));
    final top = similarities.take(min(3, similarities.length));
    final avg = top.reduce((a, b) => a + b) / top.length;
    return _calibrateCosine(avg);
  }

  Future<void> enrollSample(
    String phoneNumber,
    List<double> embedding,
    double quality,
    double? snrDb,
  ) async {
    if (embedding.isEmpty) return;
    if (snrDb != null && snrDb < kVoiceSnrEnrollmentThresholdDb) return;

    await _store.addVoiceEmbeddingSample(
      phoneNumber,
      _normalizeEmbedding(embedding),
      quality.clamp(0.0, 1.0),
      maxSamples: 8,
    );
  }

  List<double> _normalizeEmbedding(List<double> input) {
    var norm = 0.0;
    for (final v in input) {
      norm += v * v;
    }
    norm = sqrt(norm);
    if (norm <= 0) return List<double>.from(input);
    return input.map((e) => e / norm).toList(growable: false);
  }

  double _calibrateCosine(double cosine) {
    final x = cosine.clamp(-1.0, 1.0);
    final z = kVoiceCalibrationA * x + kVoiceCalibrationB;
    return (1.0 / (1.0 + exp(-z))).clamp(0.0, 1.0);
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;

    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dot / (sqrt(normA) * sqrt(normB));
  }
}
