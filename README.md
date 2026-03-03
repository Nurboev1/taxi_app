# SafarUz MVP (Uzbekiston intercity + qishloq-shahar)

Ushbu repo ikki qismdan iborat:
- `backend`: FastAPI + PostgreSQL
- `mobile`: Flutter mobil ilova (Driver va Passenger)
- `infra`: Docker Compose (PostgreSQL)

## Asosiy biznes qoidalari (MVP)
- 2 ta rol: `driver` (taxist), `passenger` (mijoz)
- `TripGig`: haydovchi safar yaratadi
- `RequestGig`: mijoz so‘rov yaratadi
- Match sharti:
  - vaqt oralig‘i kesishishi: `driver_start <= passenger_end AND driver_end >= passenger_start`
  - bo‘sh joy yetarli bo‘lishi
  - yo‘nalish matn mosligi (`exact/contains`)
- Claim qoidasi:
  - bitta so‘rovga eng ko‘pi bilan 10 ta haydovchi claim bera oladi
  - birinchi kelgan birinchi oladi
  - 10 ga yetganda status `locked`
  - race condition oldini olish uchun PostgreSQL transaction + `SELECT ... FOR UPDATE`
  - `UNIQUE(request_id, driver_id)` bilan takror claim bloklanadi
- Mijoz tanlaganda:
  - request `chosen`
  - bitta claim `accepted`, qolganlari `rejected`
  - tripda `seats_taken` yangilanadi
  - chat yaratiladi
  - haydovchi telefoni faqat shu bosqichdan keyin ko‘rinadi

## 1) Infra ishga tushirish
`infra` ichida:

```bash
docker compose up -d
```

PostgreSQL: `localhost:5432`, DB: `taxi_db`, user/pass: `taxi/taxi`

## 2) Backend ishga tushirish
`backend/.env` yarating:

```env
APP_NAME=SafarUz MVP
ENV=dev
SECRET_KEY=super-secret-key-change-me
ACCESS_TOKEN_EXPIRE_MINUTES=10080
DATABASE_URL=postgresql+psycopg2://taxi:taxi@localhost:5432/taxi_db
```

So‘ng:

```bash
cd backend
python -m venv .venv
# Windows:
.venv\Scripts\activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Ixtiyoriy seed:

```bash
python seed.py
```

## 3) Flutter mobil ishga tushirish

```bash
cd mobile
flutter pub get
flutter run
```

Agar Android emulatorda backendga ulansangiz, `10.0.2.2:8000` ishlatilgan.

## API endpointlar
- `POST /auth/request-otp`
- `POST /auth/verify-otp`
- `POST /role/set`
- `POST /driver/trips`
- `GET /driver/trips/my`
- `POST /passenger/requests`
- `GET /passenger/requests/{id}`
- `GET /requests/{id}/matches`
- `POST /requests/{id}/claim`
- `GET /requests/{id}/claims`
- `POST /requests/{id}/choose`
- `GET /chats/{id}`
- `POST /chats/{id}/messages`
- `WS /ws/chats/{id}`

## Auth test rejimi
- OTP endpointga request yuboring
- tekshirish kodi doim: `0000`

## MVP route matching hozircha
Hozirgi implementatsiya matn bo‘yicha `exact/contains`.

Keyin yaxshilash mumkin:
- viloyat/tuman/city reference jadvallari
- normalizatsiya (lotin/kiril, kichik-katta harf)
- geospatial (PostGIS) + radius bo‘yicha match

## Muhim eslatma
UIdagi barcha foydalanuvchi matnlari Uzbek tilida yozilgan.
Kod kommentlari inglizcha bo‘lishi mumkin.

