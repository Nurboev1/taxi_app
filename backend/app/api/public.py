from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from app.core.settings import settings

router = APIRouter(tags=["public"])
templates = Jinja2Templates(
    directory=str(Path(__file__).resolve().parent.parent / "templates")
)


def _public_context() -> dict[str, object]:
    bot_username = settings.telegram_support_bot_username.strip() or "SafarUzSupportBot"
    clean_username = bot_username.lstrip("@")
    return {
        "app_name": "SafarUz",
        "support_bot_username": clean_username,
        "support_bot_link": f"https://t.me/{clean_username}",
        "year": datetime.now().year,
    }


@router.get("/", response_class=HTMLResponse)
def public_home(request: Request):
    return templates.TemplateResponse(
        request=request,
        name="public/home.html",
        context=_public_context(),
    )


@router.get("/drivers", response_class=HTMLResponse)
def public_drivers(request: Request):
    return templates.TemplateResponse(
        request=request,
        name="public/drivers.html",
        context=_public_context(),
    )
