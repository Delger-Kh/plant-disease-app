import os
import sys
import tempfile
from pathlib import Path

import pytest

# Тест бүр түр мэдээллийн сан, түр зургийн хавтас ашиглана (жинхэнэ plant.db-д хүрэхгүй).
_tmp = tempfile.mkdtemp(prefix="plant_test_")
os.environ["DATABASE_URL"] = f"sqlite:///{_tmp}/test.db"
os.environ["MEDIA_DIR"] = f"{_tmp}/media"
os.environ.setdefault("ADMIN_EMAIL", "admin@plant.mn")
os.environ.setdefault("ADMIN_PASSWORD", "admin123")

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402

SAMPLES = Path(__file__).resolve().parent.parent / "sample_images"


@pytest.fixture(scope="session")
def client():
    with TestClient(app) as c:
        yield c


def _auth(client, email, password, name="Тест хэрэглэгч"):
    r = client.post("/api/auth/login", json={"email": email, "password": password})
    if r.status_code != 200:
        r = client.post("/api/auth/register", json={"name": name, "email": email, "password": password})
    assert r.status_code in (200, 201), r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture(scope="session")
def user_headers(client):
    return _auth(client, "bat@test.mn", "secret123", "Бат")


@pytest.fixture(scope="session")
def other_headers(client):
    return _auth(client, "dorj@test.mn", "secret123", "Дорж")


@pytest.fixture(scope="session")
def admin_headers(client):
    return _auth(client, "admin@plant.mn", "admin123")
