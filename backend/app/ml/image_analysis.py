"""Зургийн чанар шалгах ба навчны гэмтсэн хэсгийг ялгах (сегментчилэл).

OpenCV шаардахгүй — зөвхөн Pillow + NumPy ашиглана.

Сегментчиллийн арга (өнгөний орон зай HSV дээр):
  1. Навчны бүс: ногоон пикселээс эхэлж, шар/хүрэн ургамлын пикселээр дамжин ургуулна (том үхжсэн
     хэсгийг оруулах), навч доторх толбыг бөглөнө. Хүрэн дэвсгэр (хөрс) рүү урсвал зөвхөн ногоонд
     залгаа нарийн ирмэгийг авна.
  2. Гэмтэл: навчны бүс доторх шарласан/хүрэн, улаан-нил ягаан, хар үхжсэн пиксел.
  3. Гэмтлийн хувь = гэмтлийн пиксел / навчны пиксел.
"""
from dataclasses import dataclass, field

import numpy as np
from PIL import Image, ImageFilter

ANALYSIS_SIZE = 256


@dataclass
class QualityReport:
    ok: bool
    errors: list[str] = field(default_factory=list)    # зургийг хүлээж авахгүй шалтгаан
    warnings: list[str] = field(default_factory=list)  # анхааруулга (онош хийгдэнэ)
    blur_score: float = 0.0
    brightness: float = 0.0
    leaf_fraction: float = 0.0


@dataclass
class Segmentation:
    leaf_mask: np.ndarray
    lesion_mask: np.ndarray
    affected_pct: float


def _hsv(img: Image.Image) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    a = np.asarray(img.convert("HSV"), dtype=np.float32)
    return a[..., 0] * (360.0 / 255.0), a[..., 1] / 255.0, a[..., 2] / 255.0


def _close(mask: np.ndarray, size: int) -> np.ndarray:
    m = Image.fromarray((mask * 255).astype(np.uint8))
    m = m.filter(ImageFilter.MaxFilter(size)).filter(ImageFilter.MinFilter(size))
    return np.asarray(m) > 127


def _open(mask: np.ndarray, size: int) -> np.ndarray:
    m = Image.fromarray((mask * 255).astype(np.uint8))
    m = m.filter(ImageFilter.MinFilter(size)).filter(ImageFilter.MaxFilter(size))
    return np.asarray(m) > 127


def _fill_holes(mask: np.ndarray) -> np.ndarray:
    """Хүрээнээс хүрч чадахгүй 'нүх'-ийг бөглөнө (навч доторх хар толбыг навчинд оруулах)."""
    h, w = mask.shape
    outside = np.zeros_like(mask)
    bg = ~mask
    # хүрээн дээрх фон пикселээс эхлэн давталттай тэлэлт (BFS-ийг вектороор)
    outside[0, :] = bg[0, :]
    outside[-1, :] = bg[-1, :]
    outside[:, 0] = bg[:, 0]
    outside[:, -1] = bg[:, -1]
    for _ in range(h + w):
        grown = outside.copy()
        grown[1:, :] |= outside[:-1, :]
        grown[:-1, :] |= outside[1:, :]
        grown[:, 1:] |= outside[:, :-1]
        grown[:, :-1] |= outside[:, 1:]
        grown &= bg
        if np.array_equal(grown, outside):
            break
        outside = grown
    return ~outside


def resize_for_analysis(img: Image.Image) -> Image.Image:
    img = img.convert("RGB")
    w, h = img.size
    s = ANALYSIS_SIZE / max(w, h)
    return img.resize((max(1, round(w * s)), max(1, round(h * s))), Image.BILINEAR)


def _dilate(mask: np.ndarray, size: int) -> np.ndarray:
    m = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(size))
    return np.asarray(m) > 127


def leaf_mask(img_small: Image.Image) -> np.ndarray:
    """Навчны бүс.

    Ногоон пикселээс эхэлж (хөрс, мод зэрэг хүрэн дэвсгэрийг навч гэж андуурахгүйн тулд),
    жижиг завсрыг хааж, навч доторх толбыг (нүх) бөглөнө. Дараа нь ногоон хэсэгт шууд залгаа
    шар/хүрэн ирмэгийг (ирмэгийн үхжил) нэмнэ. Ногоон бараг байхгүй бол (бүхэлдээ хатсан навч)
    ханамж/өнгөнд суурилсан ерөнхий маскийг ашиглана.
    """
    H, S, V = _hsv(img_small)
    plant = (S > 0.18) & (V > 0.12) & (H >= 15) & (H <= 170)
    green = (S > 0.18) & (V > 0.10) & (H >= 60) & (H <= 170)
    green = _open(green, 3)
    if green.mean() < 0.02:
        m = _close(_open(plant, 3), 7)
        return _fill_holes(m)
    core = _fill_holes(_close(green, 9))
    # Ногоон цөмөөс шар/хүрэн (ургамлын) пикселээр дамжин ургуулна — том үхжсэн хэсгийг навчинд оруулна.
    grown = _grow(core, plant | core, steps=80)
    added = grown & ~core
    border = np.concatenate([added[0], added[-1], added[:, 0], added[:, -1]])
    if border.mean() > 0.12:
        # Хүрэн дэвсгэр (хөрс, мод) рүү "урссан" — зөвхөн ногоонд залгаа нарийн ирмэгийг авна.
        grown = core | (plant & _dilate(core, 9))
    return _fill_holes(_close(grown, 5))


def _grow(seed: np.ndarray, allowed: np.ndarray, steps: int) -> np.ndarray:
    """Геодезийн тэлэлт: seed-ээс зөвхөн allowed пикселээр дамжин 4-хөршөөр тэлнэ."""
    cur = seed & allowed
    for _ in range(steps):
        nxt = cur.copy()
        nxt[1:, :] |= cur[:-1, :]
        nxt[:-1, :] |= cur[1:, :]
        nxt[:, 1:] |= cur[:, :-1]
        nxt[:, :-1] |= cur[:, 1:]
        nxt &= allowed
        if np.array_equal(nxt, cur):
            break
        cur = nxt
    return cur


def check_quality(img: Image.Image) -> QualityReport:
    rep = QualityReport(ok=True)
    w, h = img.size
    if min(w, h) < 96:
        rep.errors.append("Зургийн хэмжээ хэт жижиг байна (хамгийн багадаа 96×96 пиксел).")
    small = resize_for_analysis(img)
    gray = np.asarray(small.convert("L"), dtype=np.float32)
    rep.brightness = float(gray.mean())
    # Лапласын дисперс — бүдэг зураг бага утгатай
    lap = (-4 * gray[1:-1, 1:-1] + gray[:-2, 1:-1] + gray[2:, 1:-1] + gray[1:-1, :-2] + gray[1:-1, 2:])
    rep.blur_score = float(lap.var())
    if rep.brightness < 25:
        rep.errors.append("Зураг хэт харанхуй байна. Гэрэлтэй газар дахин авна уу.")
    elif rep.brightness > 240:
        rep.errors.append("Зураг хэт гэрэлтэй (цайсан) байна. Нарны шууд тусгалаас зайлсхийнэ үү.")
    if rep.blur_score < 8:
        rep.errors.append("Зураг бүдэг байна. Камераа тогтвортой барьж, навч руу фокуслаад дахин авна уу.")
    elif rep.blur_score < 25:
        rep.warnings.append("Зураг бага зэрэг бүдэг байна — үр дүн алдаатай байж болзошгүй.")
    rep.leaf_fraction = float(leaf_mask(small).mean())
    if rep.leaf_fraction < 0.04:
        rep.errors.append("Зурган дээр навч олдсонгүй. Нэг навчийг ойроос, бүтнээр нь авна уу.")
    elif rep.leaf_fraction < 0.12:
        rep.warnings.append("Навч зургийн жижиг хэсгийг эзэлж байна — ойроос авбал илүү нарийвчлалтай.")
    rep.ok = not rep.errors
    return rep


def segment(img: Image.Image) -> Segmentation:
    small = resize_for_analysis(img)
    leaf = leaf_mask(small)
    H, S, V = _hsv(small)
    green = (H >= 60) & (H <= 170)
    # Гэмтлийн өнгө: шарласан/хүрэн/улбар (хлороз, үхжил), улаан-нил ягаан толбо, хар үхжил.
    yellow_brown = (H >= 10) & (H < 58) & (S > 0.28) & (V > 0.12)
    red_purple = ((H < 10) | (H > 300)) & (S > 0.25) & (V > 0.12)
    necrotic = (V < 0.22) & ~green
    lesion = leaf & (yellow_brown | red_purple | necrotic)
    lesion = _open(lesion, 3)
    lesion &= leaf
    leaf_px = int(leaf.sum())
    pct = 100.0 * float(lesion.sum()) / leaf_px if leaf_px else 0.0
    return Segmentation(leaf_mask=leaf, lesion_mask=lesion, affected_pct=round(pct, 1))


def severity_label(affected_pct: float, is_healthy: bool) -> str:
    if is_healthy:
        return "Эрүүл"
    if affected_pct < 5:
        return "Анхан шат"
    if affected_pct < 15:
        return "Бага"
    if affected_pct < 35:
        return "Дунд"
    return "Хүнд"


def make_overlay(img: Image.Image, seg: Segmentation, max_side: int = 640) -> Image.Image:
    """Гэмтсэн хэсгийг улаанаар, навчны хүрээг ногооноор тодруулсан зураг."""
    img = img.convert("RGB")
    w, h = img.size
    s = min(1.0, max_side / max(w, h))
    base = img.resize((max(1, round(w * s)), max(1, round(h * s))), Image.BILINEAR)
    size = base.size
    lesion = Image.fromarray((seg.lesion_mask * 255).astype(np.uint8)).resize(size, Image.NEAREST)
    leaf = Image.fromarray((seg.leaf_mask * 255).astype(np.uint8)).resize(size, Image.NEAREST)
    edge = np.asarray(leaf.filter(ImageFilter.FIND_EDGES)) > 0
    edge = np.asarray(Image.fromarray(edge.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(3))) > 0

    out = np.asarray(base, dtype=np.float32).copy()
    m = np.asarray(lesion) > 127
    red = np.array([230, 30, 40], dtype=np.float32)
    out[m] = out[m] * 0.45 + red * 0.55
    out[edge] = np.array([60, 220, 90], dtype=np.float32)
    return Image.fromarray(out.clip(0, 255).astype(np.uint8))
