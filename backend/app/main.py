import os
from datetime import datetime, timezone

from fastapi import FastAPI, Response
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.api.auth import router as auth_router
from app.api.admin import router as admin_router
from app.api.chat import router as chat_router
from app.api.driver import router as driver_router
from app.api.legal import router as legal_router
from app.api.notifications import router as notifications_router
from app.api.requests import router as request_router
from app.api.rating import router as rating_router
from app.api.role import router as role_router
from app.core.settings import settings
from app.db.session import SessionLocal

try:
    import sentry_sdk  # type: ignore
except Exception:  # pragma: no cover
    sentry_sdk = None


def _init_sentry() -> None:
    dsn = settings.sentry_dsn.strip()
    if not dsn or sentry_sdk is None:
        return
    sentry_sdk.init(
        dsn=dsn,
        environment=settings.sentry_environment.strip() or settings.env,
        traces_sample_rate=max(0.0, min(1.0, settings.sentry_traces_sample_rate)),
    )


def _check_db() -> tuple[bool, str]:
    db = SessionLocal()
    try:
        db.execute(text("SELECT 1"))
        return True, "ok"
    except Exception as exc:
        return False, f"db_error: {exc}"
    finally:
        db.close()


def _check_sms() -> tuple[bool, str]:
    provider = settings.sms_provider.strip().lower()
    if provider == "test":
        return True, "test_provider"
    if provider == "devsms":
        token_ok = bool(settings.devsms_token.strip())
        base_ok = bool(settings.devsms_base_url.strip())
        if token_ok and base_ok:
            return True, "configured"
        return False, "devsms_not_configured"
    return False, f"unknown_provider:{provider}"


def _check_fcm() -> tuple[bool, str]:
    if settings.fcm_service_account_file.strip():
        path = settings.fcm_service_account_file.strip()
        if os.path.exists(path):
            return True, "v1_configured"
        return False, "service_account_missing"
    if settings.fcm_server_key.strip():
        return True, "legacy_key_configured"
    return False, "not_configured"


def _is_strict_failure(component: str) -> bool:
    if component == "sms":
        return settings.healthcheck_fail_on_sms
    if component == "fcm":
        return settings.healthcheck_fail_on_fcm
    return True

app = FastAPI(title=settings.app_name)
_init_sentry()

cors_origins = settings.cors_origins()
allow_all_origins = "*" in cors_origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if allow_all_origins else cors_origins,
    allow_credentials=False if allow_all_origins else True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health(response: Response, deep: bool = settings.healthcheck_deep_default):
    now = datetime.now(timezone.utc).isoformat()
    if not deep:
        return {"status": "ok", "timestamp": now}

    db_ok, db_detail = _check_db()
    sms_ok, sms_detail = _check_sms()
    fcm_ok, fcm_detail = _check_fcm()
    checks = {
        "db": {"ok": db_ok, "detail": db_detail},
        "sms": {"ok": sms_ok, "detail": sms_detail},
        "fcm": {"ok": fcm_ok, "detail": fcm_detail},
    }
    strict_ok = all(
        check["ok"] if _is_strict_failure(name) else True
        for name, check in checks.items()
    )
    status = "ok" if strict_ok else "degraded"
    if not strict_ok:
        response.status_code = 503
    return {
        "status": status,
        "timestamp": now,
        "checks": checks,
    }


app.include_router(auth_router)
app.include_router(admin_router)
app.include_router(role_router)
app.include_router(driver_router)
app.include_router(request_router)
app.include_router(chat_router)
app.include_router(rating_router)
app.include_router(notifications_router)
app.include_router(legal_router)
