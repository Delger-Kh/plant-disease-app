"""Онош хийх үндсэн бизнес логик (Лаб 5-ын Business давхарга)."""
import io
import json
import uuid
from datetime import datetime, timezone

from fastapi import HTTPException, status
from PIL import Image, ImageOps, UnidentifiedImageError
from sqlalchemy import select
from sqlalchemy.orm import Session

from .config import CONFIDENCE_THRESHOLD, MAX_UPLOAD_MB, MEDIA_DIR
from .ml.image_analysis import check_quality, make_overlay, segment, severity_label
from .ml.predictor import get_predictor
from .models import Diagnosis, Disease, User
from .schemas import DiagnosisOut, DiseaseOut, Prediction

STATUS_LABELS = {
    "ai_done": "AI оношилсон",
    "needs_review": "Мэргэжилтний хяналт шаардлагатай",
    "confirmed": "Мэргэжилтэн баталсан",
}


def load_image(data: bytes) -> Image.Image:
    if len(data) > MAX_UPLOAD_MB * 1024 * 1024:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                            f"Зургийн хэмжээ {MAX_UPLOAD_MB} МБ-аас хэтэрсэн байна.")
    try:
        img = Image.open(io.BytesIO(data))
        img = ImageOps.exif_transpose(img)  # утасны зургийн эргэлтийг засна
        return img.convert("RGB")
    except (UnidentifiedImageError, OSError):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Файл зураг биш эсвэл эвдэрсэн байна.")


def diagnose(db: Session, user: User, data: bytes, note: str = "") -> Diagnosis:
    img = load_image(data)

    # 1) Зургийн чанар шалгах (<<include>>). Муу бол нэмэлт зураг хүснэ (<<extend>>).
    q = check_quality(img)
    if not q.ok:
        raise HTTPException(422,
                            {"message": "Зургийн чанар хангалтгүй байна. Дахин зураг авна уу.",
                             "errors": q.errors})

    # 2) AI загвараар таамаглах
    preds = get_predictor().predict(img, top_k=3)
    key, conf = preds[0]
    disease = db.scalar(select(Disease).where(Disease.key == key))

    # 3) Гэмтсэн хэсгийг ялгах (сегментчилэл) ба зэрэглэл
    seg = segment(img)
    is_healthy = bool(disease.is_healthy) if disease else key.endswith("healthy")
    affected = 0.0 if is_healthy and seg.affected_pct < 8 else seg.affected_pct

    # 4) Зураг хадгалах
    uid = uuid.uuid4().hex
    img_name, ov_name = f"{uid}.jpg", f"{uid}_overlay.jpg"
    save = img.copy()
    save.thumbnail((1280, 1280))
    save.save(MEDIA_DIR / img_name, "JPEG", quality=88)
    make_overlay(img, seg).save(MEDIA_DIR / ov_name, "JPEG", quality=88)

    warnings = list(q.warnings)
    status_ = "ai_done"
    if conf < CONFIDENCE_THRESHOLD:
        status_ = "needs_review"
        warnings.append("AI-ийн итгэлцэл бага байна — онош мэргэжилтний хяналтад илгээгдлээ.")

    d = Diagnosis(
        user_id=user.id, disease_id=disease.id if disease else None, predicted_key=key,
        confidence=round(conf, 4), affected_pct=affected, severity=severity_label(affected, is_healthy),
        status=status_, top_predictions=json.dumps(preds), warnings=json.dumps(warnings, ensure_ascii=False),
        note=note[:300], image_path=img_name, overlay_path=ov_name,
    )
    db.add(d)
    db.commit()
    db.refresh(d)
    return d


def _message(d: Diagnosis) -> str:
    if d.disease is None:
        return "Өвчин тодорхойлогдсонгүй."
    if d.status == "needs_review":
        return (f"Магадгүй: {d.disease.name_mn}. AI итгэлтэй биш байгаа тул мэргэжилтэн хянана. "
                "Илүү тод, ойроос авсан зураг оруулбал нарийвчлал сайжирна.")
    if d.disease.is_healthy:
        return f"Таны {d.disease.plant.lower()} эрүүл байна. Одоогийн арчилгаагаа үргэлжлүүлээрэй."
    return f"{d.disease.name_mn} илэрлээ. Гэмтлийн хэмжээ: {d.affected_pct:.0f}% ({d.severity.lower()})."


def as_utc(dt: datetime) -> datetime:
    """SQLite цагийн бүсгүй хадгалдаг тул UTC гэж тэмдэглэнэ (апп локал цаг руу хөрвүүлнэ)."""
    return dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt


def to_out(db: Session, d: Diagnosis) -> DiagnosisOut:
    raw = json.loads(d.top_predictions or "[]")
    keys = [k for k, _ in raw]
    names = {x.key: x for x in db.scalars(select(Disease).where(Disease.key.in_(keys)))} if keys else {}
    top = [Prediction(key=k, confidence=round(c, 4),
                      name_mn=names[k].name_mn if k in names else k,
                      plant=names[k].plant if k in names else "")
           for k, c in raw]
    return DiagnosisOut(
        id=d.id, created_at=as_utc(d.created_at), status=d.status, status_label=STATUS_LABELS.get(d.status, d.status),
        confidence=d.confidence, affected_pct=d.affected_pct, severity=d.severity, message=_message(d),
        note=d.note, image_url=f"/media/{d.image_path}", overlay_url=f"/media/{d.overlay_path}",
        disease=DiseaseOut.model_validate(d.disease) if d.disease else None,
        top_predictions=top, warnings=json.loads(d.warnings or "[]"),
        user_name=d.user.name if d.user else "",
    )
