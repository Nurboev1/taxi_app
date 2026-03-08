from datetime import datetime, timezone
import html
import re

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.api.auth import _client_ip, _enforce_rate_limit
from app.api.deps import get_current_user
from app.core.security import verify_password
from app.core.settings import settings
from app.db.session import get_db
from app.models.claim import RequestClaim
from app.models.request import PassengerRequest
from app.models.support_ticket import SupportTicket
from app.models.trip import DriverTrip
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
    delete_bot_message,
    forward_bot_message,
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


def _best_effort_delete_message(chat_id: str, message_id: int | None) -> None:
    if message_id is None or not settings.telegram_support_delete_sensitive_messages:
        return
    try:
        delete_bot_message(chat_id=chat_id, message_id=message_id)
    except TelegramSupportError:
        pass


def _extract_media_payload(message_obj: dict) -> dict[str, object] | None:
    photos = message_obj.get("photo")
    if isinstance(photos, list) and photos:
        item = photos[-1] if isinstance(photos[-1], dict) else {}
        return {
            "kind": "photo",
            "file_id": str(item.get("file_id") or "").strip() or None,
            "file_unique_id": str(item.get("file_unique_id") or "").strip() or None,
            "mime_type": None,
            "file_size": item.get("file_size") if isinstance(item.get("file_size"), int) else None,
        }

    for key in ("video", "voice", "audio", "document"):
        item = message_obj.get(key)
        if isinstance(item, dict):
            return {
                "kind": key,
                "file_id": str(item.get("file_id") or "").strip() or None,
                "file_unique_id": str(item.get("file_unique_id") or "").strip() or None,
                "mime_type": str(item.get("mime_type") or "").strip() or None,
                "file_size": item.get("file_size") if isinstance(item.get("file_size"), int) else None,
            }
    return None


def _extract_user_context(db: Session, user_id: int) -> dict[str, object]:
    latest_request = db.scalar(
        select(PassengerRequest)
        .where(PassengerRequest.passenger_id == user_id)
        .order_by(PassengerRequest.created_at.desc())
        .limit(1)
    )
    latest_trip = db.scalar(
        select(DriverTrip)
        .where(DriverTrip.driver_id == user_id)
        .order_by(DriverTrip.created_at.desc())
        .limit(1)
    )
    latest_claim_driver = db.scalar(
        select(RequestClaim)
        .where(RequestClaim.driver_id == user_id)
        .order_by(RequestClaim.created_at.desc())
        .limit(1)
    )
    latest_claim_passenger = db.scalar(
        select(RequestClaim)
        .join(PassengerRequest, PassengerRequest.id == RequestClaim.request_id)
        .where(PassengerRequest.passenger_id == user_id)
        .order_by(RequestClaim.created_at.desc())
        .limit(1)
    )
    latest_claim = latest_claim_driver
    if latest_claim_passenger and (
        latest_claim is None or latest_claim_passenger.created_at > latest_claim.created_at
    ):
        latest_claim = latest_claim_passenger

    summary_parts: list[str] = []
    if latest_trip:
        summary_parts.append(f"trip#{latest_trip.id}")
    if latest_request:
        summary_parts.append(f"request#{latest_request.id}")
    if latest_claim:
        summary_parts.append(f"claim#{latest_claim.id}")
    return {
        "trip_id": latest_trip.id if latest_trip else None,
        "request_id": latest_request.id if latest_request else None,
        "claim_id": latest_claim.id if latest_claim else None,
        "summary": ", ".join(summary_parts),
    }


def _attach_ticket_context(db: Session, ticket: SupportTicket, user_id: int) -> dict[str, object]:
    context = _extract_user_context(db, user_id)
    ticket.context_trip_id = context["trip_id"] if isinstance(context["trip_id"], int) else None
    ticket.context_request_id = context["request_id"] if isinstance(context["request_id"], int) else None
    ticket.context_claim_id = context["claim_id"] if isinstance(context["claim_id"], int) else None
    ticket.context_summary = str(context.get("summary") or "").strip() or None
    ticket.context_refreshed_at = datetime.now(timezone.utc)
    db.add(ticket)
    return context


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

    _attach_ticket_context(db, ticket, current_user.id)
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

    message_id_raw = message_obj.get("message_id")
    message_id = int(message_id_raw) if isinstance(message_id_raw, int) else None
    text = str(message_obj.get("text") or "").strip()
    media_payload = _extract_media_payload(message_obj)
    media_caption = str(message_obj.get("caption") or "").strip()
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

    if session.state == _STATE_AWAIT_PHONE:
        phone_input = text
        if not phone_input:
            contact = message_obj.get("contact")
            if isinstance(contact, dict):
                phone_input = str(contact.get("phone_number") or "").strip()
        if not phone_input:
            _reply(chat_id, "Telefon raqamni matn yoki contact ko'rinishida yuboring.")
            return {"ok": True}
        try:
            session.phone_candidate = _normalize_phone(phone_input)
        except ValueError:
            _reply(chat_id, "Telefon raqam formati noto'g'ri. Masalan: +998901234567")
            return {"ok": True}

        _best_effort_delete_message(chat_id, message_id)
        session.state = _STATE_AWAIT_PASSWORD
        session.updated_at = datetime.now(timezone.utc)
        db.add(session)
        db.commit()
        _reply(chat_id, "Endi parolingizni kiriting. Xabar avtomatik o'chiriladi.")
        return {"ok": True}

    if session.state == _STATE_AWAIT_PASSWORD:
        if not text:
            _reply(chat_id, "Parolni matn ko'rinishida yuboring.")
            return {"ok": True}
        _best_effort_delete_message(chat_id, message_id)
        if not session.phone_candidate:
            session.state = _STATE_AWAIT_PHONE
            session.updated_at = datetime.now(timezone.utc)
            db.add(session)
            db.commit()
            _reply(chat_id, "Avval telefon raqam yuboring.")
            return {"ok": True}

        user = db.scalar(select(User).where(User.phone == session.phone_candidate))
        if not user or not user.password_hash or not verify_password(text, user.password_hash):
            _reply(chat_id, "Telefon yoki parol noto'g'ri. Xavfsizlik uchun xabar o'chirildi, qayta urinib ko'ring.")
            return {"ok": True}

        session.user_id = user.id
        session.state = _STATE_READY
        session.updated_at = datetime.now(timezone.utc)
        db.add(session)
        db.commit()
        _reply(
            chat_id,
            "Tasdiqlandi. Endi support xabaringizni yozing.\n"
            "Rasm/video/voice ham yuborishingiz mumkin.\n"
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

    if not text and not media_payload:
        _reply(chat_id, "Matn yoki media (photo/video/voice/audio/document) yuboring.")
        return {"ok": True}

    incoming_kind = "text"
    incoming_text = text
    media_file_id = None
    media_file_unique_id = None
    media_mime_type = None
    media_file_size = None
    if media_payload:
        incoming_kind = str(media_payload.get("kind") or "text").strip().lower()
        incoming_text = media_caption
        media_file_id = str(media_payload.get("file_id") or "").strip() or None
        media_file_unique_id = str(media_payload.get("file_unique_id") or "").strip() or None
        media_mime_type = str(media_payload.get("mime_type") or "").strip() or None
        media_file_size = media_payload.get("file_size") if isinstance(media_payload.get("file_size"), int) else None

    preview_text = incoming_text or f"[{incoming_kind} evidence]"
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
            message=preview_text,
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
        ticket.message = preview_text

    context = _attach_ticket_context(db, ticket, user.id)
    initial_telegram_message_id = message_id if incoming_kind == "text" else None
    appended_message = append_ticket_message(
        db=db,
        ticket=ticket,
        sender_role=SENDER_USER,
        message=preview_text,
        message_kind=incoming_kind,
        telegram_message_id=initial_telegram_message_id,
        media_file_id=media_file_id,
        media_file_unique_id=media_file_unique_id,
        media_mime_type=media_mime_type,
        media_file_size=media_file_size,
        media_caption=media_caption if incoming_kind != "text" else None,
    )

    session.updated_at = datetime.now(timezone.utc)
    db.add(session)
    db.commit()

    notify_lines: list[str] = []
    if incoming_kind != "text":
        notify_lines.append(f"[media:{incoming_kind}]")
    notify_lines.append(preview_text)
    context_summary = str(context.get("summary") or "").strip()
    if context_summary:
        notify_lines.append(f"Context: {context_summary}")
    _notify_support_channel(ticket=ticket, user=user, text="\n".join(notify_lines), is_new=is_new)
    if incoming_kind != "text" and message_id is not None:
        support_chat_id = settings.telegram_support_chat_id.strip()
        if support_chat_id:
            try:
                forwarded = forward_bot_message(
                    to_chat_id=support_chat_id,
                    from_chat_id=chat_id,
                    message_id=message_id,
                )
                result = forwarded.get("result") if isinstance(forwarded, dict) else None
                forwarded_message_id = (
                    int(result.get("message_id"))
                    if isinstance(result, dict) and isinstance(result.get("message_id"), int)
                    else None
                )
                if forwarded_message_id is not None:
                    appended_message.telegram_message_id = forwarded_message_id
                    db.add(appended_message)
                    try:
                        db.commit()
                    except SQLAlchemyError:
                        db.rollback()
            except TelegramSupportError:
                pass
    _reply(
        chat_id,
        f"Xabaringiz ticket #{ticket.id} ga qo'shildi. Tez orada javob beramiz.",
        with_close_button=True,
    )
    return {"ok": True}
