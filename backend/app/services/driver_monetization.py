import base64
from datetime import datetime, timezone
from urllib.parse import quote_plus

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.settings import settings
from app.models.driver_payment import DriverPayment
from app.models.driver_subscription import DriverSubscription
from app.models.monetization_setting import MonetizationSetting
from app.models.user import User

SUB_STATUS_INACTIVE = "inactive"
SUB_STATUS_ACTIVE = "active"
SUB_STATUS_PAUSED = "paused"
SUB_STATUS_EXPIRED = "expired"

PAYMENT_STATUS_PENDING = "pending"
PAYMENT_STATUS_PAID = "paid"
PAYMENT_STATUS_FAILED = "failed"
PAYMENT_STATUS_CANCELLED = "cancelled"

SECONDS_PER_MONTH = 30 * 24 * 60 * 60


def get_or_create_monetization_settings(db: Session) -> MonetizationSetting:
    row = db.scalar(select(MonetizationSetting).where(MonetizationSetting.id == 1))
    if row:
        return row
    row = MonetizationSetting(id=1)
    db.add(row)
    db.flush()
    return row


def get_or_create_driver_subscription(db: Session, user_id: int) -> DriverSubscription:
    row = db.scalar(select(DriverSubscription).where(DriverSubscription.user_id == user_id))
    if row:
        return row
    row = DriverSubscription(user_id=user_id)
    db.add(row)
    db.flush()
    return row


def sync_driver_subscription(
    db: Session,
    subscription: DriverSubscription,
    monetization: MonetizationSetting,
    *,
    now: datetime | None = None,
) -> DriverSubscription:
    current_time = now or datetime.now(timezone.utc)
    changed = False

    if subscription.countdown_started_at and subscription.remaining_seconds > 0:
        elapsed = max(
            0,
            int((current_time - subscription.countdown_started_at).total_seconds()),
        )
        if elapsed > 0:
            subscription.remaining_seconds = max(0, subscription.remaining_seconds - elapsed)
            subscription.countdown_started_at = current_time
            changed = True

    if subscription.remaining_seconds <= 0:
        if subscription.remaining_seconds != 0:
            subscription.remaining_seconds = 0
            changed = True
        if subscription.status != SUB_STATUS_EXPIRED:
            subscription.status = SUB_STATUS_EXPIRED
            changed = True
        if subscription.countdown_started_at is not None:
            subscription.countdown_started_at = None
            changed = True
    elif monetization.driver_paid_mode_enabled:
        if subscription.status != SUB_STATUS_ACTIVE:
            subscription.status = SUB_STATUS_ACTIVE
            changed = True
        if subscription.countdown_started_at is None:
            subscription.countdown_started_at = current_time
            changed = True
    else:
        if subscription.status != SUB_STATUS_PAUSED:
            subscription.status = SUB_STATUS_PAUSED
            changed = True
        if subscription.countdown_started_at is not None:
            subscription.countdown_started_at = None
            changed = True

    if changed:
        db.add(subscription)
        db.flush()
    return subscription


def available_payment_providers(monetization: MonetizationSetting) -> list[str]:
    providers: list[str] = []
    if monetization.click_enabled and settings.click_checkout_url_template.strip():
        providers.append("click")
    if monetization.payme_enabled and settings.payme_merchant_id.strip():
        providers.append("payme")
    return providers


def driver_monetization_payload(
    db: Session,
    user: User,
    *,
    now: datetime | None = None,
) -> dict[str, object]:
    monetization = get_or_create_monetization_settings(db)
    subscription = get_or_create_driver_subscription(db, user.id)
    sync_driver_subscription(db, subscription, monetization, now=now)
    has_active_subscription = subscription.remaining_seconds > 0
    return {
        "enabled": monetization.driver_paid_mode_enabled,
        "monthly_price": monetization.driver_monthly_price,
        "providers": available_payment_providers(monetization),
        "has_active_subscription": has_active_subscription,
        "remaining_seconds": subscription.remaining_seconds,
        "remaining_days": subscription.remaining_seconds // 86400,
        "status": subscription.status,
        "show_payment_menu": monetization.driver_paid_mode_enabled,
        "can_switch_to_driver": (not monetization.driver_paid_mode_enabled) or has_active_subscription,
    }


def enforce_driver_paid_access(db: Session, user: User) -> None:
    payload = driver_monetization_payload(db, user)
    if payload["enabled"] and not payload["has_active_subscription"]:
        raise HTTPException(
            status_code=402,
            detail={
                "code": "DRIVER_SUBSCRIPTION_REQUIRED",
                "message": "Haydovchi rejimi uchun oylik to'lov faol. Avval obunani faollashtiring.",
                "monetization": payload,
            },
        )


def extend_driver_subscription(
    db: Session,
    *,
    user_id: int,
    months_count: int,
    amount: int,
    provider: str,
) -> DriverSubscription:
    monetization = get_or_create_monetization_settings(db)
    subscription = get_or_create_driver_subscription(db, user_id)
    sync_driver_subscription(db, subscription, monetization)
    now = datetime.now(timezone.utc)
    subscription.remaining_seconds += months_count * SECONDS_PER_MONTH
    subscription.last_payment_at = now
    subscription.last_payment_amount = amount
    subscription.last_payment_provider = provider
    subscription.status = (
        SUB_STATUS_ACTIVE if monetization.driver_paid_mode_enabled else SUB_STATUS_PAUSED
    )
    subscription.countdown_started_at = now if monetization.driver_paid_mode_enabled else None
    db.add(subscription)
    db.flush()
    return subscription


def build_click_checkout_url(
    *,
    payment: DriverPayment,
    user: User,
) -> str:
    template = settings.click_checkout_url_template.strip()
    if not template:
        raise HTTPException(status_code=400, detail="Click checkout URL sozlanmagan")
    return (
        template.replace("{payment_id}", str(payment.id))
        .replace("{user_id}", str(user.id))
        .replace("{amount}", str(payment.amount))
        .replace("{amount_tiyin}", str(payment.amount * 100))
        .replace("{phone}", quote_plus(user.phone))
        .replace("{return_url}", quote_plus(settings.payment_return_url.strip()))
    )


def build_payme_checkout_url(payment: DriverPayment) -> str:
    merchant_id = settings.payme_merchant_id.strip()
    if not merchant_id:
        raise HTTPException(status_code=400, detail="Payme merchant sozlanmagan")
    payload = (
        f"m={merchant_id};"
        f"ac.{settings.payme_account_field.strip() or 'payment_id'}={payment.id};"
        f"a={payment.amount * 100};"
        f"l=uz;"
        f"c={settings.payment_return_url.strip()}"
    )
    encoded = base64.b64encode(payload.encode("utf-8")).decode("utf-8")
    base_url = settings.payme_checkout_base_url.strip() or "https://checkout.paycom.uz"
    return f"{base_url.rstrip('/')}/{encoded}"


def create_driver_payment(
    db: Session,
    *,
    user: User,
    provider: str,
    months_count: int,
) -> DriverPayment:
    monetization = get_or_create_monetization_settings(db)
    if not monetization.driver_paid_mode_enabled:
        raise HTTPException(status_code=400, detail="Pullik rejim hozircha o'chiq")
    if monetization.driver_monthly_price <= 0:
        raise HTTPException(status_code=400, detail="Oylik narx hali sozlanmagan")
    if provider not in available_payment_providers(monetization):
        raise HTTPException(status_code=400, detail="Tanlangan to'lov usuli mavjud emas")
    if months_count < 1:
        raise HTTPException(status_code=400, detail="Kamida 1 oy tanlanishi kerak")

    payment = DriverPayment(
        user_id=user.id,
        provider=provider,
        amount=monetization.driver_monthly_price * months_count,
        months_count=months_count,
        status=PAYMENT_STATUS_PENDING,
    )
    db.add(payment)
    db.flush()

    if provider == "click":
        payment.checkout_url = build_click_checkout_url(payment=payment, user=user)
    elif provider == "payme":
        payment.checkout_url = build_payme_checkout_url(payment)

    db.add(payment)
    db.flush()
    return payment


def mark_payment_paid(
    db: Session,
    *,
    payment: DriverPayment,
    note: str | None = None,
) -> DriverPayment:
    if payment.status == PAYMENT_STATUS_PAID:
        return payment
    payment.status = PAYMENT_STATUS_PAID
    payment.paid_at = datetime.now(timezone.utc)
    if note:
        payment.note = note[:255]
    db.add(payment)
    extend_driver_subscription(
        db,
        user_id=payment.user_id,
        months_count=payment.months_count,
        amount=payment.amount,
        provider=payment.provider,
    )
    return payment
