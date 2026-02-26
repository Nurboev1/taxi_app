from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field

from app.models.enums import ClaimStatus, RequestStatus


class PassengerRequestCreateIn(BaseModel):
    from_location: str
    to_location: str
    start_time: datetime
    end_time: datetime
    seats_needed: int = Field(ge=1, le=4)


class PassengerRequestOut(BaseModel):
    id: int
    passenger_id: int
    from_location: str
    to_location: str
    start_time: datetime
    end_time: datetime
    seats_needed: int
    status: RequestStatus
    chosen_claim_id: int | None = None
    chosen_driver_id: int | None = None

    class Config:
        from_attributes = True


class ClaimCreateIn(BaseModel):
    trip_id: int


class ChooseDriverIn(BaseModel):
    claim_id: int


class ClaimOut(BaseModel):
    id: int
    request_id: int
    driver_id: int
    driver_name: str
    trip_id: int
    from_location: str
    to_location: str
    start_time: datetime
    end_time: datetime
    seats_total: int
    seats_taken: int
    price_per_seat: Decimal
    status: ClaimStatus


class MatchTripOut(BaseModel):
    id: int
    driver_id: int
    driver_name: str
    from_location: str
    to_location: str
    start_time: datetime
    end_time: datetime
    seats_total: int
    seats_taken: int
    price_per_seat: Decimal


class ChooseDriverOut(BaseModel):
    request_id: int
    chosen_claim_id: int
    driver_id: int
    driver_name: str
    driver_phone: str
    chat_id: int
    status: RequestStatus
