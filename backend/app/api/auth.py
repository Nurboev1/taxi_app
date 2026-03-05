import hmac
import random
import re
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import delete, desc, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.security import create_access_token, hash_password, verify_password
from app.core.settings import settings
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.otp import OtpCode
from app.models.user import User
from app.schemas.auth import (
    MessageOut,
    OtpPasswordCompleteIn,
    OtpReason,
    PasswordLoginIn,
    PhoneIn,
    PhoneStatusOut,
    ProfileUpdateIn,
    RequestOtpIn,
    UserOut,
    VerifyOtpIn,
    VerifyOtpOut,
)
from app.services.devsms_sms import DevSmsError, send_sms

router = APIRouter(prefix="/auth", tags=["auth"])

_PHONE_ERROR = "Telefon raqam noto'g'ri. Masalan: +998901234567"
_TESTER_PHONE_ALIASES = {
    "+998": "+998000000000",
    "+9981": "+998100000000",
}
_TESTER_OTP_CODE = "2656"


def _normalize_phone(phone: str) -> str:
    digits = re.sub(r"\D", "", phone or "")
    if digits.startswith("998") and len(digits) == 12:
        return f"+{digits}"
    if len(digits) == 9:
        return f"+998{digits}"
    raise HTTPException(status_code=400, detail=_PHONE_ERROR)


def _generate_otp_code() -> str:
    return f"{random.SystemRandom().randint(0, 9999):04d}"


def _resolve_phone(phone: str) -> tuple[str, bool]:
    raw = (phone or "").strip()
    if raw in _TESTER_PHONE_ALIASES:
        return _TESTER_PHONE_ALIASES[raw], True
    return _normalize_phone(raw), False


def _latest_otp(db: Session, phone: str) -> OtpCode | None:
    return db.scalar(
        select(OtpCode)
        .where(OtpCode.phone == phone)
        .order_by(desc(OtpCode.created_at))
    )


def _ensure_otp_valid(db: Session, phone: str, otp_value: str) -> OtpCode:
    now = datetime.now(timezone.utc)
    otp = _latest_otp(db, phone)
    if not otp:
        raise HTTPException(status_code=400, detail="OTP topilmadi")
    if now > otp.expires_at:
        raise HTTPException(status_code=400, detail="OTP muddati tugagan")
    if not hmac.compare_digest((otp_value or "").strip(), otp.code):
        raise HTTPException(status_code=400, detail="OTP noto'g'ri")
    return otp


def _validate_password(password: str) -> str:
    normalized = (password or "").strip()
    if len(normalized) < 8:
        raise HTTPException(status_code=400, detail="Parol kamida 8 ta belgidan iborat bo'lishi kerak")
    if len(normalized.encode("utf-8")) > 72:
        raise HTTPException(status_code=400, detail="Parol juda uzun. Maksimal 72 bayt")
    return normalized


@router.post("/phone-status", response_model=PhoneStatusOut)
def phone_status(payload: PhoneIn, db: Session = Depends(get_db)):
    phone, _ = _resolve_phone(payload.phone)
    user = db.scalar(select(User).where(User.phone == phone))
    return PhoneStatusOut(
        phone=phone,
        exists=user is not None,
        has_password=bool(user and user.password_hash),
    )


@router.post("/request-otp", response_model=MessageOut)
def request_otp(payload: RequestOtpIn, db: Session = Depends(get_db)):
    phone, is_tester = _resolve_phone(payload.phone)
    now = datetime.now(timezone.utc)
    user = db.scalar(select(User).where(User.phone == phone))

    if payload.reason == OtpReason.register and user and user.password_hash:
        raise HTTPException(status_code=409, detail="Bu raqam allaqachon ro'yxatdan o'tgan. Parol bilan kiring")

    if payload.reason == OtpReason.reset_password and (not user or not user.password_hash):
        raise HTTPException(status_code=404, detail="Ushbu raqam uchun parol topilmadi")

    if not is_tester:
        latest = _latest_otp(db, phone)
        if latest:
            cooldown = (now - latest.created_at).total_seconds()
            if cooldown < settings.otp_cooldown_seconds:
                wait_seconds = max(1, int(settings.otp_cooldown_seconds - cooldown))
                raise HTTPException(
                    status_code=429,
                    detail=f"Kodni qayta yuborish uchun {wait_seconds} soniya kuting",
                )

    code = _TESTER_OTP_CODE if is_tester else _generate_otp_code()
    expires_at = now + timedelta(minutes=settings.otp_ttl_minutes)

    if not is_tester:
        provider = settings.sms_provider.strip().lower()
        if provider == "devsms":
            message = (
                f"SafarUz ilovasiga kirish uchun tasdiqlash kodi: {code}. "
                "Kod 5 daqiqa amal qiladi. Kodni hech kimga bermang."
            )
            try:
                send_sms(phone=phone, message=message)
            except DevSmsError as exc:
                raise HTTPException(status_code=502, detail=str(exc)) from exc
        elif provider != "test":
            raise HTTPException(status_code=500, detail="SMS provider noto'g'ri sozlangan")

    otp = OtpCode(phone=phone, code=code, expires_at=expires_at)
    db.add(otp)
    db.commit()

    message = "OTP yuborildi"
    if is_tester:
        message = f"Tester rejimi: OTP {code}"
    elif settings.sms_provider.strip().lower() == "test":
        message = f"OTP yuborildi. Test rejimida kod: {code}"
    return MessageOut(message=message, timestamp=now)


@router.post("/complete-otp", response_model=VerifyOtpOut)
def complete_otp(payload: OtpPasswordCompleteIn, db: Session = Depends(get_db)):
    phone, _ = _resolve_phone(payload.phone)
    _ensure_otp_valid(db, phone, payload.otp)

    user = db.scalar(select(User).where(User.phone == phone))
    if payload.reason == OtpReason.register:
        if not user:
            user = User(phone=phone, role=UserRole.none, name="Foydalanuvchi")
            db.add(user)
        elif user.password_hash:
            raise HTTPException(status_code=409, detail="Bu raqam allaqachon ro'yxatdan o'tgan. Parol bilan kiring")
    else:
        if not user or not user.password_hash:
            raise HTTPException(status_code=404, detail="Ushbu raqam uchun parol topilmadi")

    user.password_hash = hash_password(_validate_password(payload.password))

    db.execute(delete(OtpCode).where(OtpCode.phone == phone))
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(str(user.id))
    return VerifyOtpOut(access_token=token, user=user, role=user.role)


@router.post("/login-password", response_model=VerifyOtpOut)
def login_password(payload: PasswordLoginIn, db: Session = Depends(get_db)):
    phone, _ = _resolve_phone(payload.phone)
    user = db.scalar(select(User).where(User.phone == phone))
    if not user or not user.password_hash:
        raise HTTPException(status_code=404, detail="Foydalanuvchi topilmadi yoki parol o'rnatilmagan")

    if not verify_password(_validate_password(payload.password), user.password_hash):
        raise HTTPException(status_code=401, detail="Parol noto'g'ri")

    token = create_access_token(str(user.id))
    return VerifyOtpOut(access_token=token, user=user, role=user.role)


@router.post("/verify-otp", response_model=VerifyOtpOut)
def verify_otp(payload: VerifyOtpIn, db: Session = Depends(get_db)):
    phone, _ = _resolve_phone(payload.phone)
    _ensure_otp_valid(db, phone, payload.otp)

    user = db.scalar(select(User).where(User.phone == phone))
    if not user:
        user = User(phone=phone, role=UserRole.none, name="Foydalanuvchi")
        db.add(user)
        db.commit()
        db.refresh(user)

    if user.password_hash:
        raise HTTPException(status_code=400, detail="Parol o'rnatilgan. Parol bilan kiring")

    db.execute(delete(OtpCode).where(OtpCode.phone == phone))
    db.commit()

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
