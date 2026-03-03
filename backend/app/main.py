from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.auth import router as auth_router
from app.api.admin import router as admin_router
from app.api.chat import router as chat_router
from app.api.driver import router as driver_router
from app.api.legal import router as legal_router
from app.api.notifications import router as notifications_router
from app.api.requests import router as request_router
from app.api.rating import router as rating_router
from app.api.role import router as role_router
from app.core.settings import settings

app = FastAPI(title=settings.app_name)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok"}


app.include_router(auth_router)
app.include_router(admin_router)
app.include_router(role_router)
app.include_router(driver_router)
app.include_router(request_router)
app.include_router(chat_router)
app.include_router(rating_router)
app.include_router(notifications_router)
app.include_router(legal_router)
