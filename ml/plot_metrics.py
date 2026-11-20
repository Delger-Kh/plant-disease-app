"""metrics.json-оос сургалтын муруй ба confusion matrix зурна.

    python plot_metrics.py --metrics ../backend/model/metrics.json --out ../docs
"""
import argparse
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

SHORT = {
    "Apple___Apple_scab": "Алим: хамуу", "Apple___Black_rot": "Алим: хар ялзрал",
    "Apple___Cedar_apple_rust": "Алим: зэв", "Apple___healthy": "Алим: эрүүл",
    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot": "Э.шиш: саарал толбо",
    "Corn_(maize)___Common_rust_": "Э.шиш: зэв", "Corn_(maize)___Northern_Leaf_Blight": "Э.шиш: хорчилт",
    "Corn_(maize)___healthy": "Э.шиш: эрүүл", "Grape___Black_rot": "Үзэм: хар ялзрал",
    "Grape___Esca_(Black_Measles)": "Үзэм: эска", "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)": "Үзэм: хорчилт",
    "Grape___healthy": "Үзэм: эрүүл", "Potato___Early_blight": "Төмс: эрт хорчилт",
    "Potato___Late_blight": "Төмс: хожуу хорчилт", "Potato___healthy": "Төмс: эрүүл",
    "Tomato___Bacterial_spot": "Лооль: бакт. толбо", "Tomato___Early_blight": "Лооль: эрт хорчилт",
    "Tomato___Late_blight": "Лооль: хожуу хорчилт", "Tomato___Leaf_Mold": "Лооль: хөгц",
    "Tomato___Septoria_leaf_spot": "Лооль: септориоз", "Tomato___Spider_mites Two-spotted_spider_mite": "Лооль: хачиг",
    "Tomato___Target_Spot": "Лооль: бай толбо", "Tomato___Tomato_Yellow_Leaf_Curl_Virus": "Лооль: TYLCV",
    "Tomato___Tomato_mosaic_virus": "Лооль: мозайк", "Tomato___healthy": "Лооль: эрүүл",
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--metrics", default="../backend/model/metrics.json")
    ap.add_argument("--out", default="../docs")
    a = ap.parse_args()
    m = json.load(open(a.metrics))
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    plt.rcParams["font.family"] = "DejaVu Sans"

    h = m["history"]
    ep = [x["epoch"] for x in h]
    fig, ax = plt.subplots(1, 2, figsize=(10, 3.6))
    ax[0].plot(ep, [x["loss"] for x in h], color="#2E7D32", lw=2)
    ax[0].set_title("Сургалтын алдагдал (loss)")
    ax[0].set_xlabel("Эпох")
    ax[1].plot(ep, [x["train_acc"] for x in h], label="Сургалт", color="#2E7D32", lw=2)
    ax[1].plot(ep, [x["val_acc"] for x in h], label="Баталгаажуулалт", color="#E65100", lw=2)
    ax[1].set_title("Нарийвчлал")
    ax[1].set_xlabel("Эпох")
    ax[1].set_ylim(0.3, 1.0)
    ax[1].legend(frameon=False)
    for x in ax:
        x.spines[["top", "right"]].set_visible(False)
        x.grid(alpha=0.25)
    fig.tight_layout()
    fig.savefig(out / "training_curve.png", dpi=150)

    cm = np.array(m["confusion_matrix"], dtype=float)
    norm = cm / cm.sum(1, keepdims=True).clip(min=1)
    labels = [SHORT.get(c, c) for c in m["classes"]]
    fig, ax = plt.subplots(figsize=(11, 9.5))
    ax.imshow(norm, cmap="Greens", vmin=0, vmax=1)
    ax.set_xticks(range(len(labels)), labels, rotation=90, fontsize=8)
    ax.set_yticks(range(len(labels)), labels, fontsize=8)
    for i in range(len(labels)):
        for j in range(len(labels)):
            if cm[i, j]:
                ax.text(j, i, int(cm[i, j]), ha="center", va="center", fontsize=6.5,
                        color="white" if norm[i, j] > 0.6 else "black")
    ax.set_xlabel("Таамагласан")
    ax.set_ylabel("Жинхэнэ")
    ax.set_title(f"Confusion matrix — тест олонлог (нарийвчлал {m['test_accuracy'] * 100:.1f}%)")
    fig.tight_layout()
    fig.savefig(out / "confusion_matrix.png", dpi=150)
    print("saved", out)


if __name__ == "__main__":
    main()
