import html
import json
import logging
from urllib import error, parse, request

from app.core.settings import settings

logger = logging.getLogger(__name__)


class TelegramSupportError(RuntimeError):
    pass


def telegram_support_config_status() -> tuple[bool, str]:
    token = settings.telegram_support_bot_token.strip()
    chat_id = settings.telegram_support_chat_id.strip()
    if not token:
        return False, "bot_token_missing"
    if not chat_id:
        return False, "chat_id_missing"
    return True, "configured"


def support_bot_link() -> str:
    username = settings.telegram_support_bot_username.strip().lstrip("@")
    if not username:
        return "https://t.me/"
    return f"https://t.me/{username}"


def _build_message(
    *,
    user_id: int,
    phone: str,
    name: str,
    role: str,
    subject: str,
    message: str,
) -> str:
    safe_subject = html.escape(subject.strip() or "No subject")
    safe_message = html.escape(message.strip())
    safe_name = html.escape(name)
    safe_phone = html.escape(phone)
    safe_role = html.escape(role)
    return (
        "<b>SafarUz Support</b>\n"
        f"<b>User ID:</b> {user_id}\n"
        f"<b>Name:</b> {safe_name}\n"
        f"<b>Phone:</b> {safe_phone}\n"
        f"<b>Role:</b> {safe_role}\n"
        f"<b>Subject:</b> {safe_subject}\n\n"
        f"{safe_message}"
    )


def send_support_message(
    *,
    user_id: int,
    phone: str,
    name: str,
    role: str,
    subject: str,
    message: str,
) -> dict:
    token = settings.telegram_support_bot_token.strip()
    chat_id = settings.telegram_support_chat_id.strip()
    if not token or not chat_id:
        raise TelegramSupportError("Telegram support bot sozlanmagan")

    return _send_telegram_message(
        token=token,
        chat_id=chat_id,
        text=_build_message(
            user_id=user_id,
            phone=phone,
            name=name,
            role=role,
            subject=subject,
            message=message,
        ),
        parse_mode="HTML",
    )


def send_bot_reply(*, chat_id: str, text: str, parse_mode: str | None = None) -> dict:
    token = settings.telegram_support_bot_token.strip()
    if not token:
        raise TelegramSupportError("Telegram support bot token kiritilmagan")
    return _send_telegram_message(
        token=token,
        chat_id=chat_id,
        text=text,
        parse_mode=parse_mode,
    )


def _send_telegram_message(
    *,
    token: str,
    chat_id: str,
    text: str,
    parse_mode: str | None = None,
) -> dict:
    payload = {
        "chat_id": chat_id,
        "text": text,
        "disable_web_page_preview": True,
    }
    if parse_mode:
        payload["parse_mode"] = parse_mode
    data = parse.urlencode(payload).encode("utf-8")
    req = request.Request(
        f"https://api.telegram.org/bot{token}/sendMessage",
        method="POST",
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    try:
        with request.urlopen(req, timeout=settings.telegram_support_timeout_seconds) as resp:
            body = resp.read().decode("utf-8", errors="ignore")
    except error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        logger.error("Telegram support HTTP error: %s body=%s", exc.code, body)
        raise TelegramSupportError("Telegramga yuborishda HTTP xato") from exc
    except Exception as exc:
        logger.exception("Telegram support send error: %s", exc)
        raise TelegramSupportError("Telegramga ulanishda xato") from exc

    try:
        parsed = json.loads(body)
    except json.JSONDecodeError as exc:
        raise TelegramSupportError("Telegram javobi noto'g'ri formatda") from exc
    if not parsed.get("ok"):
        raise TelegramSupportError("Telegram xabarni qabul qilmadi")
    return parsed
