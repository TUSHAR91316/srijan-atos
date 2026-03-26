class BiometricEvaluationResult {
  const BiometricEvaluationResult({
    required this.threshold,
    required this.far,
    required this.frr,
    required this.falseAccepts,
    required this.falseRejects,
  });

  final double threshold;
  final double far;
  final double frr;
  final int falseAccepts;
  final int falseRejects;
}

class BiometricMetricsService {
  BiometricMetricsService({this.threshold = 0.62});

  final double threshold;
  int _falseAccepts = 0;
  int _falseRejects = 0;
  int _impostorTrials = 0;
  int _genuineTrials = 0;

  void recordTrial({
    required bool isGenuine,
    required double score,
  }) {
    final accepted = score >= threshold;
    if (isGenuine) {
      _genuineTrials++;
      if (!accepted) {
        _falseRejects++;
      }
    } else {
      _impostorTrials++;
      if (accepted) {
        _falseAccepts++;
      }
    }
  }

  BiometricEvaluationResult snapshot() {
    final far = _impostorTrials == 0 ? 0.0 : _falseAccepts / _impostorTrials;
    final frr = _genuineTrials == 0 ? 0.0 : _falseRejects / _genuineTrials;

    return BiometricEvaluationResult(
      threshold: threshold,
      far: far,
      frr: frr,
      falseAccepts: _falseAccepts,
      falseRejects: _falseRejects,
    );
  }

  static BiometricEvaluationResult evaluate({
    required List<double> genuineScores,
    required List<double> impostorScores,
    required double threshold,
  }) {
    final falseRejects = genuineScores.where((score) => score < threshold).length;
    final falseAccepts = impostorScores.where((score) => score >= threshold).length;

    final far = impostorScores.isEmpty ? 0.0 : falseAccepts / impostorScores.length;
    final frr = genuineScores.isEmpty ? 0.0 : falseRejects / genuineScores.length;

    return BiometricEvaluationResult(
      threshold: threshold,
      far: far,
      frr: frr,
      falseAccepts: falseAccepts,
      falseRejects: falseRejects,
    );
  }
}
