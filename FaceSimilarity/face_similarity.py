from __future__ import annotations

import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

import cv2
import numpy as np

MODELS_DIR = Path(__file__).parent / "models"
_YUNET_FILENAME = "face_detection_yunet_2023mar.onnx"
_SFACE_FILENAME = "face_recognition_sface_2021dec.onnx"
YUNET_PATH = MODELS_DIR / _YUNET_FILENAME
SFACE_PATH = MODELS_DIR / _SFACE_FILENAME

_YUNET_URL = f"https://github.com/opencv/opencv_zoo/raw/main/models/face_detection_yunet/{_YUNET_FILENAME}"
_SFACE_URL = f"https://github.com/opencv/opencv_zoo/raw/main/models/face_recognition_sface/{_SFACE_FILENAME}"


def ensure_models() -> None:
    MODELS_DIR.mkdir(exist_ok=True)
    if not YUNET_PATH.exists():
        print(f"Downloading {_YUNET_FILENAME} ...")
        urllib.request.urlretrieve(_YUNET_URL, str(YUNET_PATH))
    if not SFACE_PATH.exists():
        print(f"Downloading {_SFACE_FILENAME} (~37MB) ...")
        urllib.request.urlretrieve(_SFACE_URL, str(SFACE_PATH))


@dataclass
class PairSimilarity:
    first_index: int
    second_index: int
    score: float


@dataclass
class CommonalityResult:
    image_count: int
    pairs: list[PairSimilarity] = field(default_factory=list)

    @property
    def overall_score(self) -> float:
        if not self.pairs:
            return 0.0
        return sum(p.score for p in self.pairs) / len(self.pairs)

    @property
    def most_similar_pair(self) -> PairSimilarity | None:
        return max(self.pairs, key=lambda p: p.score) if self.pairs else None

    @property
    def least_similar_pair(self) -> PairSimilarity | None:
        return min(self.pairs, key=lambda p: p.score) if self.pairs else None


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """Cosine similarity in [-1, 1]. Returns 0.0 for zero or mismatched vectors."""
    a_flat = a.flatten().astype(np.float64)
    b_flat = b.flatten().astype(np.float64)
    if a_flat.shape != b_flat.shape:
        return 0.0
    norm_a = float(np.linalg.norm(a_flat))
    norm_b = float(np.linalg.norm(b_flat))
    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0
    cosine = float(np.dot(a_flat, b_flat) / (norm_a * norm_b))
    return max(-1.0, min(1.0, cosine))


def similarity_score(a: np.ndarray, b: np.ndarray) -> float:
    """Similarity as a percentage [0, 100].
    Maps cosine similarity linearly: -1 → 0%, 0 → 50%, +1 → 100%.
    """
    return (cosine_similarity(a, b) + 1.0) / 2.0 * 100.0


def compute_commonality(embeddings: list[np.ndarray]) -> CommonalityResult:
    """Compute all pairwise similarity scores and derive an overall commonality score."""
    n = len(embeddings)
    pairs: list[PairSimilarity] = []
    for i in range(n):
        for j in range(i + 1, n):
            score = similarity_score(embeddings[i], embeddings[j])
            pairs.append(PairSimilarity(first_index=i, second_index=j, score=score))
    return CommonalityResult(image_count=n, pairs=pairs)


def extract_embedding(image_bgr: np.ndarray) -> np.ndarray | None:
    """Detect the most prominent face and return its 128-dim SFace embedding.

    Returns None if no face is detected in the image.
    """
    ensure_models()
    h, w = image_bgr.shape[:2]

    detector = cv2.FaceDetectorYN.create(
        str(YUNET_PATH), "", (w, h), score_threshold=0.6, nms_threshold=0.3, top_k=5000
    )
    _, faces = detector.detect(image_bgr)
    if faces is None or len(faces) == 0:
        return None

    primary = max(faces, key=lambda f: f[2] * f[3])

    recognizer = cv2.FaceRecognizerSF.create(str(SFACE_PATH), "")
    aligned = recognizer.alignCrop(image_bgr, primary)
    return recognizer.feature(aligned)


def bytes_to_bgr(image_bytes: bytes) -> np.ndarray | None:
    """Decode raw JPEG/PNG bytes to an OpenCV BGR array."""
    buf = np.frombuffer(image_bytes, dtype=np.uint8)
    return cv2.imdecode(buf, cv2.IMREAD_COLOR)
