from datetime import datetime
from enum import Enum

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


class OtpReason(str, Enum):
    register = "register"
    reset_password = "reset_password"


class PhoneIn(BaseModel):
    phone: str


class PhoneStatusOut(BaseModel):
    phone: str
    exists: bool
    has_password: bool


class RequestOtpIn(BaseModel):
    phone: str
    reason: OtpReason = OtpReason.register


class VerifyOtpIn(BaseModel):
    phone: str
    otp: str
    reason: OtpReason = OtpReason.register


class OtpPasswordCompleteIn(BaseModel):
    phone: str
    otp: str
    password: str = Field(min_length=8, max_length=128)
    reason: OtpReason = OtpReason.register


class PasswordLoginIn(BaseModel):
    phone: str
    password: str = Field(min_length=8, max_length=128)


class VerifyOtpOut(BaseModel):
    access_token: str
    user: UserOut
    role: UserRole


class SetRoleIn(BaseModel):
    role: UserRole


class DriverCheckoutIn(BaseModel):
    provider: str
    months_count: int = Field(default=1, ge=1, le=12)


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
