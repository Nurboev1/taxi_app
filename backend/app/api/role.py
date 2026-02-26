from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.security import create_access_token
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.auth import SetRoleIn

router = APIRouter(prefix="/role", tags=["role"])


@router.post("/set")
def set_role(
    payload: SetRoleIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if payload.role not in (UserRole.driver, UserRole.passenger):
        raise HTTPException(status_code=400, detail="Role noto'g'ri")

    current_user.role = payload.role
    db.add(current_user)
    db.commit()
    db.refresh(current_user)

    token = create_access_token(str(current_user.id))
    return {"access_token": token, "user": current_user, "role": current_user.role}
