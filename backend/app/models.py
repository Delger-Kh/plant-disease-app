"""Өгөгдлийн сангийн хүснэгтүүд (Лаб 5-ын Class диаграмтай нийцнэ)."""
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def now_utc():
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    email: Mapped[str] = mapped_column(String(120), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(20), default="user")  # "user" | "admin"
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)

    diagnoses: Mapped[list["Diagnosis"]] = relationship(back_populates="user", cascade="all, delete-orphan")


class Disease(Base):
    __tablename__ = "diseases"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    key: Mapped[str] = mapped_column(String(120), unique=True, index=True)  # AI загварын ангиллын нэр
    plant: Mapped[str] = mapped_column(String(60))
    name_mn: Mapped[str] = mapped_column(String(160))
    name_en: Mapped[str] = mapped_column(String(160), default="")
    pathogen: Mapped[str] = mapped_column(String(200), default="")
    symptoms: Mapped[str] = mapped_column(Text, default="")
    description: Mapped[str] = mapped_column(Text, default="")
    prevention: Mapped[str] = mapped_column(Text, default="")
    is_healthy: Mapped[bool] = mapped_column(Boolean, default=False)

    treatments: Mapped[list["Treatment"]] = relationship(
        back_populates="disease", cascade="all, delete-orphan", order_by="Treatment.id")


class Treatment(Base):
    __tablename__ = "treatments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    disease_id: Mapped[int] = mapped_column(ForeignKey("diseases.id", ondelete="CASCADE"))
    method: Mapped[str] = mapped_column(String(200))
    is_organic: Mapped[bool] = mapped_column(Boolean, default=True)
    instructions: Mapped[str] = mapped_column(Text, default="")

    disease: Mapped[Disease] = relationship(back_populates="treatments")


class Diagnosis(Base):
    __tablename__ = "diagnoses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    disease_id: Mapped[int | None] = mapped_column(ForeignKey("diseases.id", ondelete="SET NULL"), nullable=True)
    predicted_key: Mapped[str] = mapped_column(String(120))
    confidence: Mapped[float] = mapped_column(Float)
    affected_pct: Mapped[float] = mapped_column(Float, default=0.0)
    severity: Mapped[str] = mapped_column(String(40), default="")
    # "ai_done" — AI итгэлтэй; "needs_review" — итгэлцэл бага; "confirmed" — админ баталсан
    status: Mapped[str] = mapped_column(String(20), default="ai_done")
    top_predictions: Mapped[str] = mapped_column(Text, default="[]")  # JSON
    warnings: Mapped[str] = mapped_column(Text, default="[]")  # JSON
    note: Mapped[str] = mapped_column(String(300), default="")
    image_path: Mapped[str] = mapped_column(String(255))
    overlay_path: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)

    user: Mapped[User] = relationship(back_populates="diagnoses")
    disease: Mapped[Disease | None] = relationship()
