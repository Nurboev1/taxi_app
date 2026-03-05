import hmac
import random
import re
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import delete, desc, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.security import create_access_token
from app.core.settings import settings
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
from app.services.eskiz_sms import EskizSmsError, send_sms

router = APIRouter(prefix="/auth", tags=["auth"])

_PHONE_ERROR = "Telefon raqam noto'g'ri. Masalan: +998901234567"
_ESKIZ_TEST_RESTRICT_TEXT = "Для теста можно использовать только один из этих текстов"


def _normalize_phone(phone: str) -> str:
    digits = re.sub(r"\D", "", phone or "")
    if digits.startswith("998") and len(digits) == 12:
        return f"+{digits}"
    if len(digits) == 9:
        return f"+998{digits}"
    raise HTTPException(status_code=400, detail=_PHONE_ERROR)


def _generate_otp_code() -> str:
    return f"{random.SystemRandom().randint(0, 999999):06d}"


@router.post("/request-otp", response_model=MessageOut)
def request_otp(payload: RequestOtpIn, db: Session = Depends(get_db)):
    phone = _normalize_phone(payload.phone)
    now = datetime.now(timezone.utc)
    latest = db.scalar(
        select(OtpCode)
        .where(OtpCode.phone == phone)
        .order_by(desc(OtpCode.created_at))
    )
    if latest:
        cooldown = (now - latest.created_at).total_seconds()
        if cooldown < settings.otp_cooldown_seconds:
            wait_seconds = max(1, int(settings.otp_cooldown_seconds - cooldown))
            raise HTTPException(
                status_code=429,
                detail=f"Kodni qayta yuborish uchun {wait_seconds} soniya kuting",
            )

    code = _generate_otp_code()
    expires_at = now + timedelta(minutes=settings.otp_ttl_minutes)

    provider = settings.sms_provider.strip().lower()
    if provider == "eskiz":
        if settings.eskiz_test_mode:
            code = "0000"
            message = "This is test from Eskiz"
        else:
            message = (
                f"SafarUz tasdiqlash kodi: {code}. "
                f"Kod {settings.otp_ttl_minutes} daqiqa amal qiladi."
            )
        try:
            send_sms(phone=phone, message=message)
        except EskizSmsError as exc:
            # Eskiz test account rejects custom text; fallback to allowed test text.
            if _ESKIZ_TEST_RESTRICT_TEXT in str(exc):
                code = "0000"
                try:
                    send_sms(phone=phone, message="This is test from Eskiz")
                except EskizSmsError as exc2:
                    raise HTTPException(status_code=502, detail=str(exc2)) from exc2
            else:
                raise HTTPException(status_code=502, detail=str(exc)) from exc
    elif provider != "test":
        raise HTTPException(status_code=500, detail="SMS provider noto'g'ri sozlangan")

    otp = OtpCode(phone=phone, code=code, expires_at=expires_at)
    db.add(otp)
    db.commit()

    message = "OTP yuborildi"
    if provider == "test" or code == "0000":
        message = f"OTP yuborildi. Test rejimida kod: {code}"
    return MessageOut(message=message, timestamp=now)


@router.post("/verify-otp", response_model=VerifyOtpOut)
def verify_otp(payload: VerifyOtpIn, db: Session = Depends(get_db)):
    phone = _normalize_phone(payload.phone)
    now = datetime.now(timezone.utc)
    otp = db.scalar(
        select(OtpCode)
        .where(OtpCode.phone == phone)
        .order_by(desc(OtpCode.created_at))
    )
    if not otp:
        raise HTTPException(status_code=400, detail="OTP topilmadi")

    if now > otp.expires_at:
        raise HTTPException(status_code=400, detail="OTP muddati tugagan")

    if not hmac.compare_digest((payload.otp or "").strip(), otp.code):
        raise HTTPException(status_code=400, detail="OTP noto'g'ri")

    user = db.scalar(select(User).where(User.phone == phone))
    if not user:
        user = User(phone=phone, role=UserRole.none, name="Foydalanuvchi")
        db.add(user)

    db.execute(delete(OtpCode).where(OtpCode.phone == phone))
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
