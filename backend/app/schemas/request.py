from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field, model_validator

from app.models.enums import ClaimStatus, RequestStatus


class PassengerRequestCreateIn(BaseModel):
    from_location: str
    to_location: str
    preferred_time: datetime
    seats_needed: int = Field(ge=1, le=4)
    male_seats: int = Field(default=0, ge=0, le=4)
    female_seats: int = Field(default=0, ge=0, le=4)

    @model_validator(mode="after")
    def validate_seat_mix(self):
        if self.male_seats + self.female_seats != self.seats_needed:
            raise ValueError("male_seats + female_seats seats_needed ga teng bo'lishi kerak")
        return self


class PassengerRequestOut(BaseModel):
    id: int
    passenger_id: int
    passenger_gender: str | None = None
    from_location: str
    to_location: str
    start_time: datetime
    end_time: datetime
    preferred_time: datetime | None = None
    seats_needed: int
    male_seats: int = 0
    female_seats: int = 0
    status: RequestStatus
    chosen_claim_id: int | None = None
    chosen_driver_id: int | None = None
    match_level: str | None = None
    time_gap_minutes: int | None = None
    claim_state: str | None = None

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
    driver_gender: str | None = None
    driver_phone: str | None = None
    driver_car_model: str | None = None
    driver_car_number: str | None = None
    trip_id: int
    from_location: str
    to_location: str
    start_time: datetime
    end_time: datetime
    seats_total: int
    seats_taken: int
    trip_male_count: int = 0
    trip_female_count: int = 0
    driver_average_rating: float = 0
    driver_ratings_total: int = 0
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
    match_level: str
    time_gap_minutes: int


class ChooseDriverOut(BaseModel):
    request_id: int
    chosen_claim_id: int
    driver_id: int
    driver_name: str
    driver_phone: str | None = None
    chat_id: int
    status: RequestStatus


class TripPassengerOut(BaseModel):
    request_id: int
    passenger_id: int
    chat_id: int | None = None
    passenger_name: str
    passenger_first_name: str | None = None
    passenger_last_name: str | None = None
    passenger_gender: str | None = None
    passenger_phone: str | None = None
    passenger_trips_count: int = 0
    seats_needed: int
    male_seats: int = 0
    female_seats: int = 0
    from_location: str
    to_location: str
