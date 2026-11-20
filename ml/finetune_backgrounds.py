"""Дэвсгэрийн өсгөлттэй нэмэлт сургалт (fine-tune).

PlantVillage-ийн бүх зураг саарал дэвсгэртэй тул утсаар авсан (хөрс, өвс, гар, ширээ) зураг дээр
загвар андуурдаг. Энэ скрипт навчны маскаар дэвсгэрийг санамсаргүй бүтэцтэй дэвсгэрээр сольж,
навчийг жижигрүүлэх/шилжүүлэх замаар сургасан загварыг үргэлжлүүлэн сургана.

    python finetune_backgrounds.py --data data/data.npz --model ../backend/model --epochs 8
"""
import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image

from train import PlantCNN, augment, evaluate, to_tensor

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "backend"))
from app.ml.image_analysis import leaf_mask, resize_for_analysis  # noqa: E402


def compute_masks(X):
    out = np.zeros(X.shape[:3], dtype=bool)
    for i, x in enumerate(X):
        im = Image.fromarray(x)
        m = leaf_mask(resize_for_analysis(im))
        out[i] = np.asarray(Image.fromarray(m.astype(np.uint8) * 255).resize(im.size, Image.NEAREST)) > 127
    return out


def random_backgrounds(n, size, rng):
    """Бага давтамжтай өнгөт толбо + нарийн шуугиан: хөрс, өвс, мод, даавуу шиг бүтэц."""
    bgs = np.empty((n, size, size, 3), dtype=np.float32)
    palettes = np.array([[120, 95, 70], [95, 75, 55], [90, 115, 60], [60, 90, 45], [160, 140, 115],
                         [200, 190, 175], [70, 70, 75], [140, 110, 90], [225, 225, 220], [40, 45, 40]],
                        dtype=np.float32)
    for i in range(n):
        base = palettes[rng.integers(len(palettes))] + rng.normal(0, 15, 3)
        g = rng.integers(2, 9)
        low = rng.normal(0, rng.uniform(10, 45), (g, g, 3)).astype(np.float32)
        low = np.asarray(Image.fromarray(np.uint8(np.clip(low + 128, 0, 255))).resize((size, size), Image.BICUBIC),
                         dtype=np.float32) - 128
        fine = rng.normal(0, rng.uniform(3, 22), (size, size, 3))
        bgs[i] = np.clip(base + low + fine, 0, 255)
    return bgs


def compose(xb, mb, rng, p=0.6):
    """xb: [N,H,W,3] uint8, mb: [N,H,W] bool -> дэвсгэр сольсон, заримыг нь жижигрүүлсэн uint8."""
    n, s = xb.shape[0], xb.shape[1]
    out = xb.astype(np.float32).copy()
    sel = rng.random(n) < p
    if sel.any():
        bgs = random_backgrounds(int(sel.sum()), s, rng)
        for j, i in enumerate(np.where(sel)[0]):
            leaf, m = out[i], mb[i]
            if rng.random() < 0.4:  # навчийг жижигрүүлж, санамсаргүй байрлалд
                k = rng.uniform(0.6, 0.9)
                ns = max(16, int(s * k))
                leaf = np.asarray(Image.fromarray(leaf.astype(np.uint8)).resize((ns, ns), Image.BILINEAR),
                                  dtype=np.float32)
                m = np.asarray(Image.fromarray(m.astype(np.uint8) * 255).resize((ns, ns), Image.NEAREST)) > 127
                ox, oy = rng.integers(0, s - ns + 1, 2)
                big, bm = np.zeros((s, s, 3), np.float32), np.zeros((s, s), bool)
                big[oy:oy + ns, ox:ox + ns], bm[oy:oy + ns, ox:ox + ns] = leaf, m
                leaf, m = big, bm
            out[i] = np.where(m[..., None], leaf, bgs[j])
    return out.clip(0, 255).astype(np.uint8)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="data/data.npz")
    ap.add_argument("--model", default="../backend/model")
    ap.add_argument("--epochs", type=int, default=8)
    ap.add_argument("--bs", type=int, default=64)
    ap.add_argument("--lr", type=float, default=1e-3)
    a = ap.parse_args()
    torch.manual_seed(1)
    rng = np.random.default_rng(1)
    d = np.load(a.data)
    X, y, classes = d["X"], d["y"], [str(c) for c in d["classes"]]
    tr, va, te = d["tr"], d["va"], d["te"]
    mpath = Path(a.data).with_name("masks.npy")
    if mpath.exists():
        M = np.load(mpath)
    else:
        t0 = time.time()
        M = compute_masks(X)
        np.save(mpath, M)
        print(f"masks {time.time() - t0:.0f}s, mean leaf {M.mean():.2f}", flush=True)

    model_dir = Path(a.model)
    model = PlantCNN(len(classes))
    model.load_state_dict(torch.load(model_dir / "plant_cnn.pt"))
    # тогтмол "дэвсгэр сольсон" баталгаажуулалт ба тест олонлог (өөр seed)
    Xva_bg = compose(X[va], M[va], np.random.default_rng(123), p=1.0)
    Xte_bg = compose(X[te], M[te], np.random.default_rng(456), p=1.0)
    print("before: val", evaluate(model, X[va], y[va])[0], "val_bg", evaluate(model, Xva_bg, y[va])[0], flush=True)

    opt = torch.optim.AdamW(model.parameters(), lr=a.lr, weight_decay=5e-4)
    steps = a.epochs * ((len(tr) + a.bs - 1) // a.bs)
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=a.lr, total_steps=steps, pct_start=0.15)
    hist, best, best_state = [], -1, None
    for ep in range(a.epochs):
        model.train()
        t0 = time.time()
        perm = rng.permutation(tr)
        tot = correct = 0
        loss_sum = 0.0
        for i in range(0, len(perm), a.bs):
            idx = perm[i:i + a.bs]
            xb = augment(to_tensor(compose(X[idx], M[idx], rng)))
            yb = torch.from_numpy(y[idx])
            out = model(xb)
            loss = F.cross_entropy(out, yb, label_smoothing=0.05)
            opt.zero_grad()
            loss.backward()
            opt.step()
            sched.step()
            loss_sum += loss.item() * len(idx)
            correct += (out.argmax(1) == yb).sum().item()
            tot += len(idx)
        v, vb = evaluate(model, X[va], y[va])[0], evaluate(model, Xva_bg, y[va])[0]
        hist.append(dict(epoch=ep + 1, loss=loss_sum / tot, train_acc=correct / tot, val_acc=v, val_bg_acc=vb))
        print(f"ft {ep + 1} loss {loss_sum / tot:.3f} train {correct / tot:.3f} val {v:.3f} val_bg {vb:.3f} "
              f"({time.time() - t0:.0f}s)", flush=True)
        if v + vb >= best:
            best, best_state = v + vb, {k: t.clone() for k, t in model.state_dict().items()}

    model.load_state_dict(best_state)
    te_acc, te_pred = evaluate(model, X[te], y[te])
    te_bg_acc, _ = evaluate(model, Xte_bg, y[te])
    print("TEST plain", te_acc, "TEST bg", te_bg_acc, flush=True)

    cm = np.zeros((len(classes), len(classes)), dtype=int)
    for t, p in zip(y[te], te_pred):
        cm[t, p] += 1
    per_class = {}
    for i, c in enumerate(classes):
        tp = cm[i, i]
        prec, rec = tp / max(1, cm[:, i].sum()), tp / max(1, cm[i].sum())
        per_class[c] = dict(precision=round(float(prec), 4), recall=round(float(rec), 4),
                            f1=round(float(2 * prec * rec / max(1e-9, prec + rec)), 4), support=int(cm[i].sum()))
    torch.save(model.state_dict(), model_dir / "plant_cnn.pt")
    model.eval()
    torch.onnx.export(model, torch.randn(1, 3, 128, 128), model_dir / "plant_cnn.onnx", input_names=["input"],
                      output_names=["logits"], dynamic_axes={"input": {0: "batch"}, "logits": {0: "batch"}},
                      opset_version=17, dynamo=False)
    old = json.loads((model_dir / "metrics.json").read_text())
    old.update(test_accuracy=te_acc, test_accuracy_random_background=te_bg_acc, per_class=per_class,
               confusion_matrix=cm.tolist(), finetune_history=hist)
    (model_dir / "metrics.json").write_text(json.dumps(old, indent=1))
    print("saved", model_dir)


if __name__ == "__main__":
    main()
