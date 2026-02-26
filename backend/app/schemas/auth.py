from datetime import datetime

from pydantic import BaseModel

from app.models.enums import UserRole


class UserOut(BaseModel):
    id: int
    phone: str
    name: str
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


class MessageOut(BaseModel):
    message: str
    timestamp: datetime | None = None
