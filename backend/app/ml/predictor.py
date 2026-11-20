"""Сургасан CNN загварыг (ONNX) ачаалж, навчны зургаас өвчнийг таамаглана."""
import json
from functools import lru_cache
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image

from ..config import MODEL_DIR


class Predictor:
    def __init__(self, model_dir: Path):
        meta = json.loads((model_dir / "labels.json").read_text())
        self.classes: list[str] = meta["classes"]
        self.size: int = meta["input_size"]
        self.mean = np.array(meta["mean"], dtype=np.float32).reshape(1, 3, 1, 1)
        self.std = np.array(meta["std"], dtype=np.float32).reshape(1, 3, 1, 1)
        opts = ort.SessionOptions()
        opts.intra_op_num_threads = 2
        self.session = ort.InferenceSession(str(model_dir / "plant_cnn.onnx"), opts,
                                            providers=["CPUExecutionProvider"])
        self.input_name = self.session.get_inputs()[0].name

    def preprocess(self, img: Image.Image) -> np.ndarray:
        img = img.convert("RGB")
        w, h = img.size
        side = min(w, h)
        left, top = (w - side) // 2, (h - side) // 2
        img = img.crop((left, top, left + side, top + side)).resize((self.size, self.size), Image.BILINEAR)
        x = np.asarray(img, dtype=np.float32).transpose(2, 0, 1)[None] / 255.0
        return (x - self.mean) / self.std

    def predict(self, img: Image.Image, top_k: int = 3) -> list[tuple[str, float]]:
        x = self.preprocess(img)
        batch = np.concatenate([x, x[..., ::-1]], axis=0).astype(np.float32)  # TTA: тусгал
        logits = self.session.run(None, {self.input_name: batch})[0].mean(axis=0)
        e = np.exp(logits - logits.max())
        probs = e / e.sum()
        order = np.argsort(-probs)[:top_k]
        return [(self.classes[i], float(probs[i])) for i in order]


@lru_cache(maxsize=1)
def get_predictor() -> Predictor:
    return Predictor(MODEL_DIR)
