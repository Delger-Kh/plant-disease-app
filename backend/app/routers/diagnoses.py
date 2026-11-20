from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import MEDIA_DIR
from ..database import get_db
from ..models import Diagnosis, User
from ..schemas import DiagnosisOut
from ..security import get_current_user
from ..services import diagnose, to_out

router = APIRouter(prefix="/api/diagnoses", tags=["Оношилгоо"])


@router.post("", response_model=DiagnosisOut, status_code=201)
async def create(file: UploadFile = File(...), note: str = Form(""),
                 user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """US-03/04/05/06: Навчны зураг илгээж онош, гэмтлийн зураг, эмчилгээний зөвлөмж авах."""
    data = await file.read()
    if not data:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Хоосон файл ирлээ.")
    d = diagnose(db, user, data, note)
    return to_out(db, d)


@router.get("", response_model=list[DiagnosisOut])
def history(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Оношилгооны түүх (шинэ нь эхэндээ)."""
    rows = db.scalars(select(Diagnosis).where(Diagnosis.user_id == user.id)
                      .order_by(Diagnosis.created_at.desc(), Diagnosis.id.desc())).all()
    return [to_out(db, d) for d in rows]


def _get_own(db: Session, diag_id: int, user: User) -> Diagnosis:
    d = db.get(Diagnosis, diag_id)
    if d is None or (d.user_id != user.id and user.role != "admin"):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Онош олдсонгүй.")
    return d


@router.get("/{diag_id}", response_model=DiagnosisOut)
def get_one(diag_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return to_out(db, _get_own(db, diag_id, user))


@router.delete("/{diag_id}", status_code=204)
def delete(diag_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    d = _get_own(db, diag_id, user)
    for name in (d.image_path, d.overlay_path):
        (MEDIA_DIR / name).unlink(missing_ok=True)
    db.delete(d)
    db.commit()
