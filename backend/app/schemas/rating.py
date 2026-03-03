from datetime import datetime

from pydantic import BaseModel, Field


class PendingRatingOut(BaseModel):
    trip_id: int
    driver_id: int
    driver_name: str
    from_location: str
    to_location: str
    finished_at: datetime


class CreateRatingIn(BaseModel):
    stars: int = Field(ge=1, le=5)
    comment: str | None = Field(default=None, max_length=500)


class TripRatingOut(BaseModel):
    id: int
    trip_id: int
    passenger_id: int
    driver_id: int
    stars: int
    comment: str | None
    created_at: datetime

    class Config:
        from_attributes = True


class GivenRatingOut(BaseModel):
    rating_id: int
    trip_id: int
    target_name: str
    stars: int
    comment: str | None
    created_at: datetime


class ReceivedRatingOut(BaseModel):
    rating_id: int
    trip_id: int
    from_name: str
    stars: int
    comment: str | None
    created_at: datetime


class RatingSummaryOut(BaseModel):
    average: float
    total: int
    five: int
    four: int
    three: int
    two: int
    one: int
