from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field, field_validator

from app.models.enums import TripStatus


class DriverTripCreateIn(BaseModel):
    from_location: str
    to_location: str
    start_time: datetime
    end_time: datetime
    seats_total: int = Field(default=4, ge=1, le=8)
    price_per_seat: Decimal = Field(gt=0)

    @field_validator("price_per_seat")
    @classmethod
    def validate_integer_price(cls, v: Decimal) -> Decimal:
        # Only whole-number prices are allowed (digits only).
        if v != v.to_integral_value():
            raise ValueError("price_per_seat faqat butun raqam bo'lishi kerak")
        return v


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
