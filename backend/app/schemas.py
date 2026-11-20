"""API-ийн оролт, гаралтын бүтэц (Pydantic)."""
from datetime import datetime, timezone

from pydantic import BaseModel, ConfigDict, Field, field_validator


class RegisterIn(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    email: str = Field(min_length=5, max_length=120)
    password: str = Field(min_length=6, max_length=128)

    @field_validator("email")
    @classmethod
    def check_email(cls, v: str) -> str:
        v = v.strip().lower()
        if "@" not in v or "." not in v.split("@")[-1]:
            raise ValueError("И-мэйл буруу байна")
        return v


class LoginIn(BaseModel):
    email: str
    password: str


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    email: str
    role: str
    is_active: bool
    created_at: datetime

    @field_validator("created_at")
    @classmethod
    def utc(cls, v: datetime) -> datetime:
        return v.replace(tzinfo=timezone.utc) if v.tzinfo is None else v


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class ProfileUpdateIn(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=100)
    password: str | None = Field(default=None, min_length=6, max_length=128)


class TreatmentIO(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int | None = None
    method: str = Field(min_length=1, max_length=200)
    is_organic: bool = True
    instructions: str = ""


class DiseaseShort(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    key: str
    plant: str
    name_mn: str
    name_en: str
    is_healthy: bool
    pathogen: str = ""


class DiseaseOut(DiseaseShort):
    symptoms: str
    description: str
    prevention: str
    treatments: list[TreatmentIO]


class DiseaseIn(BaseModel):
    key: str = Field(min_length=1, max_length=120)
    plant: str = Field(min_length=1, max_length=60)
    name_mn: str = Field(min_length=1, max_length=160)
    name_en: str = ""
    pathogen: str = ""
    symptoms: str = ""
    description: str = ""
    prevention: str = ""
    is_healthy: bool = False
    treatments: list[TreatmentIO] = []


class Prediction(BaseModel):
    key: str
    name_mn: str
    plant: str
    confidence: float


class DiagnosisOut(BaseModel):
    id: int
    created_at: datetime
    status: str
    status_label: str
    confidence: float
    affected_pct: float
    severity: str
    message: str
    note: str
    image_url: str
    overlay_url: str
    disease: DiseaseOut | None
    top_predictions: list[Prediction]
    warnings: list[str]
    user_name: str


class DiagnosisReviewIn(BaseModel):
    disease_id: int


class UserAdminUpdateIn(BaseModel):
    role: str | None = Field(default=None, pattern="^(user|admin)$")
    is_active: bool | None = None


class StatsOut(BaseModel):
    users: int
    diagnoses: int
    needs_review: int
    diseases: int
    top_diseases: list[dict]
    last_7_days: list[dict]
