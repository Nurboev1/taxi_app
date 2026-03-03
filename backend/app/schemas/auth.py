from datetime import datetime

from pydantic import BaseModel, Field

from app.models.enums import AppLanguage, Gender, UserRole


class UserOut(BaseModel):
    id: int
    phone: str
    name: str
    first_name: str | None = None
    last_name: str | None = None
    car_model: str | None = None
    car_number: str | None = None
    gender: Gender | None = None
    age: int | None = None
    language: AppLanguage
    phone_visible: bool
    driver_blocked: bool = False
    driver_access_override: bool = False
    driver_block_reason: str | None = None
    driver_unblocked_at: datetime | None = None
    role: UserRole

    class Config:
        from_attributes = True


class RequestOtpIn(BaseModel):
    phone: str


class VerifyOtpIn(BaseModel):
    phone: str
    otp: str


class VerifyOtpOut(BaseModel):
    access_token: str
    user: UserOut
    role: UserRole


class SetRoleIn(BaseModel):
    role: UserRole


class ProfileUpdateIn(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    car_model: str | None = None
    car_number: str | None = None
    gender: Gender | None = None
    age: int | None = Field(default=None, ge=16, le=90)
    language: AppLanguage | None = None
    phone_visible: bool | None = None


class MessageOut(BaseModel):
    message: str
    timestamp: datetime | None = None
