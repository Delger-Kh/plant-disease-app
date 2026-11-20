# 🌿 Ургамлын эмч — Ургамлын өвчин илрүүлэх болон арчилгааны зөвлөх систем

Навчны зургийг утсаараа авч илгээхэд AI загвар өвчнийг таньж, гэмтсэн хэсгийг зураг дээр тодруулан,
эмчилгээ ба арчилгааны зөвлөгөө өгдөг мобайл апп.

**Баг 16:** Э.Энхсаруул · Х.Дэлгэр · Ч.Оюумаа

| Хэсэг | Технологи |
|---|---|
| Мобайл апп | Flutter (Android, iOS, Web) |
| Backend API | Python · FastAPI · SQLAlchemy · SQLite · JWT |
| AI загвар | PyTorch-оор сургасан CNN → ONNX Runtime (25 анги, 5 ургамал) |
| Гэмтэл ялгах | HSV өнгөний сегментчилэл (Pillow + NumPy) |

---

## 1. Боломжууд (User Story-той уялдуулсан)

| User Story | Хэрэгжүүлсэн байдал | Апп-ын дэлгэц | API |
|---|---|---|---|
| US-01 Бүртгүүлэх | Нэр, и-мэйл, нууц үг (≥6), давхардал шалгана | Бүртгүүлэх | `POST /api/auth/register` |
| US-02 Нэвтрэх | JWT токен, апп хаагдсан ч нэвтэрсэн хэвээр | Нэвтрэх | `POST /api/auth/login` |
| US-03 Навчны зураг оруулах | Камер / галерей, зургийн чанар шалгах (бүдэг, харанхуй, навчгүй бол дахин авахыг хүснэ) | Оношлох | `POST /api/diagnoses` |
| US-04 Оношийн үр дүн | Өвчний нэр, AI итгэлцэл, бусад 2 боломжит онош | Үр дүн | 〃 |
| US-05 Эмчилгээний зөвлөгөө | Органик ба химийн арга, урьдчилан сэргийлэх | Үр дүн | 〃 |
| US-06 Сегментчилэл | Гэмтсэн хэсэг улаанаар тодорно, гэмтлийн % ба зэрэг (Анхан шат / Бага / Дунд / Хүнд) | Үр дүн → «Гэмтэл» | 〃 |
| US-07 Ургамлын жагсаалт | Таньдаг 5 ургамлаар шүүх | Өвчний сан | `GET /api/diseases/plants` |
| US-08 Өвчний сангаас хайх | Нэр, шинж тэмдгээр хайх | Өвчний сан | `GET /api/diseases?q=` |
| US-09 Админ панель | Статистик, 7 хоногийн график, хэрэглэгч удирдах | Админ → Тойм, Хэрэглэгч | `/api/admin/*` |
| US-10 Админ өвчин нэмэх | Эмчилгээний жагсаалттай | Админ → Өвчин → «Өвчин нэмэх» | `POST /api/admin/diseases` |
| US-11 Мэдээлэл засах | | Админ → Өвчин → дарах | `PUT /api/admin/diseases/{id}` |
| US-12 Зохисгүй мэдээлэл устгах | Өвчин, онош, хэрэглэгч устгах | Админ | `DELETE ...` |
| Нэмэлт | AI итгэлцэл 70%-иас бага бол «Мэргэжилтний хяналт шаардлагатай» төлөвт орж, админ зөв оношийг сонгон батална (Лаб 5-ын sequence диаграмын `alt` хэсэг) | Админ → Хянах | `PATCH /api/admin/diagnoses/{id}` |

> US-ийн дугаарлалтыг Лаб 2–3-ын Backlog-тойгоо тулгаж шалгаарай.

## 2. Архитектур (Лаб 5: Layered + Client-Server)

```
┌───────────────────────┐    HTTP/JSON + JWT     ┌──────────────────────────────────────────┐
│  Presentation         │ ─────────────────────▶ │  FastAPI (backend/app)                   │
│  Flutter апп (mobile) │ ◀───────────────────── │  routers/  — API давхарга                │
│  дэлгэцүүд, ApiClient │     зураг (multipart)  │  services.py — Business логик            │
└───────────────────────┘                        │  ml/predictor.py — CNN (ONNX)            │
                                                 │  ml/image_analysis.py — чанар, сегмент   │
                                                 │  models.py — Data давхарга (SQLAlchemy)  │
                                                 └───────────────┬──────────────────────────┘
                                                                 ▼
                                                     SQLite (plant.db) + media/ зургууд
```

Онош хийх урсгал: зураг ирэх → чанар шалгах (муу бол 422 + шалтгаан) → CNN таамаглал (тусгалын TTA)
→ сегментчилэл ба гэмтлийн % → зураг хадгалах → итгэлцэл < 70% бол `needs_review` → DB-д бичих → үр дүн.

## 3. Ажиллуулах заавар

### 3.1 Backend (Python 3.10+)

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Эсвэл товчхондоо `./run.sh` (macOS/Linux) эсвэл `run.bat` (Windows).

- API баримт бичиг (Swagger): <http://localhost:8000/docs>
- Анхны админ: **admin@plant.mn / admin123** (`ADMIN_EMAIL`, `ADMIN_PASSWORD` орчны хувьсагчаар солино)
- Анх асахад мэдээллийн сан, 25 өвчний мэдлэгийн сан, админ хэрэглэгч автоматаар үүснэ.

### 3.2 Flutter апп

Flutter SDK 3.22 буюу түүнээс шинэ хувилбар хэрэгтэй (`flutter --version`).

```bash
cd mobile
flutter create . --project-name plant_doctor --platforms=android,ios,web   # платформын хавтсуудыг үүсгэнэ (lib/ хөндөгдөхгүй)
flutter pub get
flutter run                 # Android эмулятор эсвэл холбосон утас
flutter run -d chrome       # вэб хөтөч дээр хурдан турших
```

`flutter create .` нь зөвхөн дутуу файлуудыг нэмдэг тул бидний `lib/`, `test/`,
`android/app/src/main/AndroidManifest.xml` (интернэт зөвшөөрөл, http холболт) хэвээр үлдэнэ.

**Серверийн хаяг** (апп-ын нэвтрэх дэлгэцийн баруун дээд дүрс эсвэл Профайл → Серверийн хаяг):

| Хаанаас ажиллуулж байна | Хаяг |
|---|---|
| Android эмулятор | `http://10.0.2.2:8000` (анхны утга) |
| Chrome / iOS симулятор | `http://localhost:8000` (анхны утга) |
| Жинхэнэ утас | `http://<компьютерын IP>:8000` — утас, компьютер нэг Wi-Fi-д; IP-г `ipconfig getifaddr en0` (Mac) эсвэл `ipconfig` (Windows)-оор харна |

**iOS дээр** `ios/Runner/Info.plist`-д дараахыг нэмнэ:

```xml
<key>NSCameraUsageDescription</key>
<string>Навчны зураг авахад камер ашиглана</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Навчны зураг сонгоход галерей ашиглана</string>
<key>NSAppTransportSecurity</key>
<dict><key>NSAllowsArbitraryLoads</key><true/></dict>
```

### 3.3 Турших

```bash
cd backend && pip install pytest httpx && python -m pytest -q    # 21 тест
cd mobile && flutter test                                        # widget + JSON тест
```

`backend/sample_images/` дотор сургалтад ороогүй 8 дээж зураг бий — апп-аар оруулж туршиж болно.

## 4. AI загвар

- **Өгөгдөл:** PlantVillage — алим, эрдэнэ шиш, усан үзэм, төмс, улаан лооль; 25 анги, нийт 9,600 зураг
  (анги бүрээс ≤400), 80/10/10 хуваалт (сургалт 7,680 · баталгаажуулалт 960 · тест 960).
- **Загвар:** 5 давхаргат хөнгөн CNN (BatchNorm, Global Average Pooling), ~1 сая параметр, 128×128 оролт.
  Санамсаргүй эргүүлэлт, тусгал, гэрэл/контраст, масштабын өсгөлттэйгөөр эхнээс нь сургасан.
- **Дэвсгэрийн өсгөлт (fine-tune):** PlantVillage-ийн бүх зураг саарал дэвсгэртэй тул утсаар авсан зураг дээр
  загвар андуурч байсан. Иймд навчны маскаар дэвсгэрийг хөрс, өвс, ширээ мэт санамсаргүй бүтцээр сольж,
  навчийг жижигрүүлж 8 эпох нэмж сургасан (`ml/finetune_backgrounds.py`).
- **Үр дүн (сургалтад ороогүй 960 тест зураг):**

| Загвар | Саарал дэвсгэр (PlantVillage) | Санамсаргүй дэвсгэр |
|---|---|---|
| Анхны CNN (22 эпох) | 98.8% | 32.0% |
| **Апп-д ашиглаж буй** (+ дэвсгэрийн fine-tune) | **95.6%** | **88.1%** |

  Анги тус бүрийн үзүүлэлт: `backend/model/metrics.json`; графикууд: `docs/training_curve.png`,
  `docs/confusion_matrix.png`. Хамгийн их андуурдаг нь улаан лоолийн бай толбо → эрүүл (40-өөс 9),
  мөн улаан лоолийн хожуу хорчилт → төмсний хожуу хорчилт (нэг үүсгэгчтэй өвчин).

Дахин сургах:

```bash
cd ml
pip install torch onnx pillow numpy matplotlib
python prepare_data.py --src <PlantVillage-Dataset/raw/color> --out data/data.npz
python train.py --data data/data.npz --out ../backend/model --epochs 22
python finetune_backgrounds.py --data data/data.npz --model ../backend/model --epochs 8
python plot_metrics.py
```

### Хязгаарлалт

- PlantVillage-ийн зургууд лабораторид, нэг өнгийн дэвсгэр дээр авсан. Талбайд, олон навчтай, нарийн
  дэвсгэртэй зураг дээр нарийвчлал буурна — тиймээс апп нэг навчийг энгийн дэвсгэр дээр авахыг зөвлөдөг,
  итгэлцэл бага үед мэргэжилтний хяналт руу шилжүүлдэг.
- Зөвхөн 5 ургамлын 25 ангиллыг таньдаг. Шинэ ургамал нэмэхэд загварыг дахин сургаж, админаас
  өвчний санд ижил `key`-тэй бичлэг нэмнэ.
- Гэмтлийн хувь нь өнгөнд суурилсан ойролцоо үнэлгээ (шар, хүрэн, хар толбо). Мозайк вирус зэрэг
  цайвар ногоон алаг хээг бүрэн илрүүлэхгүй.
- Эмчилгээний зөвлөмж нь ерөнхий мэдээлэл; химийн бодисыг шошгоны дагуу хэрэглэнэ.

## 5. Хавтасны бүтэц

```
plant-disease-app/
├── backend/
│   ├── app/
│   │   ├── main.py              # FastAPI апп, эхлүүлэх
│   │   ├── config.py            # тохиргоо (орчны хувьсагч)
│   │   ├── database.py, models.py, schemas.py, security.py
│   │   ├── services.py          # онош хийх бизнес логик
│   │   ├── knowledge_base.py    # 25 өвчний монгол мэдээлэл, эмчилгээ
│   │   ├── seed.py
│   │   ├── ml/predictor.py      # ONNX загвар
│   │   ├── ml/image_analysis.py # чанар шалгах, сегментчилэл, overlay
│   │   └── routers/             # auth, diagnoses, diseases, admin
│   ├── model/                   # plant_cnn.onnx, labels.json, metrics.json
│   ├── sample_images/
│   ├── tests/
│   ├── requirements.txt, run.sh, run.bat
├── mobile/
│   ├── lib/
│   │   ├── main.dart            # апп, AuthGate
│   │   ├── models.dart
│   │   ├── services/api_client.dart
│   │   ├── widgets/common.dart
│   │   └── screens/             # login, register, diagnose, result, history, library, profile, admin/
│   ├── test/widget_test.dart
│   ├── android/app/src/main/AndroidManifest.xml
│   └── pubspec.yaml
├── ml/                          # prepare_data.py, train.py
└── docs/                        # графикууд
```

