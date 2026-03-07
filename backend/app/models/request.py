from datetime import datetime, timezone

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.enums import RequestStatus


class PassengerRequest(Base):
    __tablename__ = "passenger_requests"

    id: Mapped[int] = mapped_column(primary_key=True)
    passenger_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    from_location: Mapped[str] = mapped_column(String(120), index=True)
    to_location: Mapped[str] = mapped_column(String(120), index=True)
    start_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    end_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    preferred_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True, nullable=True)
    seats_needed: Mapped[int] = mapped_column(Integer)
    male_seats: Mapped[int] = mapped_column(Integer, default=0)
    female_seats: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[RequestStatus] = mapped_column(Enum(RequestStatus), default=RequestStatus.open, index=True)
    chosen_claim_id: Mapped[int | None] = mapped_column(ForeignKey("request_claims.id"), nullable=True)
    chosen_driver_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    passenger = relationship("User", foreign_keys=[passenger_id])
