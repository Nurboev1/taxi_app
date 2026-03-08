from datetime import datetime, timezone

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.enums import TripStatus


class DriverTrip(Base):
    __tablename__ = "driver_trips"

    id: Mapped[int] = mapped_column(primary_key=True)
    driver_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    from_location: Mapped[str] = mapped_column(String(120), index=True)
    to_location: Mapped[str] = mapped_column(String(120), index=True)
    start_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    end_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    seats_total: Mapped[int] = mapped_column(Integer, default=4)
    seats_taken: Mapped[int] = mapped_column(Integer, default=0)
    price_per_seat: Mapped[float] = mapped_column(Numeric(12, 2))
    status: Mapped[TripStatus] = mapped_column(Enum(TripStatus), default=TripStatus.open, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    driver = relationship("User")
