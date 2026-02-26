from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field

from app.models.enums import TripStatus


class DriverTripCreateIn(BaseModel):
    from_location: str
    to_location: str
    start_time: datetime
    end_time: datetime
    seats_total: int = Field(default=4, ge=1, le=8)
    price_per_seat: Decimal = Field(gt=0)


class DriverTripOut(BaseModel):
    id: int
    driver_id: int
    from_location: str
    to_location: str
    start_time: datetime
    end_time: datetime
    seats_total: int
    seats_taken: int
    price_per_seat: Decimal
    status: TripStatus

    class Config:
        from_attributes = True
