from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class MonetizationSetting(Base):
    __tablename__ = "monetization_settings"

    id: Mapped[int] = mapped_column(primary_key=True, default=1)
    driver_paid_mode_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    driver_monthly_price: Mapped[int] = mapped_column(Integer, default=0)
    click_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    payme_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    updated_by: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
