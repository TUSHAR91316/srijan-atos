from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

from pipeline_lib import (
    SpeakerEmbedder,
    compute_far_frr_curve,
    evaluate_enrollment_simulation,
    evaluate_trial_pairs,
    export_dart_calibration,
    export_summary,
    find_eer,
    find_min_dcf,
    fit_logistic_calibration,
    read_trials_file,
    save_curve_csv,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="VoxCeleb1 evaluation for on-device speaker model")
    parser.add_argument("--dataset-root", type=Path, required=True, help="Root folder containing VoxCeleb1 wav files")
    parser.add_argument(
        "--trials-file",
        type=Path,
        default=Path("tools/voxceleb_eval/data/voxceleb1_test_v2.txt"),
        help="Verification trial list file",
    )
    parser.add_argument(
        "--model-path",
        type=Path,
        default=Path("android/app/src/main/assets/speaker_embedding.tflite"),
        help="TFLite speaker embedding model path",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("tools/voxceleb_eval/artifacts"),
        help="Output folder for metrics and plots",
    )
    parser.add_argument(
        "--dart-calibration-path",
        type=Path,
        default=Path("lib/services/biometric_calibration.dart"),
        help="Target dart constants file to overwrite with calibrated values",
    )
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--points", type=int, default=2000, help="Threshold sweep granularity")
    parser.add_argument("--skip-dart-export", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    trials = read_trials_file(args.trials_file)
    embedder = SpeakerEmbedder(args.model_path)

    labels, scores, missing = evaluate_trial_pairs(trials, args.dataset_root, embedder)
    if labels.size == 0:
        raise RuntimeError("No evaluable trial pairs were found. Check dataset-root and trials-file alignment.")

    curve = compute_far_frr_curve(labels, scores, points=args.points)
    threshold_eer, eer = find_eer(curve)
    threshold_min_dcf, min_dcf = find_min_dcf(curve)
    a, b = fit_logistic_calibration(scores, labels)
    simulation = evaluate_enrollment_simulation(args.dataset_root, trials, embedder, seed=args.seed)

    curve_csv = args.output_dir / "far_frr_curve.csv"
    save_curve_csv(curve_csv, curve)

    summary = {
        "evaluated_pairs": int(labels.size),
        "missing_pairs": int(missing),
        "genuine_pairs": int((labels == 1).sum()),
        "impostor_pairs": int((labels == 0).sum()),
        "score_min": float(scores.min()),
        "score_max": float(scores.max()),
        "score_mean": float(scores.mean()),
        "threshold_eer": float(threshold_eer),
        "eer": float(eer),
        "threshold_min_dcf": float(threshold_min_dcf),
        "min_dcf": float(min_dcf),
        "calibration_a": float(a),
        "calibration_b": float(b),
        **simulation,
    }
    export_summary(args.output_dir / "evaluation_summary.json", summary)

    render_plots(args.output_dir, labels, scores, curve, threshold_eer)

    if not args.skip_dart_export:
        export_dart_calibration(args.dart_calibration_path, a=a, b=b, threshold=threshold_eer)

    print("Evaluation complete")
    for key in [
        "evaluated_pairs",
        "missing_pairs",
        "eer",
        "threshold_eer",
        "threshold_min_dcf",
        "min_dcf",
        "calibration_a",
        "calibration_b",
    ]:
        print(f"{key}: {summary[key]}")


def render_plots(output_dir: Path, labels: np.ndarray, scores: np.ndarray, curve, threshold_eer: float) -> None:
    positives = scores[labels == 1]
    negatives = scores[labels == 0]

    plt.figure(figsize=(8, 5))
    plt.hist(negatives, bins=60, alpha=0.6, label="Impostor")
    plt.hist(positives, bins=60, alpha=0.6, label="Genuine")
    plt.axvline(threshold_eer, color="black", linestyle="--", label=f"EER threshold={threshold_eer:.3f}")
    plt.xlabel("Cosine similarity")
    plt.ylabel("Count")
    plt.title("VoxCeleb1 score distribution")
    plt.legend()
    plt.tight_layout()
    plt.savefig(output_dir / "score_distribution.png", dpi=160)
    plt.close()

    x_far = [p.far for p in curve]
    y_frr = [p.frr for p in curve]
    plt.figure(figsize=(6, 6))
    plt.plot(x_far, y_frr)
    plt.xlabel("FAR")
    plt.ylabel("FRR")
    plt.title("DET-style FAR/FRR curve")
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_dir / "det_curve.png", dpi=160)
    plt.close()

    thresholds = [p.threshold for p in curve]
    plt.figure(figsize=(8, 5))
    plt.plot(thresholds, x_far, label="FAR")
    plt.plot(thresholds, y_frr, label="FRR")
    plt.axvline(threshold_eer, color="black", linestyle="--", label="EER threshold")
    plt.xlabel("Threshold")
    plt.ylabel("Rate")
    plt.title("FAR/FRR vs threshold")
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_dir / "far_frr_vs_threshold.png", dpi=160)
    plt.close()


if __name__ == "__main__":
    main()
