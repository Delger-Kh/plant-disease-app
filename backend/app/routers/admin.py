from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Diagnosis, Disease, Treatment, User
from ..schemas import (DiagnosisOut, DiagnosisReviewIn, DiseaseIn, DiseaseOut, StatsOut, UserAdminUpdateIn,
                       UserOut)
from ..security import require_admin
from ..services import to_out

router = APIRouter(prefix="/api/admin", tags=["Админ"])


@router.get("/stats", response_model=StatsOut)
def stats(_: User = Depends(require_admin), db: Session = Depends(get_db)):
    top = db.execute(
        select(Disease.name_mn, func.count(Diagnosis.id))
        .join(Diagnosis, Diagnosis.disease_id == Disease.id)
        .where(Disease.is_healthy.is_(False))
        .group_by(Disease.id).order_by(func.count(Diagnosis.id).desc()).limit(5)
    ).all()
    today = datetime.now(timezone.utc).date()
    days = []
    rows = db.scalars(select(Diagnosis.created_at)
                      .where(Diagnosis.created_at >= datetime.now(timezone.utc) - timedelta(days=7))).all()
    for i in range(6, -1, -1):
        day = today - timedelta(days=i)
        days.append({"date": day.isoformat(), "count": sum(1 for r in rows if r.date() == day)})
    return StatsOut(
        users=db.scalar(select(func.count(User.id))),
        diagnoses=db.scalar(select(func.count(Diagnosis.id))),
        needs_review=db.scalar(select(func.count(Diagnosis.id)).where(Diagnosis.status == "needs_review")),
        diseases=db.scalar(select(func.count(Disease.id))),
        top_diseases=[{"name": n, "count": c} for n, c in top],
        last_7_days=days,
    )


# ------------------------------------------------------------- Хэрэглэгчид
@router.get("/users", response_model=list[UserOut])
def users(_: User = Depends(require_admin), db: Session = Depends(get_db)):
    return db.scalars(select(User).order_by(User.created_at.desc())).all()


@router.patch("/users/{user_id}", response_model=UserOut)
def update_user(user_id: int, body: UserAdminUpdateIn, admin: User = Depends(require_admin),
                db: Session = Depends(get_db)):
    u = db.get(User, user_id)
    if u is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Хэрэглэгч олдсонгүй.")
    if u.id == admin.id and (body.role == "user" or body.is_active is False):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Өөрийнхөө админ эрхийг хасах боломжгүй.")
    if body.role is not None:
        u.role = body.role
    if body.is_active is not None:
        u.is_active = body.is_active
    db.commit()
    db.refresh(u)
    return u


@router.delete("/users/{user_id}", status_code=204)
def delete_user(user_id: int, admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    u = db.get(User, user_id)
    if u is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Хэрэглэгч олдсонгүй.")
    if u.id == admin.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Өөрийгөө устгах боломжгүй.")
    db.delete(u)
    db.commit()


# ------------------------------------------------------- Өвчний сан (US-10/11/12)
def _apply(d: Disease, body: DiseaseIn):
    for f in ("key", "plant", "name_mn", "name_en", "pathogen", "symptoms", "description", "prevention",
              "is_healthy"):
        setattr(d, f, getattr(body, f))
    d.treatments.clear()
    for t in body.treatments:
        d.treatments.append(Treatment(method=t.method, is_organic=t.is_organic, instructions=t.instructions))


@router.post("/diseases", response_model=DiseaseOut, status_code=201)
def create_disease(body: DiseaseIn, _: User = Depends(require_admin), db: Session = Depends(get_db)):
    if db.scalar(select(Disease).where(Disease.key == body.key)):
        raise HTTPException(status.HTTP_409_CONFLICT, "Ийм түлхүүртэй (key) өвчин аль хэдийн байна.")
    d = Disease()
    _apply(d, body)
    db.add(d)
    db.commit()
    db.refresh(d)
    return d


@router.put("/diseases/{disease_id}", response_model=DiseaseOut)
def update_disease(disease_id: int, body: DiseaseIn, _: User = Depends(require_admin),
                   db: Session = Depends(get_db)):
    d = db.get(Disease, disease_id)
    if d is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Өвчин олдсонгүй.")
    other = db.scalar(select(Disease).where(Disease.key == body.key, Disease.id != disease_id))
    if other:
        raise HTTPException(status.HTTP_409_CONFLICT, "Ийм түлхүүртэй (key) өвчин аль хэдийн байна.")
    _apply(d, body)
    db.commit()
    db.refresh(d)
    return d


@router.delete("/diseases/{disease_id}", status_code=204)
def delete_disease(disease_id: int, _: User = Depends(require_admin), db: Session = Depends(get_db)):
    d = db.get(Disease, disease_id)
    if d is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Өвчин олдсонгүй.")
    db.delete(d)
    db.commit()


# ---------------------------------------------------- Итгэлцэл багатай оношийг хянах
@router.get("/diagnoses", response_model=list[DiagnosisOut])
def all_diagnoses(status_: str = Query("", alias="status"), _: User = Depends(require_admin), db: Session = Depends(get_db)):
    stmt = select(Diagnosis).order_by(Diagnosis.created_at.desc(), Diagnosis.id.desc()).limit(200)
    if status_:
        stmt = stmt.where(Diagnosis.status == status_)
    return [to_out(db, d) for d in db.scalars(stmt).all()]


@router.patch("/diagnoses/{diag_id}", response_model=DiagnosisOut)
def review(diag_id: int, body: DiagnosisReviewIn, _: User = Depends(require_admin),
           db: Session = Depends(get_db)):
    d = db.get(Diagnosis, diag_id)
    dis = db.get(Disease, body.disease_id)
    if d is None or dis is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Онош эсвэл өвчин олдсонгүй.")
    d.disease_id = dis.id
    d.status = "confirmed"
    if dis.is_healthy:
        d.severity = "Эрүүл"
    db.commit()
    db.refresh(d)
    return to_out(db, d)
