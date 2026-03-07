from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class TelegramSupportSession(Base):
    __tablename__ = "telegram_support_sessions"

    id: Mapped[int] = mapped_column(primary_key=True)
    chat_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    state: Mapped[str] = mapped_column(String(24), default="await_phone", index=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    phone_candidate: Mapped[str | None] = mapped_column(String(32), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), index=True
    )
