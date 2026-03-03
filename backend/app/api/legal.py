from pathlib import Path

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

router = APIRouter(prefix="/legal", tags=["legal"])
templates = Jinja2Templates(
    directory=str(Path(__file__).resolve().parent.parent / "templates")
)


@router.get("/privacy", response_class=HTMLResponse)
def privacy_policy(request: Request):
    return templates.TemplateResponse(
        request=request,
        name="legal/privacy.html",
        context={},
    )


@router.get("/terms", response_class=HTMLResponse)
def terms_of_use(request: Request):
    return templates.TemplateResponse(
        request=request,
        name="legal/terms.html",
        context={},
    )
