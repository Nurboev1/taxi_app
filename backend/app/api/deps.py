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
from app.services.driver_monetization import enforce_driver_paid_access

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/verify-otp")


def _sync_driver_block_status(db: Session, user: User) -> None:
    # Automatic 30-day driver blocking disabled.
    _ = db
    _ = user


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
    def checker(
        user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
    ) -> User:
        if user.role != role:
            raise HTTPException(status_code=403, detail="Sizda bu amal uchun ruxsat yo'q")
        if role == UserRole.driver and is_driver_blocked(user):
            raise HTTPException(status_code=403, detail={"code": "DRIVER_BLOCKED", "message": "Haydovchi akkaunti bloklangan"})
        if role == UserRole.driver:
            enforce_driver_paid_access(db, user)
        return user

    return checker
