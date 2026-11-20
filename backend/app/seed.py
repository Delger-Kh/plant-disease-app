"""Анхны өгөгдөл: админ хэрэглэгч ба өвчний мэдлэгийн сан."""
from sqlalchemy import select
from sqlalchemy.orm import Session

from .config import ADMIN_EMAIL, ADMIN_NAME, ADMIN_PASSWORD
from .knowledge_base import DISEASES
from .models import Disease, Treatment, User
from .security import hash_password


def seed(db: Session) -> None:
    if not db.scalar(select(User).where(User.email == ADMIN_EMAIL)):
        db.add(User(name=ADMIN_NAME, email=ADMIN_EMAIL, password_hash=hash_password(ADMIN_PASSWORD),
                    role="admin"))
    existing = set(db.scalars(select(Disease.key)).all())
    for item in DISEASES:
        if item["key"] in existing:
            continue  # админ зассан өгөгдлийг дарж бичихгүй
        d = Disease(**{k: v for k, v in item.items() if k != "treatments"})
        d.treatments = [Treatment(**t) for t in item["treatments"]]
        db.add(d)
    db.commit()
