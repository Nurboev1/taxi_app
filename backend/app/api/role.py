from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, is_driver_blocked
from app.core.security import create_access_token
from app.db.session import get_db
from app.models.driver_payment import DriverPayment
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.auth import DriverCheckoutIn, SetRoleIn
from app.services.driver_monetization import (
    PAYMENT_STATUS_PAID,
    create_driver_payment,
    driver_monetization_payload,
    enforce_driver_paid_access,
)

router = APIRouter(prefix="/role", tags=["role"])


@router.post("/set")
def set_role(
    payload: SetRoleIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if payload.role not in (UserRole.driver, UserRole.passenger):
        raise HTTPException(status_code=400, detail="Role noto'g'ri")
    if payload.role == UserRole.driver and is_driver_blocked(current_user):
        raise HTTPException(status_code=403, detail={"code": "DRIVER_BLOCKED", "message": "Haydovchi akkaunti bloklangan"})
    if payload.role == UserRole.driver:
        enforce_driver_paid_access(db, current_user)

    current_user.role = payload.role
    db.add(current_user)
    db.commit()
    db.refresh(current_user)

    token = create_access_token(str(current_user.id))
    return {"access_token": token, "user": current_user, "role": current_user.role}


@router.get("/driver-monetization")
def get_driver_monetization(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return driver_monetization_payload(db, current_user)


@router.post("/driver-monetization/checkout")
def create_driver_checkout(
    payload: DriverCheckoutIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    payment = create_driver_payment(
        db,
        user=current_user,
        provider=(payload.provider or "").strip().lower(),
        months_count=payload.months_count,
    )
    db.commit()
    return {
        "payment_id": payment.id,
        "provider": payment.provider,
        "payment_url": payment.checkout_url,
        "status": payment.status,
    }


@router.get("/driver-monetization/payments/{payment_id}")
def get_driver_payment_status(
    payment_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    payment = db.get(DriverPayment, payment_id)
    if not payment or payment.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="To'lov topilmadi")

    return {
        "payment_id": payment.id,
        "status": payment.status,
        "provider": payment.provider,
        "amount": payment.amount,
        "is_paid": payment.status == PAYMENT_STATUS_PAID,
        "monetization": driver_monetization_payload(db, current_user),
    }
