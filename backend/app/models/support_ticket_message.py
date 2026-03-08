from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class SupportTicketMessage(Base):
    __tablename__ = "support_ticket_messages"

    id: Mapped[int] = mapped_column(primary_key=True)
    ticket_id: Mapped[int] = mapped_column(ForeignKey("support_tickets.id"), index=True)
    sender_role: Mapped[str] = mapped_column(String(24), index=True)
    message_kind: Mapped[str] = mapped_column(String(24), default="text", index=True)
    telegram_message_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    message: Mapped[str] = mapped_column(Text)
    media_file_id: Mapped[str | None] = mapped_column(String(256), nullable=True)
    media_file_unique_id: Mapped[str | None] = mapped_column(String(256), nullable=True)
    media_mime_type: Mapped[str | None] = mapped_column(String(128), nullable=True)
    media_file_size: Mapped[int | None] = mapped_column(Integer, nullable=True)
    media_caption: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), index=True
    )
