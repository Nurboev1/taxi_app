import json
import logging
import time
from urllib import error, parse, request

from app.core.settings import settings

logger = logging.getLogger(__name__)

_token: str | None = None
_token_obtained_at = 0.0


class EskizSmsError(RuntimeError):
    pass


def _build_url(path: str) -> str:
    base = settings.eskiz_base_url.rstrip("/")
    return f"{base}{path}"


def _decode_json(data: bytes) -> dict:
    try:
        return json.loads(data.decode("utf-8"))
    except Exception as exc:  # pragma: no cover
        raise EskizSmsError("Eskiz javobi JSON formatida emas") from exc


def _extract_token(payload: dict) -> str | None:
    if isinstance(payload.get("data"), dict):
        token = payload["data"].get("token")
        if isinstance(token, str) and token.strip():
            return token.strip()
    token = payload.get("token")
    if isinstance(token, str) and token.strip():
        return token.strip()
    return None


def _auth_token(force: bool = False) -> str:
    global _token, _token_obtained_at

    # Eskiz token typically lives for 30 days; we refresh earlier.
    token_age_seconds = time.time() - _token_obtained_at
    if not force and _token and token_age_seconds < (29 * 24 * 60 * 60):
        return _token

    if not settings.eskiz_email.strip() or not settings.eskiz_password.strip():
        raise EskizSmsError("Eskiz email/parol kiritilmagan")

    form = parse.urlencode(
        {
            "email": settings.eskiz_email.strip(),
            "password": settings.eskiz_password,
        }
    ).encode("utf-8")
    req = request.Request(
        _build_url("/api/auth/login"),
        method="POST",
        data=form,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
        },
    )

    try:
        with request.urlopen(req, timeout=settings.eskiz_timeout_seconds) as resp:
            payload = _decode_json(resp.read())
    except error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        logger.warning("Eskiz auth HTTP error: %s body=%s", exc.code, body)
        raise EskizSmsError("Eskiz autentifikatsiya xatoligi") from exc
    except Exception as exc:
        raise EskizSmsError("Eskiz autentifikatsiya ulanish xatoligi") from exc

    token = _extract_token(payload)
    if not token:
        logger.warning("Eskiz auth token not found in payload: %s", payload)
        raise EskizSmsError("Eskiz token olinmadi")

    _token = token
    _token_obtained_at = time.time()
    return token


def _send_once(phone: str, message: str, token: str) -> dict:
    payload: dict[str, str] = {
        "mobile_phone": phone,
        "message": message,
        "from": settings.eskiz_from.strip(),
    }
    callback_url = settings.eskiz_callback_url.strip()
    if callback_url:
        payload["callback_url"] = callback_url

    form = parse.urlencode(payload).encode("utf-8")
    req = request.Request(
        _build_url("/api/message/sms/send"),
        method="POST",
        data=form,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
            "Authorization": f"Bearer {token}",
        },
    )

    with request.urlopen(req, timeout=settings.eskiz_timeout_seconds) as resp:
        return _decode_json(resp.read())


def send_sms(*, phone: str, message: str) -> dict:
    token = _auth_token(force=False)
    try:
        return _send_once(phone, message, token)
    except error.HTTPError as exc:
        if exc.code == 401:
            token = _auth_token(force=True)
            return _send_once(phone, message, token)
        body = exc.read().decode("utf-8", errors="ignore")
        logger.warning("Eskiz send HTTP error: %s body=%s", exc.code, body)
        raise EskizSmsError(f"Eskiz SMS yuborishda xatolik: {body}") from exc
    except Exception as exc:
        raise EskizSmsError("Eskiz SMS ulanish xatoligi") from exc
