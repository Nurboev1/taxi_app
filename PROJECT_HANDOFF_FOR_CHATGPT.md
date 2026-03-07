# SafarUz Project Handoff (for next ChatGPT)

Last updated: 2026-03-07 (Asia/Tashkent)
Repository: `Nurboev1/taxi_app`
Main branch head (local): `dcf0a91`

## 1) Maqsad
Bu hujjatning maqsadi: boshqa ChatGPT yoki yangi developer shu faylni o'qib, loyihani qayerda to'xtagan bo'lsa, o'sha joydan davom ettira olsin.

Ushbu loyiha 2 qismdan iborat:
- Backend: FastAPI + SQLAlchemy + PostgreSQL
- Mobile: Flutter (Android/iOS), Riverpod + GoRouter

Qo'shimcha:
- Admin panel (FastAPI + Jinja2)
- SMS OTP (hozir DevSMS)
- Push notifications (Firebase FCM v1/legacy) + local fallback polling

---

## 2) Joriy holat (snapshot)

### 2.1 Git holati
So'nggi commitlar:
- `dcf0a91` Fix bcrypt runtime error and enforce password byte limit
- `bd4d225` release
- `6313eed` nothing
- `ee800ac` almost ... ready..

Ishchi daraxtda hozir WIP (commit qilinmagan) fayllar bor:
- `backend/app/api/deps.py`
- `mobile/lib/app.dart`
- `mobile/lib/core/api/endpoints.dart`
- `mobile/lib/core/widgets/daytime_wave_background.dart`
- `mobile/lib/core/widgets/neo_shell.dart`
- `mobile/lib/features/auth/auth_page.dart`
- `mobile/lib/features/auth/otp_page.dart`
- `mobile/lib/features/driver/driver_home_page.dart`
- `mobile/lib/features/passenger/passenger_home_page.dart`
- `mobile/lib/features/auth/password_login_page.dart` (new)
- `mobile/lib/features/auth/set_password_page.dart` (new)

Demak hozirgi branch toza emas. Davom ettirishdan oldin shu WIP ni alohida commit qilish kerak.

### 2.2 Product nomi
UI title: `SafarUz`.
Ba'zi joylarda eski nom (`Surxon Taxi`) matn yoki env ichida qolgan.

---

## 3) Repo tuzilmasi

Root ichida asosiy papkalar:
- `backend/` - FastAPI backend
- `mobile/` - Flutter app
- `infra/` - docker-compose (Postgres)

Eslatma: rootda eski Flutter shell (`android/`, `ios/`, `lib/`) ham bor. Real aktiv mobil kod `mobile/` ichida.

---

## 4) Backend batafsil

### 4.1 Entry point va routerlar
Fayl: `backend/app/main.py`

Routers:
- `auth`
- `admin`
- `role`
- `driver`
- `requests`
- `chat`
- `rating`
- `notifications`
- `legal`

Health:
- `GET /health` => `{ "status": "ok" }`

CORS:
- Hozir `allow_origins=["*"]` (production uchun qattiq cheklash tavsiya).

### 4.2 Sozlamalar
Fayl: `backend/app/core/settings.py`

Muhim envlar:
- `DATABASE_URL`
- `SECRET_KEY`
- `ADMIN_USERNAME`, `ADMIN_PASSWORD`
- `FCM_SERVER_KEY` (legacy)
- `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_FILE` (FCM v1)
- `SMS_PROVIDER` (`devsms` yoki `test`)
- `OTP_TTL_MINUTES`, `OTP_COOLDOWN_SECONDS`
- DevSMS parametrlari

### 4.3 Auth oqimi (eng muhim)
Fayl: `backend/app/api/auth.py`

Hozirgi flow:
1. `POST /auth/phone-status`
   - telefon bor-yo'qligi va password mavjudligini tekshiradi.
2. `POST /auth/request-otp`
   - `reason`: `register` yoki `reset_password`
3. `POST /auth/complete-otp`
   - OTP + yangi password bilan yakuniy login/token qaytaradi
4. `POST /auth/login-password`
   - oldindan password mavjud user uchun login

Legacy endpoint hali bor:
- `POST /auth/verify-otp` (passwordsiz eski flow)

Profile:
- `GET /auth/profile/me`
- `PUT /auth/profile/me`

Password qoidalari:
- minimal 8 belgi
- maksimal 72 byte (bcrypt cheklovi sabab)

OTP:
- 4 xonali random
- TTL va cooldown envdan boshqariladi

#### Tester maxsus rejimi
`_TESTER_PHONE_ALIASES`:
- `+998` -> `+998000000000`
- `+9981` -> `+998100000000`

`_TESTER_OTP_CODE = "2656"`

Bu test userlar uchun SMS pulini tejash rejimi.

### 4.4 SMS provider (DevSMS)
Fayl: `backend/app/services/devsms_sms.py`

Hozir OTP SMS matni kodda quyidagicha:
`SafarUz ilovasiga kirish uchun tasdiqlash kodi: {code}. Kod 5 daqiqa amal qiladi. Kodni hech kimga bermang.`

API call:
- URL: `<DEVSMS_BASE_URL>/send_sms.php`
- Auth: `Bearer <DEVSMS_TOKEN>`
- phone `+` belgisiz yuboriladi

### 4.5 Rol va blok logikasi
Fayllar:
- `backend/app/api/role.py`
- `backend/app/api/deps.py`
- `backend/app/models/user.py`

Userda blok fieldlar:
- `driver_blocked`
- `driver_access_override`
- `driver_block_reason`
- `driver_unblocked_at`

Joriy holat:
- Avtomatik "1 oyda auto block" o'chirilgan.
- `deps.py` ichida `_sync_driver_block_status()` no-op.
- Driver blocked bo'lsa driver endpointlarda 403 qaytadi (`DRIVER_BLOCKED`).

### 4.6 Driver safar logikasi
Fayl: `backend/app/api/driver.py`

Endpointlar:
- `POST /driver/trips`
- `GET /driver/trips/my`
- `POST /driver/trips/{trip_id}/finish`
- `GET /driver/trips/{trip_id}/passengers`
- `POST /driver/trips/{trip_id}/passengers/{request_id}/finish`
- `GET /driver/requests/open`

Muhim business logic:
- Request matching route + time + seats
- Agar mos topilmasa fallback qilib hamma open request ko'rsatish
- Har driver uchun request order deterministik aralashtirilgan (`_driver_specific_order_key`)
- Claim state mapping: `pending/accepted/rejected`

### 4.7 Passenger request/claim logikasi
Fayl: `backend/app/api/requests.py`

Endpointlar:
- `POST /passenger/requests`
- `GET /passenger/requests/{id}`
- `GET /requests/{id}/matches`
- `POST /requests/{id}/claim`
- `GET /requests/{id}/claims`
- `POST /requests/{id}/choose`

Muhim business qoidalar:
- Bitta requestga maksimal 10 claim
- Duplicate claim oldini olish: unique `(request_id, driver_id)`
- Passenger choose qilganda:
  - chosen claim -> `accepted`
  - qolganlari -> `rejected`
  - trip `seats_taken` oshadi
  - chat yaratiladi
  - driverga notification yaratiladi (`claim_accepted`)

### 4.8 Chat
Fayl: `backend/app/api/chat.py`

Endpointlar:
- `GET /chats/my`
- `GET /chats/{chat_id}`
- `POST /chats/{chat_id}/messages`
- `DELETE /chats/{chat_id}`
- `WS /ws/chats/{chat_id}?token=<jwt>`

Xususiyat:
- Chat o'chirilsa serverdan to'liq delete (ikkala tomon uchun).
- Yangi xabar yuborilganda notification yaratiladi (`chat_message`).

### 4.9 Rating
Fayl: `backend/app/api/rating.py`

Endpointlar:
- `GET /ratings/pending`
- `POST /ratings/trip/{trip_id}`
- `GET /ratings/mine/given`
- `GET /ratings/mine/received`
- `GET /ratings/summary/{user_id}`

### 4.10 Notification (backend saqlash + push)
Fayllar:
- `backend/app/api/notifications.py`
- `backend/app/services/notifications.py`
- `backend/app/services/push.py`

DB notification endpointlar:
- `GET /notifications/my`
- `POST /notifications/{id}/read`
- `POST /notifications/read-all`
- `POST /notifications/push-token`

Push yuborish:
- Avval FCM v1 (service account) uriladi
- bo'lmasa legacy key fallback
- ikkalasi ham ishlamasa warning log

### 4.11 Legal sahifalar
Fayllar:
- `backend/app/api/legal.py`
- `backend/app/templates/legal/privacy.html`
- `backend/app/templates/legal/terms.html`

URL:
- `/legal/privacy`
- `/legal/terms`

### 4.12 Admin panel
Fayl: `backend/app/api/admin.py`
Template: `backend/app/templates/admin/dashboard.html`

Endpointlar:
- `/admin/login` (GET/POST)
- `/admin/logout`
- `/admin` dashboard
- `/admin/driver-access` (block/unblock)
- `/admin/change-password` (POST)

Qila oladi:
- Statistika ko'rish
- Recent user/request
- Trips by date
- User lookup by ID
- Driver block/unblock
- Resource metrics (host/container)
- Server xatoliklari tab (`journalctl`) orqali service loglaridan `ERROR/Exception/Traceback/...` satrlarini ko'rsatish
- Admin parolini paneldan o'zgartirish (DB hash + env fallback)

---

## 5) DB sxema va migrations

Migrations:
- `0001_initial.py`
- `0002_profile_and_prefs.py`
- `0003_trip_ratings.py`
- `0004_claim_completed.py`
- `0005_user_notifications.py`
- `0006_driver_access_block.py`
- `0007_driver_unblocked_at.py`
- `0008_user_fcm_token.py`
- `0009_user_password_hash.py`
- `0010_admin_credentials.py`

Asosiy jadvallar:
- `users`
- `admin_credentials`
- `otp_codes`
- `driver_trips`
- `passenger_requests`
- `request_claims`
- `chats`
- `chat_messages`
- `trip_ratings`
- `user_notifications`

Muhim constraintlar:
- `users.phone` unique
- `request_claims` unique (`request_id`, `driver_id`)
- `chats` unique (`request_id`, `passenger_id`, `driver_id`)

---

## 6) Mobile batafsil

### 6.1 Startup
Fayl: `mobile/lib/main.dart`

Init ketma-ketligi:
- `Firebase.initializeApp()` (try/catch)
- `notificationPollerProvider.start()`
- `pushNotificationsServiceProvider.init()`
- `runApp(TaxiApp)`

### 6.2 Route xaritasi
Fayl: `mobile/lib/app.dart`

Auth routelar:
- `/auth`
- `/password-login`
- `/otp?reason=...`
- `/set-password?reason=...&otp=...`

Core routelar:
- `/role`
- `/profile-setup`
- `/profile`
- `/settings`
- `/driver`, `/driver-blocked`, `/driver/create-trip`, `/driver/my-trips`, `/driver/my-ratings`, `/driver/open-requests`, `/driver/trip-passengers/:id`
- `/passenger`, `/passenger/create-request`, `/passenger/request-status`, `/passenger/rate-trip`, `/passenger/my-ratings`
- `/chats`, `/chat/:id`
- `/notifications`

### 6.3 Auth UI flow (hozir)
Fayllar:
- `mobile/lib/features/auth/auth_page.dart`
- `mobile/lib/features/auth/password_login_page.dart`
- `mobile/lib/features/auth/otp_page.dart`
- `mobile/lib/features/auth/set_password_page.dart`
- `mobile/lib/features/auth/auth_controller.dart`

Flow:
1) `AuthPage`: telefon + legal checkbox
2) `phone-status` tekshiriladi
3a) hasPassword=true => `PasswordLoginPage`
3b) hasPassword=false => `request-otp(register)` => `OtpPage`
4) `OtpPage` (4-digit)
5) `SetPasswordPage` => `complete-otp`

Forgot password:
- `PasswordLoginPage` -> `Tasdiqlash dialog` -> `request-otp(reset_password)` -> `OtpPage` -> `SetPasswordPage`
- Ya'ni `Parolni unutdingizmi?` bosilganda OTP darhol yuborilmaydi; avval userdan tasdiq olinadi.

### 6.4 API endpoint constants
Fayl: `mobile/lib/core/api/endpoints.dart`

Default `baseUrl`:
- `https://safaruz.duckdns.org`

Release buildda `--dart-define=API_BASE_URL=...` bilan override qilish kerak.

### 6.5 Notifications (mobile)
Fayllar:
- `mobile/lib/core/notifications/notification_poller.dart`
- `mobile/lib/core/notifications/push_notifications_service.dart`
- `mobile/lib/features/notifications/notifications_controller.dart`

Mexanizm:
- Polling: har 20s `/notifications/my` so'raydi, yangi unreadlarni local notification qiladi.
- Firebase push: FCM token backendga yuboriladi (`/notifications/push-token`)
- Foreground push kelganda local notification chiqadi.

### 6.6 Theme/UI shell
Fayllar:
- `mobile/lib/app.dart` (ThemeData)
- `mobile/lib/core/widgets/neo_shell.dart`
- `mobile/lib/core/widgets/daytime_wave_background.dart`

Hozir light/dark uchun gradient fon, NeoPanel card uslubi bor.

### 6.7 I18n
Fayl: `mobile/lib/core/i18n/strings.dart`

Langlar: `uz`, `ru`, `en`.

Muhim muammo:
- RU bo'limida encoding mojibake bor (`Ð...` ko'rinish), tozalash kerak.

---

## 7) Infra va deploy

### 7.1 Docker infra
Fayl: `infra/docker-compose.yml`

Postgres konteyner:
- image: `postgres:16-alpine`
- db/user/pass: `taxi_db/taxi/taxi`
- limitlar: `mem_limit: 1g`, `cpus: 1.0`

### 7.2 Local backend run
```bash
cd backend
python -m venv .venv
# windows
.\.venv\Scripts\activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 7.3 VPS run (systemd bor deb faraz qilingan holat)
Diagnostika commandlar:
```bash
systemctl status safaruz-backend --no-pager
journalctl -u safaruz-backend -f
journalctl -u safaruz-backend -n 200 --no-pager
```

Agar DB ulanish xatosi bo'lsa:
- `.env` ichidagi `DATABASE_URL` tekshirish
- PostgreSQL service/konteyner ishlayotganini tekshirish (`ss -ltnp | grep 5432`)

### 7.4 Public domain + HTTPS (current production path)
- Domain: `safaruz.duckdns.org` (DuckDNS)
- Reverse proxy/TLS: `Caddy`
- Muhim topilgan issue: Caddy start bo'lmaganda `:80` portni `nginx` band qilgan.
- Fix: `nginx`ni to'xtatib Caddy ni ishga tushirish.

Minimal checklist:
```bash
sudo systemctl stop nginx
sudo systemctl disable nginx
sudo ss -ltnp | grep ':80 '

sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl restart caddy
sudo systemctl enable caddy
sudo systemctl status caddy --no-pager
```

Health tekshiruv:
```bash
curl https://safaruz.duckdns.org/health
```

Eslatma:
- `curl -I https://.../health` da `405 allow: GET` chiqishi normal (HEAD request sabab).
- To'g'ri tekshiruv `GET` bilan (`curl https://.../health`).

---

## 8) Build/release (mobile)

```bash
cd mobile
flutter clean
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://safaruz.duckdns.org
```

APK odatda shu yerda:
- `mobile/build/app/outputs/flutter-apk/app-release.apk`

---

## 9) Integratsiyalar

### 9.1 DevSMS
Kerakli envlar:
- `SMS_PROVIDER=devsms`
- `DEVSMS_BASE_URL`
- `DEVSMS_TOKEN`
- `DEVSMS_FROM`

### 9.2 Firebase push
Kerakli envlar:
- `FCM_PROJECT_ID`
- `FCM_SERVICE_ACCOUNT_FILE` (backend serverdagi json path)

Mobile:
- `mobile/android/app/google-services.json` mavjud bo'lishi kerak.

Backendda service account json gitga qo'shilmaydi (`backend/.gitignore`da bor).

---

## 10) Security va konfiguratsiya risklari (MUHIM)

1. `backend/.env.example` ichida realga o'xshash `DEVSMS_TOKEN` bor.
   - Darhol tokenni rotate qilish va `.env.example`ni mask qilish kerak.

2. DuckDNS token chatda oshkor qilingan.
   - DuckDNS paneldan tokenni regenerate qilib scriptlarni yangilash kerak.

3. `ADMIN_PASSWORD` default (`admin123`) bo'lib ketishi mumkin.
   - productionda albatta almashtirish kerak.

4. CORS hamma origin uchun ochiq.
   - productionda frontend domainlar bilan cheklash kerak.

5. Legacy `/auth/verify-otp` endpoint hali ochiq.
   - yangi password flowga to'liq o'tilgach deprecate qilish kerak.

6. Legal/README drift:
   - README hozir kod bilan to'liq mos emas (eski OTP flow yozilgan).

---

## 11) Hozirgi ochiq kamchiliklar (tech debt)

- RU i18n matnlari encoding buzilgan.
- UIda ba'zi joylarda eski/yarim tayyor auth flow textlari qolgan bo'lishi mumkin.
- Notification delivery 2 qavatli (polling + push), duplicate risk ayrim edge-caselar bo'lishi mumkin.
- Rootda ikki xil Flutter struktura bor (confusion risk).
- Testlar deyarli yo'q (manual regressionga tayanilgan).
- Admin `Server xatoliklari` tab Linux systemd/journalctl ga bog'liq; Windows local devda ishlamasligi normal.

---

## 12) Next ChatGPT uchun aniq davom rejasi

1. WIP fayllarni review qilib bitta mantiqiy commitga yig'ish.
2. `README.md`ni hozirgi auth/password flowga moslab to'liq yangilash.
3. `backend/.env.example`dan real tokenni olib tashlash, `***` bilan mask.
4. `strings.dart`dagi RU encodingni tozalash.
5. Auth legacy endpoint (`/verify-otp`) ni bosqichma-bosqich o'chirish rejasini qilish.
6. CORS, admin creds, secrets bo'yicha production hardening.
7. `alembic upgrade head` bilan `0010_admin_credentials` migrationni productionga qo'llash.
8. Minimal integration testlar yozish:
   - register/reset/login
   - claim/choose
   - finish trip -> rating pending
   - notification create/read

---

## 13) Tez tekshiruv checklist

Backend:
- `GET /health` 200
- `GET https://safaruz.duckdns.org/health` 200
- `POST /auth/phone-status` ishlaydi
- `POST /auth/request-otp` ishlaydi
- `POST /auth/complete-otp` token qaytaradi
- `POST /auth/login-password` ishlaydi
- `/admin/login` ochiladi

Mobile:
- Phone -> OTP -> Set password flow ishlaydi
- Existing user phone -> password login ishlaydi
- Driver/passenger dashboardlar ochiladi
- Chat send/receive ishlaydi
- Notifications list ko'rinadi

---

## 14) Boshqa ChatGPTga yuborish uchun tayyor prompt

Quyidagi promptni nusxa qilib yangi chatga yuborish mumkin:

"""
Sen `taxi_app` loyihasini davom ettirayotgan senior full-stack assistantsan.

Kontekst:
- Loyihaning handoff fayli: `PROJECT_HANDOFF_FOR_CHATGPT.md`
- Asosiy stack: FastAPI + PostgreSQL + Flutter
- Hozirgi auth flow: phone-status -> request-otp -> complete-otp + password login
- reset password flow: "Parolni unutdingizmi?" bosilganda avval tasdiqlash oynasi chiqadi
- Tester aliases: +998, +9981; tester OTP: 2656
- Mobile base URL default: https://safaruz.duckdns.org
- WIP fayllar mavjud (git statusga qarab ishlagin)

Birinchi ish:
1) `git status` va handoffdagi open issuesni tekshir
2) README va .env.example ni production-safe holatga keltir
3) RU i18n encodingni tuzat
4) O'zgartirishdan keyin release build commandini ber

Ish jarayonida har o'zgartirishni fayl nomi bilan aniq yoz.
"""

---

## 15) Muhim fayllar ro'yxati

Backend:
- `backend/app/main.py`
- `backend/app/core/settings.py`
- `backend/app/core/security.py`
- `backend/app/api/auth.py`
- `backend/app/api/role.py`
- `backend/app/api/driver.py`
- `backend/app/api/requests.py`
- `backend/app/api/chat.py`
- `backend/app/api/rating.py`
- `backend/app/api/notifications.py`
- `backend/app/api/admin.py`
- `backend/app/services/devsms_sms.py`
- `backend/app/services/push.py`
- `backend/app/services/notifications.py`
- `backend/app/models/user.py`
- `backend/app/schemas/auth.py`
- `backend/alembic/versions/*.py`

Mobile:
- `mobile/lib/main.dart`
- `mobile/lib/app.dart`
- `mobile/lib/core/api/endpoints.dart`
- `mobile/lib/features/auth/auth_controller.dart`
- `mobile/lib/features/auth/auth_page.dart`
- `mobile/lib/features/auth/password_login_page.dart`
- `mobile/lib/features/auth/otp_page.dart`
- `mobile/lib/features/auth/set_password_page.dart`
- `mobile/lib/core/notifications/notification_poller.dart`
- `mobile/lib/core/notifications/push_notifications_service.dart`
- `mobile/lib/core/i18n/strings.dart`
- `mobile/pubspec.yaml`

Infra:
- `infra/docker-compose.yml`

---

## 16) Yakuniy eslatma
Bu hujjat yozilgan paytda loyiha ishlayotgan, lekin konfiguratsiya va xavfsizlik bo'yicha bir nechta muhim risklar bor (token, CORS, default admin, legacy endpoint). Davom ettiruvchi assistant avval shu risklarni yopishi kerak.
