from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.support_ticket import SupportTicket
from app.models.support_ticket_message import SupportTicketMessage

TICKET_STATUS_OPEN = "open"
TICKET_STATUS_IN_PROGRESS = "in_progress"
TICKET_STATUS_CLOSED = "closed"

SENDER_USER = "user"
SENDER_SUPPORT = "support"
SENDER_SYSTEM = "system"


def append_ticket_message(
    *,
    db: Session,
    ticket: SupportTicket,
    sender_role: str,
    message: str,
) -> SupportTicketMessage:
    now = datetime.now(timezone.utc)
    text = (message or "").strip()
    msg = SupportTicketMessage(
        ticket_id=ticket.id,
        sender_role=sender_role,
        message=text,
        created_at=now,
    )
    ticket.updated_at = now
    ticket.last_activity_at = now
    ticket.last_actor = sender_role
    if sender_role == SENDER_USER and ticket.status == TICKET_STATUS_CLOSED:
        ticket.status = TICKET_STATUS_OPEN
        ticket.closed_at = None
    db.add(msg)
    db.add(ticket)
    return msg


def close_ticket(
    *,
    db: Session,
    ticket: SupportTicket,
    reason: str | None = None,
) -> None:
    now = datetime.now(timezone.utc)
    ticket.status = TICKET_STATUS_CLOSED
    ticket.closed_at = now
    ticket.updated_at = now
    ticket.last_activity_at = now
    ticket.last_actor = SENDER_SYSTEM
    db.add(ticket)
    if reason:
        db.add(
            SupportTicketMessage(
                ticket_id=ticket.id,
                sender_role=SENDER_SYSTEM,
                message=reason.strip(),
                created_at=now,
            )
        )


def auto_close_stale_tickets(db: Session) -> int:
    threshold = datetime.now(timezone.utc) - timedelta(days=1)
    rows = db.scalars(
        select(SupportTicket).where(
            SupportTicket.status.in_([TICKET_STATUS_OPEN, TICKET_STATUS_IN_PROGRESS]),
            SupportTicket.last_actor == SENDER_SUPPORT,
            SupportTicket.last_activity_at < threshold,
        )
    ).all()
    for ticket in rows:
        close_ticket(
            db=db,
            ticket=ticket,
            reason="Ticket 24 soat javobsiz qolgani uchun avtomatik yopildi.",
        )
    return len(rows)
