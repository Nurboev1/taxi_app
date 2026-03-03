from datetime import datetime, timedelta, timezone

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import ALGORITHM
from app.core.settings import settings
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.user import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/verify-otp")


def _sync_driver_block_status(db: Session, user: User) -> None:
    if user.driver_blocked:
        return
    check_from = user.driver_unblocked_at or user.created_at
    if check_from <= datetime.now(timezone.utc) - timedelta(days=30):
        user.driver_blocked = True
        user.driver_access_override = False
        user.driver_block_reason = "auto_30_days"
        user.driver_unblocked_at = None
        db.add(user)
        db.commit()
        db.refresh(user)


def is_driver_blocked(user: User) -> bool:
    return bool(user.driver_blocked)


def get_current_user(db: Session = Depends(get_db), token: str = Depends(oauth2_scheme)) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token yaroqsiz",
    )
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[ALGORITHM])
        user_id = int(payload.get("sub"))
    except (JWTError, TypeError, ValueError):
        raise credentials_exception

    user = db.scalar(select(User).where(User.id == user_id))
    if not user:
        raise credentials_exception
    _sync_driver_block_status(db, user)
    return user


def require_role(role: UserRole):
    def checker(user: User = Depends(get_current_user)) -> User:
        if user.role != role:
            raise HTTPException(status_code=403, detail="Sizda bu amal uchun ruxsat yo'q")
        if role == UserRole.driver and is_driver_blocked(user):
            raise HTTPException(status_code=403, detail={"code": "DRIVER_BLOCKED", "message": "Haydovchi akkaunti bloklangan"})
        return user

    return checker
