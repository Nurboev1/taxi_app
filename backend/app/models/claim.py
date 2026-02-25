from datetime import datetime, timezone

from sqlalchemy import DateTime, Enum, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.enums import ClaimStatus


class RequestClaim(Base):
    __tablename__ = "request_claims"
    __table_args__ = (UniqueConstraint("request_id", "driver_id", name="uq_request_driver_claim"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    request_id: Mapped[int] = mapped_column(ForeignKey("passenger_requests.id"), index=True)
    driver_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    trip_id: Mapped[int] = mapped_column(ForeignKey("driver_trips.id"), index=True)
    status: Mapped[ClaimStatus] = mapped_column(Enum(ClaimStatus), default=ClaimStatus.pending, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    driver = relationship("User")
    trip = relationship("DriverTrip")
