from datetime import datetime, timezone
import html
import re

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.auth import _client_ip, _enforce_rate_limit
from app.api.deps import get_current_user
from app.core.security import verify_password
from app.core.settings import settings
from app.db.session import get_db
from app.models.support_ticket import SupportTicket
from app.models.telegram_support_session import TelegramSupportSession
from app.models.user import User
from app.schemas.support import SupportContactIn, SupportContactOut, SupportLinkOut
from app.services.support_tickets import (
    SENDER_USER,
    TICKET_STATUS_CLOSED,
    append_ticket_message,
    auto_close_stale_tickets,
    close_ticket,
)
from app.services.telegram_support import (
    TelegramSupportError,
    send_bot_reply,
    send_support_message,
    support_bot_link,
)

router = APIRouter(prefix="/support", tags=["support"])

_STATE_AWAIT_PHONE = "await_phone"
_STATE_AWAIT_PASSWORD = "await_password"
_STATE_READY = "ready"

_CLOSE_COMMANDS = {"/close", "/close_ticket", "ticketni yopish", "yopish"}


def _normalize_phone(phone: str) -> str:
    digits = re.sub(r"\D", "", phone or "")
    if digits.startswith("998") and len(digits) == 12:
        return f"+{digits}"
    if len(digits) == 9:
        return f"+998{digits}"
    raise ValueError("Telefon format noto'g'ri")


def _get_or_create_session(db: Session, chat_id: str) -> TelegramSupportSession:
    session = db.scalar(
        select(TelegramSupportSession).where(TelegramSupportSession.chat_id == chat_id)
    )
    if session:
        return session
    now = datetime.now(timezone.utc)
    session = TelegramSupportSession(
        chat_id=chat_id,
        state=_STATE_AWAIT_PHONE,
        created_at=now,
        updated_at=now,
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session


def _reply(chat_id: str, text: str, with_close_button: bool = False) -> None:
    try:
        reply_markup = None
        if with_close_button:
            reply_markup = {
                "keyboard": [[{"text": "Ticketni yopish"}]],
                "resize_keyboard": True,
            }
        send_bot_reply(chat_id=chat_id, text=text, reply_markup=reply_markup)
    except TelegramSupportError:
        pass


def _active_ticket_for_user(db: Session, user_id: int) -> SupportTicket | None:
    return db.scalar(
        select(SupportTicket)
        .where(
            SupportTicket.user_id == user_id,
            SupportTicket.status != TICKET_STATUS_CLOSED,
        )
        .order_by(SupportTicket.last_activity_at.desc())
        .limit(1)
    )


def _notify_support_channel(ticket: SupportTicket, user: User, text: str, is_new: bool) -> None:
    support_chat_id = settings.telegram_support_chat_id.strip()
    if not support_chat_id:
        return
    title = "Yangi ticket" if is_new else "Ticketga javob"
    body = (
        f"<b>SafarUz Support</b>\n"
        f"<b>{title}:</b> #{ticket.id}\n"
        f"<b>User ID:</b> {user.id}\n"
        f"<b>Name:</b> {html.escape(user.name or '-')}\n"
        f"<b>Phone:</b> {html.escape(user.phone)}\n"
        f"<b>Status:</b> {ticket.status}\n\n"
        f"{html.escape(text)}"
    )
    try:
        send_bot_reply(chat_id=support_chat_id, text=body, parse_mode="HTML")
    except TelegramSupportError:
        pass


@router.get("/link", response_model=SupportLinkOut)
def support_link():
    return SupportLinkOut(url=support_bot_link())


@router.post("/contact", response_model=SupportContactOut)
def contact_support(
    request: Request,
    payload: SupportContactIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    ip = _client_ip(request)
    _enforce_rate_limit(
        key=f"support:contact:ip:{ip}",
        limit=settings.auth_rate_support_contact_per_ip,
        window_seconds=settings.auth_rate_window_seconds,
    )

    auto_close_stale_tickets(db)

    subject = payload.subject.strip()
    message = payload.message.strip()
    if not message:
        raise HTTPException(status_code=400, detail="Xabar bo'sh bo'lmasligi kerak")

    now = datetime.now(timezone.utc)
    ticket = _active_ticket_for_user(db, current_user.id)
    if ticket is None:
        ticket = SupportTicket(
            source="app_api",
            user_id=current_user.id,
            phone=current_user.phone,
            telegram_chat_id=None,
            telegram_username=None,
            subject=subject or "App support",
            message=message,
            status="open",
            last_actor=SENDER_USER,
            created_at=now,
            updated_at=now,
            last_activity_at=now,
            closed_at=None,
        )
        db.add(ticket)
        db.flush()
    else:
        ticket.subject = subject or ticket.subject
        ticket.message = message

    append_ticket_message(db=db, ticket=ticket, sender_role=SENDER_USER, message=message)
    db.commit()

    try:
        send_support_message(
            user_id=current_user.id,
            phone=current_user.phone,
            name=current_user.name or "Unknown",
            role=current_user.role.value,
            subject=f"Ticket #{ticket.id} | {subject or 'App support'}",
            message=message,
        )
    except TelegramSupportError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    return SupportContactOut(
        message="Support xabari yuborildi",
        sent_at=datetime.now(timezone.utc),
    )


@router.post("/telegram/webhook")
def telegram_webhook(
    payload: dict,
    db: Session = Depends(get_db),
    x_telegram_bot_api_secret_token: str | None = Header(default=None),
):
    configured_secret = settings.telegram_support_webhook_secret.strip()
    if configured_secret and x_telegram_bot_api_secret_token != configured_secret:
        raise HTTPException(status_code=401, detail="Telegram secret token noto'g'ri")

    auto_close_stale_tickets(db)

    message_obj = payload.get("message") or payload.get("edited_message")
    if not isinstance(message_obj, dict):
        return {"ok": True}

    chat = message_obj.get("chat") or {}
    if chat.get("type") != "private":
        return {"ok": True}

    chat_id = str(chat.get("id") or "")
    if not chat_id:
        return {"ok": True}

    text = str(message_obj.get("text") or "").strip()
    session = _get_or_create_session(db, chat_id)

    if text in {"/start", "/help"}:
        session.state = _STATE_AWAIT_PHONE
        session.phone_candidate = None
        session.user_id = None
        session.updated_at = datetime.now(timezone.utc)
        db.add(session)
        db.commit()
        _reply(
            chat_id,
            "Assalomu alaykum! Supportga yozishdan oldin telefon raqamingizni kiriting.\n"
            "Masalan: +998901234567",
        )
        return {"ok": True}

    if text == "/logout":
        session.state = _STATE_AWAIT_PHONE
        session.phone_candidate = None
        session.user_id = None
        session.updated_at = datetime.now(timezone.utc)
        db.add(session)
        db.commit()
        _reply(chat_id, "Session tozalandi. Qayta kirish uchun telefon raqamingizni yuboring.")
        return {"ok": True}

    if not text:
        _reply(chat_id, "Faqat matn yuboring.")
        return {"ok": True}

    if session.state == _STATE_AWAIT_PHONE:
        try:
            session.phone_candidate = _normalize_phone(text)
        except ValueError:
            _reply(chat_id, "Telefon raqam formati noto'g'ri. Masalan: +998901234567")
            return {"ok": True}

        session.state = _STATE_AWAIT_PASSWORD
        session.updated_at = datetime.now(timezone.utc)
        db.add(session)
        db.commit()
        _reply(chat_id, "Endi parolingizni kiriting.")
        return {"ok": True}

    if session.state == _STATE_AWAIT_PASSWORD:
        if not session.phone_candidate:
            session.state = _STATE_AWAIT_PHONE
            session.updated_at = datetime.now(timezone.utc)
            db.add(session)
            db.commit()
            _reply(chat_id, "Avval telefon raqam yuboring.")
            return {"ok": True}

        user = db.scalar(select(User).where(User.phone == session.phone_candidate))
        if not user or not user.password_hash or not verify_password(text, user.password_hash):
            _reply(chat_id, "Telefon yoki parol noto'g'ri. Qayta urinib ko'ring.")
            return {"ok": True}

        session.user_id = user.id
        session.state = _STATE_READY
        session.updated_at = datetime.now(timezone.utc)
        db.add(session)
        db.commit()
        _reply(
            chat_id,
            "Tasdiqlandi. Endi support xabaringizni yozing.\n"
            "Muammo hal bo'lsa /close deb ticketni yopishingiz mumkin.",
            with_close_button=True,
        )
        return {"ok": True}

    if session.state != _STATE_READY or not session.user_id:
        session.state = _STATE_AWAIT_PHONE
        session.user_id = None
        session.phone_candidate = None
        session.updated_at = datetime.now(timezone.utc)
        db.add(session)
        db.commit()
        _reply(chat_id, "Session yangilandi. Telefon raqamingizni qayta yuboring.")
        return {"ok": True}

    user = db.scalar(select(User).where(User.id == session.user_id))
    if not user:
        session.state = _STATE_AWAIT_PHONE
        session.user_id = None
        session.phone_candidate = None
        session.updated_at = datetime.now(timezone.utc)
        db.add(session)
        db.commit()
        _reply(chat_id, "Foydalanuvchi topilmadi. Telefon raqamingizni qayta yuboring.")
        return {"ok": True}

    if text.lower() in _CLOSE_COMMANDS:
        ticket_to_close = _active_ticket_for_user(db, user.id)
        if not ticket_to_close:
            _reply(chat_id, "Yopiladigan ochiq ticket topilmadi.")
            return {"ok": True}
        close_ticket(db=db, ticket=ticket_to_close, reason="Foydalanuvchi ticketni botdan yopdi.")
        db.commit()
        _reply(chat_id, f"Ticket #{ticket_to_close.id} yopildi. Yangi savol bo'lsa, yozavering.")
        return {"ok": True}

    now = datetime.now(timezone.utc)
    ticket = _active_ticket_for_user(db, user.id)
    is_new = ticket is None
    if ticket is None:
        ticket = SupportTicket(
            source="telegram_bot",
            user_id=user.id,
            phone=user.phone,
            telegram_chat_id=chat_id,
            telegram_username=(message_obj.get("from") or {}).get("username"),
            subject="Telegram support",
            message=text,
            status="open",
            last_actor=SENDER_USER,
            created_at=now,
            updated_at=now,
            last_activity_at=now,
            closed_at=None,
        )
        db.add(ticket)
        db.flush()
    else:
        ticket.telegram_chat_id = chat_id
        ticket.telegram_username = (message_obj.get("from") or {}).get("username")
        ticket.message = text

    append_ticket_message(db=db, ticket=ticket, sender_role=SENDER_USER, message=text)

    session.updated_at = datetime.now(timezone.utc)
    db.add(session)
    db.commit()

    _notify_support_channel(ticket=ticket, user=user, text=text, is_new=is_new)
    _reply(
        chat_id,
        f"Xabaringiz ticket #{ticket.id} ga qo'shildi. Tez orada javob beramiz.",
        with_close_button=True,
    )
    return {"ok": True}
