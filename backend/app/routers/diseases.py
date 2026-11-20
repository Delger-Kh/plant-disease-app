from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Disease, User
from ..schemas import DiseaseOut, DiseaseShort
from ..security import get_current_user

router = APIRouter(prefix="/api/diseases", tags=["Өвчний сан"])


@router.get("", response_model=list[DiseaseShort])
def list_diseases(q: str = "", plant: str = "", _: User = Depends(get_current_user),
                  db: Session = Depends(get_db)):
    """US-08: Өвчний сангаас хайх."""
    stmt = select(Disease).order_by(Disease.plant, Disease.is_healthy, Disease.name_mn)
    if plant:
        stmt = stmt.where(Disease.plant == plant)
    if q:
        like = f"%{q}%"
        stmt = stmt.where(or_(Disease.name_mn.ilike(like), Disease.name_en.ilike(like),
                              Disease.plant.ilike(like), Disease.symptoms.ilike(like)))
    return db.scalars(stmt).all()


@router.get("/plants", response_model=list[str])
def plants(_: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """US-07: Апп таньж чадах ургамлын жагсаалт."""
    return sorted(set(db.scalars(select(Disease.plant)).all()))


@router.get("/{disease_id}", response_model=DiseaseOut)
def get_disease(disease_id: int, _: User = Depends(get_current_user), db: Session = Depends(get_db)):
    d = db.get(Disease, disease_id)
    if d is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Өвчин олдсонгүй.")
    return d
