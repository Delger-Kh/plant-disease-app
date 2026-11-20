"""Ургамлын навчны өвчин таних жижиг CNN-ийг эхнээс нь сургаж, ONNX болгон гаргана.

Ашиглах нь:
    python train.py --data data.npz --out ../backend/model --epochs 30
"""
import argparse
import json
import time
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

MEAN = torch.tensor([0.485, 0.456, 0.406]).view(1, 3, 1, 1)
STD = torch.tensor([0.229, 0.224, 0.225]).view(1, 3, 1, 1)


def conv_bn(cin, cout, stride=1):
    return nn.Sequential(nn.Conv2d(cin, cout, 3, stride=stride, padding=1, bias=False),
                         nn.BatchNorm2d(cout), nn.ReLU(inplace=True))


class PlantCNN(nn.Module):
    """Хөнгөн CNN: stride-2 эхлэл + 4 конволюцийн шат + Global Average Pooling + ангилагч.

    128x128 -> 64 -> 32 -> 16 -> 8 хэмжээтэй онцлог зураг (feature map).
    """

    def __init__(self, n_classes):
        super().__init__()
        self.features = nn.Sequential(
            conv_bn(3, 32, stride=2),                 # 64x64
            conv_bn(32, 64), nn.MaxPool2d(2),         # 32x32
            conv_bn(64, 128), nn.MaxPool2d(2),        # 16x16
            conv_bn(128, 256), nn.MaxPool2d(2),       # 8x8
            conv_bn(256, 256),
        )
        self.drop = nn.Dropout(0.3)
        self.fc = nn.Linear(256, n_classes)

    def forward(self, x):  # x: [N,3,128,128], аль хэдийн нормчлогдсон
        x = self.features(x)
        x = F.adaptive_avg_pool2d(x, 1).flatten(1)
        return self.fc(self.drop(x))


def to_tensor(xb):
    x = torch.from_numpy(xb).permute(0, 3, 1, 2).float() / 255.0
    return (x - MEAN) / STD


def augment(x):
    """Багцын түвшний санамсаргүй өөрчлөлт: эргүүлэх, тусгах, гэрэл/өнгө, шилжүүлэх."""
    n = x.shape[0]
    if np.random.rand() < 0.5:
        x = x.flip(3)
    if np.random.rand() < 0.5:
        x = x.flip(2)
    k = np.random.randint(4)
    if k:
        x = torch.rot90(x, k, (2, 3))
    # гэрэлтүүлэг ба контраст (зураг бүрт)
    b = (torch.rand(n, 1, 1, 1) - 0.5) * 0.6
    c = 1 + (torch.rand(n, 1, 1, 1) - 0.5) * 0.5
    x = x * c + b
    # жижиг масштаб/шилжилт
    theta = torch.zeros(n, 2, 3)
    s = 1 + (torch.rand(n) - 0.5) * 0.3
    theta[:, 0, 0] = s
    theta[:, 1, 1] = s
    theta[:, :, 2] = (torch.rand(n, 2) - 0.5) * 0.2
    grid = F.affine_grid(theta, x.shape, align_corners=False)
    return F.grid_sample(x, grid, padding_mode="reflection", align_corners=False)


@torch.no_grad()
def evaluate(model, X, y, bs=256):
    model.eval()
    preds = []
    for i in range(0, len(X), bs):
        xb = to_tensor(X[i:i + bs])
        logits = model(xb) + model(xb.flip(3))  # TTA: хэвтээ тусгал
        preds.append(logits.argmax(1).numpy())
    p = np.concatenate(preds)
    return float((p == y).mean()), p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="data.npz")
    ap.add_argument("--out", default="../backend/model")
    ap.add_argument("--epochs", type=int, default=30)
    ap.add_argument("--bs", type=int, default=64)
    ap.add_argument("--lr", type=float, default=3e-3)
    a = ap.parse_args()

    torch.manual_seed(0)
    np.random.seed(0)
    torch.set_num_threads(max(1, torch.get_num_threads()))
    d = np.load(a.data)
    X, y, classes = d["X"], d["y"], [str(c) for c in d["classes"]]
    tr, va, te = d["tr"], d["va"], d["te"]
    model = PlantCNN(len(classes))
    n_params = sum(p.numel() for p in model.parameters())
    print("classes", len(classes), "params", n_params, "train", len(tr))

    opt = torch.optim.AdamW(model.parameters(), lr=a.lr, weight_decay=5e-4)
    steps = a.epochs * ((len(tr) + a.bs - 1) // a.bs)
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=a.lr, total_steps=steps, pct_start=0.2)
    hist = []
    best, best_state = -1, None
    for ep in range(a.epochs):
        model.train()
        t0 = time.time()
        perm = np.random.permutation(tr)
        tot, correct, loss_sum = 0, 0, 0.0
        for i in range(0, len(perm), a.bs):
            idx = perm[i:i + a.bs]
            xb = augment(to_tensor(X[idx]))
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
        va_acc, _ = evaluate(model, X[va], y[va])
        hist.append(dict(epoch=ep + 1, loss=loss_sum / tot, train_acc=correct / tot, val_acc=va_acc))
        print(f"ep {ep + 1:2d} loss {loss_sum / tot:.3f} train {correct / tot:.3f} val {va_acc:.3f} "
              f"({time.time() - t0:.0f}s)", flush=True)
        if va_acc >= best:
            best = va_acc
            best_state = {k: v.clone() for k, v in model.state_dict().items()}

    model.load_state_dict(best_state)
    te_acc, te_pred = evaluate(model, X[te], y[te])
    cm = np.zeros((len(classes), len(classes)), dtype=int)
    for t, p in zip(y[te], te_pred):
        cm[t, p] += 1
    per_class = {}
    for i, c in enumerate(classes):
        tp = cm[i, i]
        prec = tp / max(1, cm[:, i].sum())
        rec = tp / max(1, cm[i].sum())
        per_class[c] = dict(precision=round(float(prec), 4), recall=round(float(rec), 4),
                            f1=round(float(2 * prec * rec / max(1e-9, prec + rec)), 4), support=int(cm[i].sum()))
    print("TEST ACC", te_acc)

    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    torch.save(model.state_dict(), out / "plant_cnn.pt")
    model.eval()
    dummy = torch.randn(1, 3, 128, 128)
    torch.onnx.export(model, dummy, out / "plant_cnn.onnx", input_names=["input"], output_names=["logits"],
                      dynamic_axes={"input": {0: "batch"}, "logits": {0: "batch"}}, opset_version=17,
                      dynamo=False)
    json.dump(dict(classes=classes, input_size=128, mean=MEAN.flatten().tolist(), std=STD.flatten().tolist()),
              open(out / "labels.json", "w"), indent=1)
    json.dump(dict(test_accuracy=te_acc, best_val_accuracy=best, n_params=n_params, n_train=int(len(tr)),
                   n_val=int(len(va)), n_test=int(len(te)), history=hist, per_class=per_class,
                   confusion_matrix=cm.tolist(), classes=classes),
              open(out / "metrics.json", "w"), indent=1)
    print("saved to", out)


if __name__ == "__main__":
    main()
