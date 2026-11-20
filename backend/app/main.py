"""Ургамлын өвчин илрүүлэх систем — REST API.

Ажиллуулах:  uvicorn app.main:app --host 0.0.0.0 --port 8000
Баримт бичиг: http://localhost:8000/docs
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .config import MEDIA_DIR
from .database import Base, SessionLocal, engine
from .ml.predictor import get_predictor
from .routers import admin, auth, diagnoses, diseases
from .seed import seed


@asynccontextmanager
async def lifespan(_: FastAPI):
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        seed(db)
    get_predictor()  # загварыг урьдчилан ачаална
    yield


app = FastAPI(title="Ургамлын өвчин илрүүлэх систем API", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.mount("/media", StaticFiles(directory=MEDIA_DIR), name="media")

app.include_router(auth.router)
app.include_router(diagnoses.router)
app.include_router(diseases.router)
app.include_router(admin.router)


@app.get("/api/health", tags=["Систем"])
def health():
    p = get_predictor()
    return {"status": "ok", "model_classes": len(p.classes)}
