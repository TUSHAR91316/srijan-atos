import 'package:fake_call_detector/services/biometric_metrics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Biometric metrics', () {
    test('computes FAR/FRR for batch evaluation', () {
      final result = BiometricMetricsService.evaluate(
        genuineScores: const <double>[0.92, 0.87, 0.55, 0.73],
        impostorScores: const <double>[0.10, 0.20, 0.71, 0.45],
        threshold: 0.70,
      );

      expect(result.falseRejects, 1);
      expect(result.falseAccepts, 1);
      expect(result.frr, closeTo(0.25, 1e-6));
      expect(result.far, closeTo(0.25, 1e-6));
    });

    test('supports incremental FAR/FRR tracking', () {
      final metrics = BiometricMetricsService(threshold: 0.6);

      metrics.recordTrial(isGenuine: true, score: 0.8);
      metrics.recordTrial(isGenuine: true, score: 0.5);
      metrics.recordTrial(isGenuine: false, score: 0.4);
      metrics.recordTrial(isGenuine: false, score: 0.7);

      final result = metrics.snapshot();
      expect(result.falseRejects, 1);
      expect(result.falseAccepts, 1);
      expect(result.frr, closeTo(0.5, 1e-6));
      expect(result.far, closeTo(0.5, 1e-6));
    });
  });
}
