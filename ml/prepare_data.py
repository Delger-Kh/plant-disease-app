"""PlantVillage зургуудыг 128x128 болгон жижигрүүлж, train/val/test-д хуваана.

Ашиглах нь:
    python prepare_data.py --src <PlantVillage/raw/color> --out data.npz
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

CROPS = ("Apple", "Corn", "Grape", "Potato", "Tomato")
SIZE = 128


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--out", default="data.npz")
    ap.add_argument("--seed", type=int, default=42)
    a = ap.parse_args()

    src = Path(a.src)
    classes = sorted(d.name for d in src.iterdir() if d.is_dir() and d.name.startswith(CROPS))
    X, y = [], []
    for ci, c in enumerate(classes):
        files = sorted(p for p in (src / c).iterdir() if p.suffix.lower() in (".jpg", ".jpeg", ".png"))
        for p in files:
            try:
                im = Image.open(p).convert("RGB").resize((SIZE, SIZE), Image.BILINEAR)
            except Exception as e:  # эвдэрсэн файл
                print("skip", p, e)
                continue
            X.append(np.asarray(im, dtype=np.uint8))
            y.append(ci)
        print(f"{ci:2d} {c}: {sum(1 for t in y if t == ci)}")
    X = np.stack(X)
    y = np.array(y, dtype=np.int64)

    # Анги бүрээс 80/10/10 хуваалт (stratified)
    rng = np.random.default_rng(a.seed)
    tr, va, te = [], [], []
    for ci in range(len(classes)):
        idx = np.where(y == ci)[0]
        rng.shuffle(idx)
        n = len(idx)
        n_te = max(1, round(n * 0.1))
        n_va = max(1, round(n * 0.1))
        te += idx[:n_te].tolist()
        va += idx[n_te:n_te + n_va].tolist()
        tr += idx[n_te + n_va:].tolist()
    np.savez_compressed(a.out, X=X, y=y, tr=np.array(tr), va=np.array(va), te=np.array(te),
                        classes=np.array(classes))
    print("total", len(y), "train", len(tr), "val", len(va), "test", len(te))
    json.dump(classes, open(Path(a.out).with_name("classes.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
