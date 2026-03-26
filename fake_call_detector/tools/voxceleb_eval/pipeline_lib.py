from __future__ import annotations

import csv
import dataclasses
import json
import math
import random
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple

import librosa
import numpy as np
import soundfile as sf
from sklearn.linear_model import LogisticRegression


@dataclasses.dataclass(frozen=True)
class TrialPair:
    label: int
    left: str
    right: str


@dataclasses.dataclass(frozen=True)
class CurvePoint:
    threshold: float
    far: float
    frr: float


@dataclasses.dataclass(frozen=True)
class CalibrationResult:
    a: float
    b: float
    threshold_eer: float
    threshold_min_dcf: float
    eer: float


class SpeakerEmbedder:
    def __init__(self, model_path: Path, num_threads: int = 2) -> None:
        self._interpreter = _create_interpreter(model_path, num_threads=num_threads)
        self._interpreter.allocate_tensors()
        self._input_details = self._interpreter.get_input_details()
        self._output_details = self._interpreter.get_output_details()
        input_shape = tuple(self._input_details[0]["shape"])
        if input_shape != (1, 15600):
            raise ValueError(f"Unexpected model input shape: {input_shape}, expected (1, 15600)")

    def embed_waveform(self, waveform: np.ndarray) -> np.ndarray:
        if waveform.shape != (15600,):
            raise ValueError(f"Expected waveform shape (15600,), got {waveform.shape}")
        model_input = waveform.astype(np.float32, copy=False)[None, :]
        self._interpreter.set_tensor(self._input_details[0]["index"], model_input)
        self._interpreter.invoke()
        out = self._interpreter.get_tensor(self._output_details[0]["index"])[0]
        return l2_normalize(out.astype(np.float32, copy=False))


class EmbeddingCache:
    def __init__(self) -> None:
        self._cache: Dict[str, np.ndarray] = {}

    def get_or_compute(self, key: str, compute_fn) -> np.ndarray:
        val = self._cache.get(key)
        if val is not None:
            return val
        val = compute_fn()
        self._cache[key] = val
        return val


def _create_interpreter(model_path: Path, num_threads: int):
    model = str(model_path)
    errors: List[str] = []

    try:
        import ai_edge_litert as litert  # type: ignore

        if hasattr(litert, "Interpreter"):
            return litert.Interpreter(model_path=model, num_threads=num_threads)
    except Exception as exc:  # pragma: no cover - best effort fallback
        errors.append(f"ai_edge_litert.Interpreter: {exc}")

    try:
        from ai_edge_litert.interpreter import Interpreter  # type: ignore

        return Interpreter(model_path=model, num_threads=num_threads)
    except Exception as exc:  # pragma: no cover - best effort fallback
        errors.append(f"ai_edge_litert.interpreter.Interpreter: {exc}")

    try:
        from tensorflow.lite.python.interpreter import Interpreter  # type: ignore

        return Interpreter(model_path=model, num_threads=num_threads)
    except Exception as exc:  # pragma: no cover - best effort fallback
        errors.append(f"tensorflow Interpreter: {exc}")

    raise RuntimeError("Could not create TFLite interpreter. Errors: " + " | ".join(errors))


def read_trials_file(path: Path) -> List[TrialPair]:
    trials: List[TrialPair] = []
    with path.open("r", encoding="utf-8") as fh:
        for line in fh:
            parts = line.strip().split()
            if len(parts) < 3:
                continue
            label = int(parts[0])
            trials.append(TrialPair(label=label, left=parts[1], right=parts[2]))
    if not trials:
        raise ValueError(f"No trial pairs found in {path}")
    return trials


def resolve_audio_path(dataset_root: Path, rel_path: str) -> Path:
    candidates = [
        dataset_root / rel_path,
        dataset_root / "wav" / rel_path,
        dataset_root / "vox1_test_wav" / rel_path,
        dataset_root / "vox1_dev_wav" / rel_path,
    ]
    for c in candidates:
        if c.exists():
            return c
    return candidates[0]


def preprocess_audio(path: Path, target_sr: int = 16000, target_len: int = 15600) -> np.ndarray:
    signal, sr = sf.read(path, always_2d=False)
    if signal.ndim == 2:
        signal = signal.mean(axis=1)
    signal = signal.astype(np.float32, copy=False)

    if sr != target_sr:
        signal = librosa.resample(signal, orig_sr=sr, target_sr=target_sr)

    if signal.shape[0] >= target_len:
        start = (signal.shape[0] - target_len) // 2
        signal = signal[start : start + target_len]
    else:
        padded = np.zeros((target_len,), dtype=np.float32)
        padded[: signal.shape[0]] = signal
        signal = padded

    signal = signal - float(np.mean(signal))
    peak = float(np.max(np.abs(signal)))
    if peak > 0:
        signal = signal / peak
    signal = np.clip(signal, -1.0, 1.0)
    return signal.astype(np.float32, copy=False)


def l2_normalize(vector: np.ndarray) -> np.ndarray:
    norm = float(np.linalg.norm(vector))
    if norm <= 0:
        return vector
    return vector / norm


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-12))


def evaluate_trial_pairs(
    trials: Sequence[TrialPair],
    dataset_root: Path,
    embedder: SpeakerEmbedder,
) -> Tuple[np.ndarray, np.ndarray, int]:
    cache = EmbeddingCache()
    labels: List[int] = []
    scores: List[float] = []
    missing = 0

    for t in trials:
        left_path = resolve_audio_path(dataset_root, t.left)
        right_path = resolve_audio_path(dataset_root, t.right)
        if not left_path.exists() or not right_path.exists():
            missing += 1
            continue

        left_embedding = cache.get_or_compute(
            t.left,
            lambda: embedder.embed_waveform(preprocess_audio(left_path)),
        )
        right_embedding = cache.get_or_compute(
            t.right,
            lambda: embedder.embed_waveform(preprocess_audio(right_path)),
        )

        labels.append(t.label)
        scores.append(cosine_similarity(left_embedding, right_embedding))

    return np.asarray(labels, dtype=np.int32), np.asarray(scores, dtype=np.float64), missing


def compute_far_frr_curve(labels: np.ndarray, scores: np.ndarray, points: int = 2000) -> List[CurvePoint]:
    if labels.size == 0:
        raise ValueError("No labels provided")

    positives = labels == 1
    negatives = labels == 0

    thresholds = np.linspace(-1.0, 1.0, num=points, dtype=np.float64)
    curve: List[CurvePoint] = []
    for th in thresholds:
        accepted = scores >= th
        false_accepts = np.logical_and(accepted, negatives).sum()
        false_rejects = np.logical_and(~accepted, positives).sum()
        far = float(false_accepts / max(int(negatives.sum()), 1))
        frr = float(false_rejects / max(int(positives.sum()), 1))
        curve.append(CurvePoint(threshold=float(th), far=far, frr=frr))
    return curve


def find_eer(curve: Sequence[CurvePoint]) -> Tuple[float, float]:
    best_idx = min(range(len(curve)), key=lambda i: abs(curve[i].far - curve[i].frr))
    p = curve[best_idx]
    eer = (p.far + p.frr) / 2.0
    return p.threshold, eer


def find_min_dcf(curve: Sequence[CurvePoint], target_prior: float = 0.01, c_miss: float = 1.0, c_fa: float = 1.0) -> Tuple[float, float]:
    best = None
    for p in curve:
        dcf = c_miss * target_prior * p.frr + c_fa * (1.0 - target_prior) * p.far
        if best is None or dcf < best[1]:
            best = (p.threshold, dcf)
    assert best is not None
    return best


def fit_logistic_calibration(scores: np.ndarray, labels: np.ndarray) -> Tuple[float, float]:
    model = LogisticRegression(random_state=42, solver="lbfgs")
    model.fit(scores.reshape(-1, 1), labels)
    a = float(model.coef_[0][0])
    b = float(model.intercept_[0])
    return a, b


def evaluate_enrollment_simulation(
    dataset_root: Path,
    trials: Sequence[TrialPair],
    embedder: SpeakerEmbedder,
    seed: int = 42,
    enroll_per_speaker: int = 3,
) -> Dict[str, float]:
    rng = random.Random(seed)
    by_speaker: Dict[str, List[str]] = {}
    for t in trials:
        for path in (t.left, t.right):
            speaker = Path(path).parts[0] if Path(path).parts else ""
            if speaker:
                by_speaker.setdefault(speaker, []).append(path)

    usable_speakers = [s for s, items in by_speaker.items() if len(set(items)) >= enroll_per_speaker + 1]
    if len(usable_speakers) < 2:
        return {
            "simulation_pairs": 0,
            "simulation_genuine_mean": 0.0,
            "simulation_impostor_mean": 0.0,
        }

    cache = EmbeddingCache()

    def emb(rel_path: str) -> np.ndarray:
        p = resolve_audio_path(dataset_root, rel_path)
        return cache.get_or_compute(rel_path, lambda: embedder.embed_waveform(preprocess_audio(p)))

    genuine_scores: List[float] = []
    impostor_scores: List[float] = []

    for speaker in usable_speakers:
        unique_paths = sorted(set(by_speaker[speaker]))
        rng.shuffle(unique_paths)
        enrollment_paths = unique_paths[:enroll_per_speaker]
        probe_paths = unique_paths[enroll_per_speaker:]
        centroid = l2_normalize(np.mean([emb(p) for p in enrollment_paths], axis=0))

        for probe in probe_paths[: min(3, len(probe_paths))]:
            genuine_scores.append(cosine_similarity(centroid, emb(probe)))

        impostor_speaker = rng.choice([s for s in usable_speakers if s != speaker])
        impostor_path = rng.choice(sorted(set(by_speaker[impostor_speaker])))
        impostor_scores.append(cosine_similarity(centroid, emb(impostor_path)))

    return {
        "simulation_pairs": len(genuine_scores) + len(impostor_scores),
        "simulation_genuine_mean": float(np.mean(genuine_scores)) if genuine_scores else 0.0,
        "simulation_impostor_mean": float(np.mean(impostor_scores)) if impostor_scores else 0.0,
    }


def save_curve_csv(path: Path, curve: Sequence[CurvePoint]) -> None:
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.writer(fh)
        writer.writerow(["threshold", "far", "frr"])
        for p in curve:
            writer.writerow([f"{p.threshold:.6f}", f"{p.far:.8f}", f"{p.frr:.8f}"])


def export_summary(path: Path, payload: Dict) -> None:
    with path.open("w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2, sort_keys=True)


def export_dart_calibration(path: Path, a: float, b: float, threshold: float, snr_threshold_db: float = 10.0) -> None:
    content = (
        "/// Generated by tools/voxceleb_eval/run_evaluation.py\n"
        "/// using VoxCeleb1 evaluation outputs.\n"
        f"const double kVoiceSnrEnrollmentThresholdDb = {snr_threshold_db:.3f};\n"
        f"const double kVoiceCalibrationA = {a:.6f};\n"
        f"const double kVoiceCalibrationB = {b:.6f};\n"
        f"const double kVoiceEnrollmentUpdateThreshold = {threshold:.6f};\n"
        f"const double kVoiceVerificationThreshold = {threshold:.6f};\n"
    )
    path.write_text(content, encoding="utf-8")
