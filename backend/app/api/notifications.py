from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.notification import UserNotification
from app.models.user import User
from app.schemas.notification import NotificationOut, PushTokenIn

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("/my", response_model=list[NotificationOut])
def my_notifications(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    items = db.scalars(
        select(UserNotification)
        .where(UserNotification.user_id == current_user.id)
        .order_by(UserNotification.created_at.desc())
        .limit(100)
    ).all()
    return list(items)


@router.post("/{notification_id}/read")
def mark_read(
    notification_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    n = db.scalar(
        select(UserNotification).where(
            UserNotification.id == notification_id,
            UserNotification.user_id == current_user.id,
        )
    )
    if not n:
        return {"ok": False}
    n.is_read = True
    db.add(n)
    db.commit()
    return {"ok": True}


@router.post("/read-all")
def read_all(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    items = db.scalars(
        select(UserNotification).where(
            UserNotification.user_id == current_user.id,
            UserNotification.is_read.is_(False),
        )
    ).all()
    for n in items:
        n.is_read = True
        db.add(n)
    db.commit()
    return {"ok": True, "updated": len(items)}


@router.post("/push-token")
def set_push_token(
    payload: PushTokenIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    token = payload.token.strip()
    if not token:
        current_user.fcm_token = None
    else:
        current_user.fcm_token = token
    db.add(current_user)
    db.commit()
    return {"ok": True}
