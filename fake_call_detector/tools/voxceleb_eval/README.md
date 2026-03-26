# VoxCeleb1 Evaluation Pipeline

This toolkit evaluates the app's on-device speaker embedding model (`speaker_embedding.tflite`) using VoxCeleb1 trial pairs and exports calibrated thresholds back into the Flutter app.

## What It Produces

- Pairwise verification scoring on VoxCeleb1 trial lists
- FAR/FRR sweep and EER/minDCF threshold search
- Enrollment-vs-impostor simulation summary
- Plots:
  - `score_distribution.png`
  - `det_curve.png`
  - `far_frr_vs_threshold.png`
- Artifacts:
  - `evaluation_summary.json`
  - `far_frr_curve.csv`
- App calibration update:
  - `lib/services/biometric_calibration.dart`

## Setup

Install Python dependencies:

```bash
pip install -r tools/voxceleb_eval/requirements.txt
```

Download trial/meta lists:

```bash
python tools/voxceleb_eval/prepare_voxceleb1_metadata.py
```

## Dataset Layout

Audio files are expected under one of these layouts:

- `<dataset_root>/idXXXXX/.../*.wav`
- `<dataset_root>/wav/idXXXXX/.../*.wav`
- `<dataset_root>/vox1_test_wav/idXXXXX/.../*.wav`
- `<dataset_root>/vox1_dev_wav/idXXXXX/.../*.wav`

## Run Evaluation

```bash
python tools/voxceleb_eval/run_evaluation.py \
  --dataset-root D:/datasets/voxceleb1 \
  --trials-file tools/voxceleb_eval/data/voxceleb1_test_v2.txt \
  --model-path android/app/src/main/assets/speaker_embedding.tflite
```

If you only want metrics without changing app constants:

```bash
python tools/voxceleb_eval/run_evaluation.py \
  --dataset-root D:/datasets/voxceleb1 \
  --skip-dart-export
```

## Reproducibility

- Random seed defaults to `42` and can be overridden with `--seed`.
- Threshold sweep granularity defaults to `2000` points (`--points`).
- The same preprocessing used by Android native pipeline is applied:
  - mono conversion
  - resample to 16 kHz
  - center crop or zero pad to 15600 samples
  - mean subtraction
  - max-abs normalization to `[-1, 1]`
