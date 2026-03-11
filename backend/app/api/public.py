from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.templating import Jinja2Templates

from app.core.settings import settings

router = APIRouter(tags=["public"])
REPO_ROOT = Path(__file__).resolve().parents[3]
APK_PATH = REPO_ROOT / "release_assets" / "SafarUz-Android-v1.1.0.apk"
APK_DOWNLOAD_NAME = "SafarUz-Android-v1.1.0.apk"
templates = Jinja2Templates(
    directory=str(Path(__file__).resolve().parent.parent / "templates")
)


def _public_context() -> dict[str, object]:
    bot_username = settings.telegram_support_bot_username.strip() or "SafarUzSupportBot"
    clean_username = bot_username.lstrip("@")
    apk_exists = APK_PATH.exists()
    apk_size_mb = round(APK_PATH.stat().st_size / (1024 * 1024), 1) if apk_exists else None
    apk_updated_at = (
        datetime.fromtimestamp(APK_PATH.stat().st_mtime).strftime("%Y-%m-%d %H:%M")
        if apk_exists
        else None
    )
    return {
        "app_name": "SafarUz",
        "support_bot_username": clean_username,
        "support_bot_link": f"https://t.me/{clean_username}",
        "apk_available": apk_exists,
        "apk_download_url": "/download/apk",
        "apk_name": APK_DOWNLOAD_NAME,
        "apk_size_mb": apk_size_mb,
        "apk_updated_at": apk_updated_at,
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


@router.get("/download", response_class=HTMLResponse)
def public_download(request: Request):
    return templates.TemplateResponse(
        request=request,
        name="public/download.html",
        context=_public_context(),
    )


@router.get("/download/apk")
def public_download_apk():
    if not APK_PATH.exists():
        raise HTTPException(status_code=404, detail="APK topilmadi")
    return FileResponse(
        path=str(APK_PATH),
        media_type="application/vnd.android.package-archive",
        filename=APK_DOWNLOAD_NAME,
    )
