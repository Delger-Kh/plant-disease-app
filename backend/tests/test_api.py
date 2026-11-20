"""API-ийн бүрэн урсгалын тестүүд: бүртгэл → онош → түүх → админ."""
import io

import pytest
from PIL import Image, ImageFilter

from conftest import SAMPLES

# Дээж зураг → загварын хүлээгдэж буй ангилал (PlantVillage-ийн сургалтад ороогүй тест зургууд)
EXPECTED = {
    "tomato_early_blight.jpg": "Tomato___Early_blight",
    "tomato_healthy.jpg": "Tomato___healthy",
    "potato_late_blight.jpg": "Potato___Late_blight",
    "apple_scab.jpg": "Apple___Apple_scab",
    "corn_common_rust.jpg": "Corn_(maize)___Common_rust_",
    "grape_black_rot.jpg": "Grape___Black_rot",
    "tomato_leaf_mold.jpg": "Tomato___Leaf_Mold",
    "potato_healthy.jpg": "Potato___healthy",
}


def _upload(client, headers, name, note=""):
    with open(SAMPLES / name, "rb") as f:
        return client.post("/api/diagnoses", headers=headers, files={"file": (name, f, "image/jpeg")},
                           data={"note": note})


def _png(img):
    b = io.BytesIO()
    img.save(b, "PNG")
    return b.getvalue()


# ------------------------------------------------------------------ Нэвтрэлт
def test_health(client):
    r = client.get("/api/health")
    assert r.status_code == 200 and r.json()["model_classes"] == 25


def test_register_validation_and_duplicates(client, user_headers):
    r = client.post("/api/auth/register", json={"name": "Б", "email": "муу", "password": "1"})
    assert r.status_code == 422
    r = client.post("/api/auth/register", json={"name": "Бат", "email": "BAT@test.mn", "password": "secret123"})
    assert r.status_code == 409


def test_login_wrong_password(client, user_headers):
    r = client.post("/api/auth/login", json={"email": "bat@test.mn", "password": "буруу"})
    assert r.status_code == 401
    assert "буруу" in r.json()["detail"]


def test_me_and_profile_update(client, user_headers):
    r = client.get("/api/auth/me", headers=user_headers)
    assert r.status_code == 200 and r.json()["role"] == "user"
    r = client.put("/api/auth/me", headers=user_headers, json={"name": "Бат-Эрдэнэ"})
    assert r.json()["name"] == "Бат-Эрдэнэ"


def test_requires_token(client):
    assert client.get("/api/diagnoses").status_code == 401
    assert client.get("/api/diagnoses", headers={"Authorization": "Bearer abc"}).status_code == 401


# ------------------------------------------------------------------ Оношилгоо
@pytest.mark.parametrize("name", list(EXPECTED))
def test_diagnose_samples(client, user_headers, name):
    r = _upload(client, user_headers, name, note="тест")
    assert r.status_code == 201, r.text
    d = r.json()
    assert d["top_predictions"][0]["key"] == EXPECTED[name], d["top_predictions"]
    assert d["disease"]["key"] == EXPECTED[name]
    assert d["disease"]["treatments"], "эмчилгээний зөвлөмж байх ёстой"
    assert 0 < d["confidence"] <= 1
    assert d["severity"]
    if d["disease"]["is_healthy"]:
        assert d["severity"] == "Эрүүл" and d["affected_pct"] < 8
    # хадгалсан зураг болон гэмтэл тодруулсан зураг татагдах ёстой
    assert client.get(d["image_url"]).status_code == 200
    assert client.get(d["overlay_url"]).status_code == 200


def test_rejects_non_leaf_and_blurry(client, user_headers):
    wall = Image.new("RGB", (400, 400), (190, 185, 180))
    r = client.post("/api/diagnoses", headers=user_headers, files={"file": ("wall.png", _png(wall), "image/png")})
    assert r.status_code == 422
    assert r.json()["detail"]["errors"]

    leaf = Image.open(SAMPLES / "tomato_early_blight.jpg").filter(ImageFilter.GaussianBlur(4))
    r = client.post("/api/diagnoses", headers=user_headers, files={"file": ("blur.png", _png(leaf), "image/png")})
    assert r.status_code == 422
    assert any("бүдэг" in e for e in r.json()["detail"]["errors"])


def test_rejects_non_image(client, user_headers):
    r = client.post("/api/diagnoses", headers=user_headers, files={"file": ("a.txt", b"hello", "text/plain")})
    assert r.status_code == 400


def test_history_privacy_and_delete(client, user_headers, other_headers):
    created = _upload(client, user_headers, "grape_black_rot.jpg").json()
    hist = client.get("/api/diagnoses", headers=user_headers).json()
    assert hist[0]["id"] == created["id"]
    # өөр хэрэглэгч харж, устгаж чадахгүй
    assert client.get(f"/api/diagnoses/{created['id']}", headers=other_headers).status_code == 404
    assert client.delete(f"/api/diagnoses/{created['id']}", headers=other_headers).status_code == 404
    assert client.delete(f"/api/diagnoses/{created['id']}", headers=user_headers).status_code == 204
    assert client.get(f"/api/diagnoses/{created['id']}", headers=user_headers).status_code == 404


# ------------------------------------------------------------------ Өвчний сан
def test_disease_library(client, user_headers):
    all_ = client.get("/api/diseases", headers=user_headers).json()
    assert len(all_) == 25
    plants = client.get("/api/diseases/plants", headers=user_headers).json()
    assert set(plants) == {"Алим", "Эрдэнэ шиш", "Усан үзэм", "Төмс", "Улаан лооль"}
    tom = client.get("/api/diseases", headers=user_headers, params={"plant": "Улаан лооль"}).json()
    assert len(tom) == 10
    found = client.get("/api/diseases", headers=user_headers, params={"q": "хорчилт"}).json()
    assert any("хорчилт" in x["name_mn"] for x in found)
    one = client.get(f"/api/diseases/{tom[0]['id']}", headers=user_headers).json()
    assert one["treatments"]


# ------------------------------------------------------------------ Админ
def test_admin_forbidden_for_user(client, user_headers):
    assert client.get("/api/admin/stats", headers=user_headers).status_code == 403


def test_admin_stats_users(client, admin_headers, user_headers):
    s = client.get("/api/admin/stats", headers=admin_headers).json()
    assert s["users"] >= 2 and s["diseases"] == 25 and len(s["last_7_days"]) == 7
    assert sum(x["count"] for x in s["last_7_days"]) == s["diagnoses"]
    users = client.get("/api/admin/users", headers=admin_headers).json()
    bat = next(u for u in users if u["email"] == "bat@test.mn")
    me = next(u for u in users if u["email"] == "admin@plant.mn")
    assert client.patch(f"/api/admin/users/{me['id']}", headers=admin_headers,
                        json={"role": "user"}).status_code == 400
    r = client.patch(f"/api/admin/users/{bat['id']}", headers=admin_headers, json={"is_active": False})
    assert r.json()["is_active"] is False
    assert client.get("/api/auth/me", headers=user_headers).status_code == 401
    client.patch(f"/api/admin/users/{bat['id']}", headers=admin_headers, json={"is_active": True})
    assert client.get("/api/auth/me", headers=user_headers).status_code == 200


def test_admin_disease_crud(client, admin_headers):
    body = {"key": "Cucumber___Powdery_mildew", "plant": "Өргөст хэмх", "name_mn": "Хэмхний цагаан хөгц",
            "treatments": [{"method": "Хүхрийн бэлдмэл", "is_organic": True, "instructions": "7 хоног тутам"}]}
    r = client.post("/api/admin/diseases", headers=admin_headers, json=body)
    assert r.status_code == 201
    did = r.json()["id"]
    assert client.post("/api/admin/diseases", headers=admin_headers, json=body).status_code == 409
    body["name_mn"] = "Өргөст хэмхний цагаан хөгц"
    body["treatments"].append({"method": "Агааржуулах", "is_organic": True})
    r = client.put(f"/api/admin/diseases/{did}", headers=admin_headers, json=body)
    assert r.json()["name_mn"] == body["name_mn"] and len(r.json()["treatments"]) == 2
    assert client.delete(f"/api/admin/diseases/{did}", headers=admin_headers).status_code == 204


def test_admin_review(client, admin_headers, user_headers):
    d = _upload(client, user_headers, "tomato_leaf_mold.jpg").json()
    healthy = client.get("/api/diseases", headers=admin_headers, params={"q": "Эрүүл улаан"}).json()[0]
    r = client.patch(f"/api/admin/diagnoses/{d['id']}", headers=admin_headers, json={"disease_id": healthy["id"]})
    assert r.status_code == 200
    assert r.json()["status"] == "confirmed" and r.json()["disease"]["is_healthy"]
    lst = client.get("/api/admin/diagnoses", headers=admin_headers, params={"status": "confirmed"}).json()
    assert any(x["id"] == d["id"] for x in lst)
    # хэрэглэгч өөрийн түүхэндээ баталгаажсан төлөвийг харна
    mine = client.get(f"/api/diagnoses/{d['id']}", headers=user_headers).json()
    assert mine["status_label"] == "Мэргэжилтэн баталсан"
