"""Тохиргоо. Бүх утгыг орчны хувьсагчаар (environment variable) өөрчилж болно."""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent



def _secret_key() -> str:
    """SECRET_KEY өгөөгүй бол анх асахад санамсаргүй түлхүүр үүсгэж .secret_key файлд хадгална."""
    if os.getenv("SECRET_KEY"):
        return os.environ["SECRET_KEY"]
    f = BASE_DIR / ".secret_key"
    if not f.exists():
        import secrets
        f.write_text(secrets.token_urlsafe(48))
    return f.read_text().strip()


SECRET_KEY = _secret_key()
TOKEN_HOURS = int(os.getenv("TOKEN_HOURS", "72"))
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{BASE_DIR / 'plant.db'}")
MEDIA_DIR = Path(os.getenv("MEDIA_DIR", str(BASE_DIR / "media")))
MODEL_DIR = Path(os.getenv("MODEL_DIR", str(BASE_DIR / "model")))

# Анхны админ хэрэглэгч (сервер анх асахад автоматаар үүснэ)
ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "admin@plant.mn")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "admin123")
ADMIN_NAME = os.getenv("ADMIN_NAME", "Админ")

# AI-ийн итгэлцэл үүнээс бага бол онош "Хянах шаардлагатай" төлөвт орно (Лаб 5-ын sequence)
CONFIDENCE_THRESHOLD = float(os.getenv("CONFIDENCE_THRESHOLD", "0.70"))
MAX_UPLOAD_MB = int(os.getenv("MAX_UPLOAD_MB", "10"))

MEDIA_DIR.mkdir(parents=True, exist_ok=True)
