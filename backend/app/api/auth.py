from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.security import create_access_token
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.otp import OtpCode
from app.models.user import User
from app.schemas.auth import (
    MessageOut,
    ProfileUpdateIn,
    RequestOtpIn,
    UserOut,
    VerifyOtpIn,
    VerifyOtpOut,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/request-otp", response_model=MessageOut)
def request_otp(payload: RequestOtpIn, db: Session = Depends(get_db)):
    otp = OtpCode(phone=payload.phone, code="0000")
    db.add(otp)
    db.commit()
    return MessageOut(message="OTP yuborildi. Test rejimida kod: 0000", timestamp=datetime.now(timezone.utc))


@router.post("/verify-otp", response_model=VerifyOtpOut)
def verify_otp(payload: VerifyOtpIn, db: Session = Depends(get_db)):
    otp = db.scalar(
        select(OtpCode)
        .where(OtpCode.phone == payload.phone)
        .order_by(desc(OtpCode.created_at))
    )
    if not otp or payload.otp != "0000":
        raise HTTPException(status_code=400, detail="OTP noto'g'ri")

    user = db.scalar(select(User).where(User.phone == payload.phone))
    if not user:
        user = User(phone=payload.phone, role=UserRole.none, name="Foydalanuvchi")
        db.add(user)
        db.commit()
        db.refresh(user)

    token = create_access_token(str(user.id))
    return VerifyOtpOut(access_token=token, user=user, role=user.role)


@router.get("/profile/me", response_model=UserOut)
def my_profile(current_user: User = Depends(get_current_user)):
    return current_user


@router.put("/profile/me", response_model=UserOut)
def update_profile(
    payload: ProfileUpdateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(current_user, field, value)

    if current_user.first_name or current_user.last_name:
        full = f"{current_user.first_name or ''} {current_user.last_name or ''}".strip()
        if full:
            current_user.name = full

    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    return current_user
