# SafarUz Project Handoff (for next ChatGPT)

Last updated: 2026-03-08 (Asia/Tashkent, superadmin broadcast notifications added)
Repository: `Nurboev1/taxi_app`
Main branch head (local before this handoff update): `fb7f9dc`

## 0) So'nggi yangilanish (2026-03-08)

- Admin panel audit log tizimi kengaytirildi:
  - `admin_audit_logs`ga `actor_ip`, `request_id`, `actor_user_agent`, `before_state`, `after_state` qo'shildi
  - barcha muhim admin actionlarda old/new state diff auditga yoziladi
  - audit log filterlari qo'shildi (`actor`, `action`, `target`, `request_id`, `limit`)
  - audit log CSV export qo'shildi (`admin_accounts` tabdan)
- Support ticketlar uchun SLA dashboard qo'shildi:
  - summary kartalar: `open`, `waiting_support`, `waiting_user`, `escalated`, `breached`
  - har ticketda `waiting_on`, `pending_minutes`, `auto_close_minutes_left` ko'rsatiladi
  - eskalatsiya qoidası: support navbati 30+ daqiqa (`SUPPORT_TICKET_ESCALATE_MINUTES=30`)
  - breach ko'rsatkichi: support javobidan keyin 24 soat oynasi (`SUPPORT_TICKET_AUTO_CLOSE_HOURS=24`)
  - ticketlar SLA og'irligiga qarab sortlanadi (breached/escalated birinchi)
- Support ticket status ownership qat'iylashtirildi:
  - admin paneldan qo'lda status o'zgartirish o'chirildi
  - status faqat user (`/close`) yoki 24h auto-close orqali o'zgaradi
- Admin panel UI to'liq qayta dizayn qilindi:
  - yangi login sahifasi (`backend/app/templates/admin/login.html`)
  - yangi dashboard vizual tizimi (`backend/app/templates/admin/dashboard.html`)
  - responsive layout, zamonaviy card/hero/tab kompozitsiyasi
- Dashboard logikasi yangilandi (overview tab):
  - vaqt oynasi filteri qo'shildi (`24h`, `7d`, `30d`, `90d`)
  - yangi KPIlar: yangi user/safar/so'rov, claim acceptance rate, trip fill rate, notif/chat trend
  - support KPIlar: open/waiting/breach/avg first response
  - alert blok: support breach, waiting support, blocked drivers, parolsiz userlar, server errors
  - activity feed: user signup + trip done + support ticket + admin action
  - admin action breakdown (top actionlar, period bo'yicha)
- Global Search + User 360 qo'shildi (`search360` tab):
  - bitta qidiruvdan `user/ticket/trip/request/claim/audit` entitylarini topadi
  - prefix query qo'llab-quvvatlanadi (`user:`, `ticket:`, `trip:`, `request:`, `claim:`, `audit:`)
  - topilgan user uchun 360 summary (support, notif, trips, requests, claims)
  - unified timeline (user/support/trip/request/claim/audit eventlar)
- Superadmin uchun `Broadcast` tabi qo'shildi:
  - audience: `all`, `drivers`, `passengers`
  - xabar app ichidagi `user_notifications`ga yoziladi
  - `fcm_token` mavjud userlarga push yuboriladi
  - har yuborish `admin_audit_logs`ga `broadcast_notifications_sent` action bilan yoziladi
- Telegram support oqimi kengaytirildi:
  - Media evidence: bot `photo/video/voice/audio/document`ni qabul qiladi
  - Support chat media forward: user yuborgan media support kanaliga forward qilinadi
  - Login privacy: telefon/parol kirish xabarlari botda auto-delete (`TELEGRAM_SUPPORT_DELETE_SENSITIVE_MESSAGES=true`)
- Admin `Support ticketlar` tabi kengaytirildi:
  - saved replies dropdown (`reply template`) qo'shildi
  - media uchun panelda faqat "Photo/Video/..." yuborilgani haqidagi matn ko'rinadi
  - ticket statusi UIda qo'lda o'zgartirilmaydi (faqat user `/close` yoki 24h auto-close)
- Yangi migration:
  - `backend/alembic/versions/0016_admin_audit_log_metadata.py`
- Eslatma: productionda deploydan oldin:
  - `cd /opt/safaruz/backend`
  - `source .venv/bin/activate`
  - `python -m alembic upgrade head`

## 0) So'nggi yangilanish (2026-03-07)

- Admin panelga RBAC qo'shildi:
  - Rollar: `superadmin`, `support`, `ops`
  - Yangi tab: `Admin accountlar`
  - Superadmin shu tabdan role bilan yangi admin account yarata oladi
  - Tablar rolega qarab ko'rinadi (ruxsatsiz tabga kirsa `overview`ga qaytadi)
- Admin account boshqaruvi kengaydi:
  - `activate/deactivate`
  - admin account parolini reset qilish
  - audit log (`admin_audit_logs`) ko'rinishi
- Xavfsizlik yangilandi:
  - Auth endpointlarga process-level rate-limit qo'shildi (`request-otp`, `complete-otp`, `login-password`, `verify-otp`)
  - CORS `*`dan env-based aniq ro'yxatga o'tdi (`CORS_ALLOWED_ORIGINS`)
- Monitoring qo'shildi:
  - Sentry integratsiya (`SENTRY_DSN` orqali)
  - `/health` endpointi `deep=true` da `db/sms/fcm` tekshiradi
  - Deep health degradeda `503` qaytaradi
  - `HEALTHCHECK_FAIL_ON_SMS`, `HEALTHCHECK_FAIL_ON_FCM` orqali strictlik boshqariladi
- Telegram support bot backendga ulandi:
  - Yangi endpoint: `POST /support/contact` (auth required)
  - Telegramga support xabar yuboradi (`TELEGRAM_SUPPORT_BOT_TOKEN`, `TELEGRAM_SUPPORT_CHAT_ID`)
  - Health deep checkga `telegram_support` qo'shildi
- Telegram bot orqali support auth oqimi qo'shildi:
  - `POST /support/telegram/webhook`
  - Botda ketma-ket: telefon -> parol -> support xabari
  - Support xabarlari DBga ticket sifatida saqlanadi
- Admin panelga `Support ticketlar` tabi qo'shildi:
  - faqat `support` va `superadmin` ko'ra oladi
  - ticket ustiga bosilganda full chat dialog ochiladi
  - support javobi paneldan yuborilganda Telegram userga ketadi
  - user botdan `/close` yoki `Ticketni yopish` tugmasi bilan yopadi
  - support statusni paneldan o'zgartira olmaydi
  - support javobidan keyin 24 soat user javob bermasa auto-close
- Mobile profil tablarida (`driver` va `passenger`) eng pastiga `Bog'lanish` action tile qo'shildi:
  - `Telegram: @SafarUzSupportBot`
  - Bu tugma profil detail sahifasida emas, aynan pastki `Profil` tab ichida.
- Legal sahifalardagi support aloqa ham `@SafarUzSupportBot`ga almashtirilgan.
- FCM push uchun dependency fix:
  - `backend/requirements.txt`ga `requests==2.32.3` qo'shildi
  - `backend/app/services/push.py` import xatosi logi aniqroq qilindi (`google-auth + requests`)
- Push bildirishnomalarda Android ovozli/high-priority kelishi uchun:
  - Notification channel `safaruz_alerts_v2` yaratildi (`Importance.max`, sound/vibration yoqilgan)
  - `AndroidManifest.xml`ga `com.google.firebase.messaging.default_notification_channel_id=safaruz_alerts_v2` qo'shildi
  - Backend FCM payloadga `channel_id/android_channel_id` qo'shildi
- FCM loglari aniqroq qilindi:
  - `backend/app/services/push.py` endi v1 HTTP xatodan `fcm_code` (`UNREGISTERED`, `SENDER_ID_MISMATCH`, va h.k.) ni chiqaradi
  - "no valid provider" chalg'ituvchi logi o'rniga:
    - `no provider configured` (haqiqatan konfiguratsiya yo'q bo'lsa)
    - `configured providers failed (...)` (provider bor-u yuborish yiqilsa)
- Yo'lovchi group composition logikasi tuzatildi:
  - `passenger_requests` jadvaliga `male_seats` va `female_seats` qo'shildi
  - yangi migration: `backend/alembic/versions/0015_request_seat_mix.py`
  - eski requestlar migration paytida user account jinsiga qarab backfill qilinadi
  - `trip_gender_stats()` endi `seats_needed`ni account jinsiga ko'paytirib yubormaydi, explicit compositionni ishlatadi
  - driver request listi, trip passenger detaili va passenger request status sahifalarida composition ko'rinadi
- `Create Request` va `Create Trip` mobile sahifalari qayta dizayn qilindi:
  - katta hero panel
  - aniqroq vaqt/location bloklari
  - request sahifasida seat composition counterlar
  - trip sahifasida seat/price/time sectionlari chiroyliroq qayta ishlangan
- `admin_credentials` modeli kengaydi:
  - `role`, `is_active`, `created_by` fieldlar qo'shildi
- Yangi migration:
  - `backend/alembic/versions/0011_admin_roles_and_status.py`
  - `backend/alembic/versions/0012_admin_audit_logs.py`
  - `backend/alembic/versions/0013_support_tickets_and_telegram_sessions.py` (`revision` ID: `0013_support_tickets`, sababi `alembic_version` maydoni `varchar(32)`)
  - `backend/alembic/versions/0014_ticket_messages.py`
  - `backend/alembic/versions/0015_request_seat_mix.py`
- Eslatma: productionda albatta:
  - `cd /opt/safaruz/backend`
  - `source .venv/bin/activate`
  - `python -m alembic upgrade head`

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
- `20e3d7e` Improve FCM failure logging and provider failure messages
- `bcbcfaa` Enable audible Android push notifications with high-priority channel
- `f1df2f7` Add support bot action to bottom of profile tabs
- `cc06325` Point legal support contacts to SafarUz Telegram bot
- `d4b3fe7` Implement threaded support tickets with bot close and auto-close
- `61175ba` Fix Alembic revision id length for 0013 migration

Ishchi daraxt holati:
- Handoff yozilgan paytda `git status` toza (commit qilinmagan WIP yo'q).

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
- `support`

Health:
- `GET /health` => quick (`status`, `timestamp`)
- `GET /health?deep=true` => `db/sms/fcm/telegram_support` checks + degradeda `503`

CORS:
- Env orqali boshqariladi: `CORS_ALLOWED_ORIGINS`.

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
- Telegram support:
  - `TELEGRAM_SUPPORT_BOT_TOKEN`, `TELEGRAM_SUPPORT_CHAT_ID`
  - `TELEGRAM_SUPPORT_WEBHOOK_SECRET`
  - `TELEGRAM_SUPPORT_DELETE_SENSITIVE_MESSAGES` (login paytida telefon/parol xabarlarini auto-delete)

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

### 4.11 Support (Telegram bot + ticketlar)
Fayllar:
- `backend/app/api/support.py`
- `backend/app/models/support_ticket.py`
- `backend/app/models/support_ticket_message.py`
- `backend/app/models/telegram_support_session.py`
- `backend/app/services/support_tickets.py`
- `backend/app/services/telegram_support.py`

Endpointlar:
- `GET /support/link` -> bot link qaytaradi
- `POST /support/contact` -> appdan yuborilgan support (auth required)
- `POST /support/telegram/webhook` -> Telegram botdan kelgan xabarlar

Telegram bot login oqimi:
1) `/start`
2) telefon raqam kiritiadi
3) parol kiritiladi
4) tasdiqlangandan keyin yozilgan har bir xabar ticketga qo'shiladi

Support ticket real oqimi:
- Bitta user uchun aktiv (`open`/`in_progress`) ticketga xabar append qilinadi.
- Ticketdagi barcha yozishmalar `support_ticket_messages`da saqlanadi (chat history).
- Bot media xabarlarni ham qabul qiladi: `photo/video/voice/audio/document`.
- Login bosqichida telefon/parol xabarlari botdan auto-delete qilinadi (privacy).
- User botdan `/close` yoki `Ticketni yopish` yuborsa ticket yopiladi.
- Support javobidan keyin user 24 soat ichida yozmasa ticket avtomatik yopiladi.
- User keyin qayta yozsa yangi/ochiq ticket oqimi qayta boshlanadi.

### 4.12 Legal sahifalar
Fayllar:
- `backend/app/api/legal.py`
- `backend/app/templates/legal/privacy.html`
- `backend/app/templates/legal/terms.html`

URL:
- `/legal/privacy`
- `/legal/terms`

### 4.13 Admin panel
Fayl: `backend/app/api/admin.py`
Template: `backend/app/templates/admin/dashboard.html`

Endpointlar:
- `/admin/login` (GET/POST)
- `/admin/logout`
- `/admin` dashboard
- `/admin/driver-access` (block/unblock)
- `/admin/change-password` (POST)
- `/admin/support-tickets/reply` (POST)
- `/admin/broadcasts/send` (POST, superadmin only)

Qila oladi:
- Statistika ko'rish
- Recent user/request
- Trips by date
- User lookup by ID (kengaytirilgan: profil fieldlari + claim/chat/notification/rating statistikalar)
- Driver block/unblock
- Resource metrics (host/container)
- Server xatoliklari tab (`journalctl`) orqali service loglaridan `ERROR/Exception/Traceback/...` satrlarini ko'rsatish
- Admin parolini paneldan o'zgartirish (DB hash + env fallback)
- Support ticketlarni chat ko'rinishida ochib ko'rish (`support`/`superadmin`)
- Support javob yuborish (`support`/`superadmin`)
- Saved reply template tanlab tez javob yuborish (`support`/`superadmin`)
- Ticket statusini qo'lda o'zgartirish admin panelda o'chirilgan
- Support SLA metrikalarini ko'rish (`waiting_support`, `escalated`, `breached`, auto-close countdown)
- Media yuborilganini matn ko'rinishida ko'rish (photo/video/voice...)
- Audit logni filterlash va CSV export qilish (`admin_accounts` tabi)
- Overview intelligence panel:
  - time window KPI (`24h/7d/30d/90d`)
  - alertlar + activity feed + admin action breakdown
- Global Search + User 360 panel:
  - cross-entity qidiruv (`user/ticket/trip/request/claim/audit`)
  - prefix qidiruv (`user:`, `ticket:`, `trip:`, `request:`, `claim:`, `audit:`)
  - topilgan user uchun 360 summary + unified timeline
- Broadcast notifications panel (`superadmin` only):
  - audience bo'yicha bulk notification yuborish (`all`, `drivers`, `passengers`)
  - app notification + FCM push birga ishlaydi
  - oxirgi broadcastlar audit history ko'rinishida chiqadi

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
- `0011_admin_roles_and_status.py`
- `0012_admin_audit_logs.py`
- `0013_support_tickets_and_telegram_sessions.py` (revision id: `0013_support_tickets`)
- `0014_ticket_messages.py`
- `0015_request_seat_mix.py`
- `0016_admin_audit_log_metadata.py`

Asosiy jadvallar:
- `users`
- `admin_credentials`
- `admin_audit_logs`
- `otp_codes`
- `driver_trips`
- `passenger_requests`
- `request_claims`
- `chats`
- `chat_messages`
- `trip_ratings`
- `user_notifications`
- `support_tickets`
- `support_ticket_messages`
- `telegram_support_sessions`

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

### 6.7 Support entry points (mobile)
Fayllar:
- `mobile/lib/features/driver/driver_home_page.dart`
- `mobile/lib/features/passenger/passenger_home_page.dart`
- `mobile/lib/features/driver/driver_blocked_page.dart`

Hozirgi holat:
- Driver blocked ekranidagi `Bog'lanish` tugmasi `https://t.me/SafarUzSupportBot`ga ochadi.
- Driver va Passenger pastki `Profil` tabining eng pastida ham `Bog'lanish` tile bor.
- Legal sahifalardagi support kontakt ham botga yo'naltirilgan.

### 6.8 I18n
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

### 9.3 Telegram support bot
Kerakli envlar:
- `TELEGRAM_SUPPORT_BOT_TOKEN`
- `TELEGRAM_SUPPORT_CHAT_ID`
- `TELEGRAM_SUPPORT_WEBHOOK_SECRET`
- `TELEGRAM_SUPPORT_DELETE_SENSITIVE_MESSAGES=true`

Mobile:
- `mobile/android/app/google-services.json` mavjud bo'lishi kerak.

Backendda service account json gitga qo'shilmaydi (`backend/.gitignore`da bor).

---

## 10) Security va konfiguratsiya risklari (MUHIM)

1. `backend/.env.example` ichida real tokenlar bor (`DEVSMS_TOKEN`, `TELEGRAM_SUPPORT_BOT_TOKEN`, `TELEGRAM_SUPPORT_CHAT_ID`).
   - Owner talabi bo'yicha ular saqlanmoqda; ammo public repo uchun xavf yuqori.
   - Tavsiya: tokenlarni davriy rotate qilish va productionda kamida env vault/secret manager ishlatish.

2. DuckDNS token chatda oshkor qilingan.
   - DuckDNS paneldan tokenni regenerate qilib scriptlarni yangilash kerak.

3. `ADMIN_PASSWORD` default (`admin123`) bo'lib ketishi mumkin.
   - productionda albatta almashtirish kerak.

4. CORS env orqali boshqariladi.
   - `CORS_ALLOWED_ORIGINS` faqat kerakli domainlar bilan cheklanganini tekshirish kerak.

5. Legacy `/auth/verify-otp` endpoint hali ochiq.
   - yangi password flowga to'liq o'tilgach deprecate qilish kerak.

6. Legal/README drift:
   - README hozir kod bilan to'liq mos emas (eski OTP flow yozilgan).

---

## 11) Hozirgi ochiq kamchiliklar (tech debt)

## 10.4) 2026-03-07 UI redesign wave

- Main mobile UI bir xil "neo" vizual tilga o'tkazildi:
  - yangi shared komponentlar: `mobile/lib/core/widgets/neo_sections.dart`
  - qo'shilgan bloklar: `NeoHeroCard`, `NeoBadge`, `NeoActionCard`, `NeoSectionHeader`, `NeoMetricCard`, `NeoInfoRow`, `NeoEmptyState`
- Quyidagi sahifalar sezilarli qayta dizayn qilindi:
  - `mobile/lib/features/passenger/passenger_home_page.dart`
  - `mobile/lib/features/driver/my_trips_page.dart`
  - `mobile/lib/features/chat/chats_page.dart`
  - `mobile/lib/features/chat/chat_page.dart`
  - `mobile/lib/features/notifications/notifications_page.dart`
  - `mobile/lib/features/settings/profile_page.dart`
  - `mobile/lib/features/settings/settings_page.dart`
  - `mobile/lib/features/settings/profile_setup_page.dart`
  - `mobile/lib/features/role/role_page.dart`
- `mobile/lib/features/driver/driver_home_page.dart` allaqachon neo style'ga yaqinlashtirilgan edi; qolgan passenger/settings/chat/trips screens ham shu uslubga keltirildi.
- Dizayn yo'nalishi:
  - kattaroq hero headerlar
  - rangli action cardlar
  - bo'sh holatlar uchun alohida empty-state bloklar
  - profil va trip detail joylarda metric/info row pattern
  - chat composer va message bubblelar tozalandi
- Verify:
  - `flutter analyze` redesign qilingan fayllarda toza o'tgan
  - `dart format` ishlatilgan
- 2026-03-07 qo'shimcha fix:
  - redesign paytida qolib ketgan hardcoded English/Uzbek matnlarning asosiy qismi `mobile/lib/core/i18n/strings.dart` kalitlariga ko'chirildi
  - `mobile/lib/features/driver/create_trip_page.dart` ichida vaqt labeli `Jo'nash/Tugash` chalkashligidan `Boshlanish/Tugash` ko'rinishiga to'g'rilandi (`start_time_label`, `end_time_label`)
  - `mobile/lib/features/driver/my_received_ratings_page.dart` ham lokalizatsiyaga yaqinlashtirildi
  - `mobile/lib/features/settings/profile_page.dart` ichida haydovchi rating count joylashuvi qayta tartiblandi
  - `mobile/lib/features/chat/chat_page.dart` ichidagi katta hero blok olib tashlandi
  - chat sahifasi birinchi ochilganda endi oxirgi xabarga avtomatik tushadi
- Eslatma:
  - `backend/.env.example` ichidagi mavjud tokenlarni owner talabi bo'yicha o'chirmaslik kerak
  - agar keyingi redesign davom etsa, auth page'lar (`auth_page.dart`, `password_login_page.dart`, `otp_page.dart`, `set_password_page.dart`) ham shu neo vizual tizimga ko'chirilishi mumkin
- 2026-03-08 admin panel wave:
  - admin dashboard/login dizayni to'liq yangilandi
  - audit log metadata + state diff qo'shildi
  - support ticket SLA paneli qo'shildi

- RU i18n matnlari encoding buzilgan.
- UIda ba'zi joylarda eski/yarim tayyor auth flow textlari qolgan bo'lishi mumkin.
- Notification delivery 2 qavatli (polling + push), duplicate risk ayrim edge-caselar bo'lishi mumkin.
- Rootda ikki xil Flutter struktura bor (confusion risk).
- Testlar deyarli yo'q (manual regressionga tayanilgan).
- Admin `Server xatoliklari` tab Linux systemd/journalctl ga bog'liq; Windows local devda ishlamasligi normal.

---

## 12) Next ChatGPT uchun aniq davom rejasi

1. `git status`ni tekshirib, yangi o'zgarishlarni mayda commitlarga bo'lib yuritish.
2. `README.md`ni hozirgi auth/password flowga moslab to'liq yangilash.
3. Owner talabi: `.env.example` tokenlarini o'chirmaslik.
   - Buning o'rniga token rotation/checklist va private deployment secret strategy qo'shish.
4. `strings.dart`dagi RU encodingni tozalash.
5. Auth legacy endpoint (`/verify-otp`) ni bosqichma-bosqich o'chirish rejasini qilish.
6. CORS, admin creds, secrets bo'yicha production hardening.
7. `alembic upgrade head` bilan oxirgi migrationlarni (`0016_admin_audit_log_metadata`gacha) productionga qo'llash.
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
- Support bot: @SafarUzSupportBot (legal + profile tab + blocked driver entry points)
- Support ticketlar: threaded chat + admin reply + user /close + 24h auto-close

Birinchi ish:
1) `git status` va handoffdagi open issuesni tekshir
2) README va deployment doclarni hozirgi flowga moslab yangila
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
