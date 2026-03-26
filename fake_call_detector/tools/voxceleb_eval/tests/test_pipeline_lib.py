import tempfile
import unittest
from pathlib import Path

import numpy as np

from tools.voxceleb_eval.pipeline_lib import (
    compute_far_frr_curve,
    export_dart_calibration,
    find_eer,
    fit_logistic_calibration,
    preprocess_audio,
)


class PipelineLibTests(unittest.TestCase):
    def test_far_frr_curve_and_eer(self):
        labels = np.array([1, 1, 0, 0], dtype=np.int32)
        scores = np.array([0.9, 0.8, 0.3, 0.1], dtype=np.float64)
        curve = compute_far_frr_curve(labels, scores, points=200)
        threshold, eer = find_eer(curve)

        self.assertTrue(-1.0 <= threshold <= 1.0)
        self.assertLessEqual(eer, 0.26)

    def test_logistic_calibration_sign(self):
        labels = np.array([1, 1, 1, 0, 0, 0], dtype=np.int32)
        scores = np.array([0.8, 0.9, 0.7, 0.2, 0.3, 0.1], dtype=np.float64)
        a, _ = fit_logistic_calibration(scores, labels)
        self.assertGreater(a, 0.0)

    def test_export_dart_calibration(self):
        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "biometric_calibration.dart"
            export_dart_calibration(out, a=11.5, b=-7.1, threshold=0.77)
            text = out.read_text(encoding="utf-8")
            self.assertIn("kVoiceCalibrationA = 11.500000", text)
            self.assertIn("kVoiceEnrollmentUpdateThreshold = 0.770000", text)

    def test_preprocess_audio_shape(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "sample.wav"
            # 1 second of synthetic sine at 16kHz.
            sr = 16000
            t = np.arange(sr) / sr
            x = (0.4 * np.sin(2 * np.pi * 220 * t)).astype(np.float32)
            import soundfile as sf

            sf.write(path, x, sr)
            y = preprocess_audio(path)
            self.assertEqual(y.shape, (15600,))
            self.assertLessEqual(np.max(np.abs(y)), 1.0)


if __name__ == "__main__":
    unittest.main()
