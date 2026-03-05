import json
import logging
from urllib import error, request

from app.core.settings import settings

logger = logging.getLogger(__name__)


class DevSmsError(RuntimeError):
    pass


def _build_url(path: str) -> str:
    base = settings.devsms_base_url.rstrip("/")
    if path.startswith("/"):
        return f"{base}{path}"
    return f"{base}/{path}"


def _decode_json(data: bytes) -> dict:
    try:
        return json.loads(data.decode("utf-8"))
    except Exception as exc:  # pragma: no cover
        raise DevSmsError("DevSMS javobi JSON formatida emas") from exc


def send_sms(*, phone: str, message: str) -> dict:
    token = settings.devsms_token.strip()
    if not token:
        raise DevSmsError("DevSMS token kiritilmagan")

    payload = {
        "phone": phone.lstrip("+"),
        "message": message,
        "from": settings.devsms_from.strip() or "4546",
    }

    req = request.Request(
        _build_url("/send_sms.php"),
        method="POST",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )

    try:
        with request.urlopen(req, timeout=settings.devsms_timeout_seconds) as resp:
            body = resp.read()
            data = _decode_json(body)
    except error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        logger.warning("DevSMS HTTP error: %s body=%s", exc.code, body)
        raise DevSmsError(f"DevSMS SMS yuborishda xatolik: {body}") from exc
    except Exception as exc:
        raise DevSmsError("DevSMS ulanish xatoligi") from exc

    if not isinstance(data, dict):
        raise DevSmsError("DevSMS javobi noto'g'ri formatda")

    if data.get("success") is not True:
        message_text = str(data.get("message") or "DevSMS yuborishni rad etdi")
        raise DevSmsError(message_text)

    return data

