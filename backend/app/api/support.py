from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request

from app.api.auth import _client_ip, _enforce_rate_limit
from app.api.deps import get_current_user
from app.core.settings import settings
from app.models.user import User
from app.schemas.support import SupportContactIn, SupportContactOut
from app.services.telegram_support import TelegramSupportError, send_support_message

router = APIRouter(prefix="/support", tags=["support"])


@router.post("/contact", response_model=SupportContactOut)
def contact_support(
    request: Request,
    payload: SupportContactIn,
    current_user: User = Depends(get_current_user),
):
    ip = _client_ip(request)
    _enforce_rate_limit(
        key=f"support:contact:ip:{ip}",
        limit=settings.auth_rate_support_contact_per_ip,
        window_seconds=settings.auth_rate_window_seconds,
    )

    subject = payload.subject.strip()
    message = payload.message.strip()
    if not message:
        raise HTTPException(status_code=400, detail="Xabar bo'sh bo'lmasligi kerak")

    try:
        send_support_message(
            user_id=current_user.id,
            phone=current_user.phone,
            name=current_user.name or "Unknown",
            role=current_user.role.value,
            subject=subject,
            message=message,
        )
    except TelegramSupportError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    return SupportContactOut(
        message="Support xabari yuborildi",
        sent_at=datetime.now(timezone.utc),
    )
