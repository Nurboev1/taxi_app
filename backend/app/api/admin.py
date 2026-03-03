from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from fastapi import APIRouter, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from jose import JWTError, jwt
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.security import ALGORITHM
from app.core.settings import settings
from app.db.session import SessionLocal
from app.models.chat import Chat, ChatMessage
from app.models.claim import RequestClaim
from app.models.rating import TripRating
from app.models.request import PassengerRequest
from app.models.trip import DriverTrip
from app.models.user import User
from app.models.enums import ClaimStatus, UserRole

router = APIRouter(prefix="/admin", tags=["admin"])
templates = Jinja2Templates(directory=str(Path(__file__).resolve().parent.parent / "templates"))

ADMIN_COOKIE = "admin_session"


def _create_admin_token(username: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.admin_token_expire_minutes)
    payload = {"sub": f"admin:{username}", "exp": expire}
    return jwt.encode(payload, settings.secret_key, algorithm=ALGORITHM)


def _verify_admin_token(token: str | None) -> bool:
    if not token:
        return False
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[ALGORITHM])
        sub = str(payload.get("sub", ""))
        return sub == f"admin:{settings.admin_username}"
    except JWTError:
        return False


def _admin_required(request: Request) -> bool:
    return _verify_admin_token(request.cookies.get(ADMIN_COOKIE))


@router.get("/login", response_class=HTMLResponse)
def admin_login_page(request: Request):
    if _admin_required(request):
        return RedirectResponse(url="/admin", status_code=302)
    return templates.TemplateResponse(
        request=request,
        name="admin/login.html",
        context={"error": None},
    )


@router.post("/login", response_class=HTMLResponse)
def admin_login(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
):
    if username != settings.admin_username or password != settings.admin_password:
        return templates.TemplateResponse(
            request=request,
            name="admin/login.html",
            context={"error": "Login yoki parol noto'g'ri"},
        )

    token = _create_admin_token(username)
    response = RedirectResponse(url="/admin", status_code=302)
    response.set_cookie(
        key=ADMIN_COOKIE,
        value=token,
        httponly=True,
        max_age=settings.admin_token_expire_minutes * 60,
        samesite="lax",
    )
    return response


@router.get("/logout")
def admin_logout():
    response = RedirectResponse(url="/admin/login", status_code=302)
    response.delete_cookie(ADMIN_COOKIE)
    return response


@router.get("", response_class=HTMLResponse)
def admin_dashboard(request: Request):
    if not _admin_required(request):
        return RedirectResponse(url="/admin/login", status_code=302)

    db: Session = SessionLocal()
    try:
        tab = request.query_params.get("tab", "overview")
        trip_date_raw = request.query_params.get("trip_date")
        selected_trip_date: date | None = None
        if trip_date_raw:
            try:
                selected_trip_date = date.fromisoformat(trip_date_raw)
            except ValueError:
                selected_trip_date = None

        lookup_user_id_raw = request.query_params.get("user_id")
        driver_access_user_id_raw = request.query_params.get("driver_access_user_id")
        driver_access_status = request.query_params.get("driver_access_status")
        lookup_user: User | None = None
        lookup_user_stats: dict[str, int] | None = None
        lookup_error: str | None = None
        driver_access_user: User | None = None
        driver_access_error: str | None = None

        users_total = db.scalar(select(func.count(User.id))) or 0
        drivers_total = db.scalar(select(func.count(User.id)).where(User.role == UserRole.driver)) or 0
        passengers_total = db.scalar(select(func.count(User.id)).where(User.role == UserRole.passenger)) or 0
        trips_total = db.scalar(select(func.count(DriverTrip.id))) or 0
        requests_total = db.scalar(select(func.count(PassengerRequest.id))) or 0
        claims_total = db.scalar(select(func.count(RequestClaim.id))) or 0
        chats_total = db.scalar(select(func.count(Chat.id))) or 0
        messages_total = db.scalar(select(func.count(ChatMessage.id))) or 0
        ratings_total = db.scalar(select(func.count(TripRating.id))) or 0

        recent_users = db.scalars(select(User).order_by(User.created_at.desc()).limit(10)).all()
        recent_requests = db.scalars(select(PassengerRequest).order_by(PassengerRequest.created_at.desc()).limit(10)).all()

        trips_stmt = select(DriverTrip).order_by(DriverTrip.start_time.desc())
        if selected_trip_date is not None:
            day_start = datetime(selected_trip_date.year, selected_trip_date.month, selected_trip_date.day, tzinfo=timezone.utc)
            day_end = day_start + timedelta(days=1)
            trips_stmt = trips_stmt.where(DriverTrip.start_time >= day_start, DriverTrip.start_time < day_end)
        trips = db.scalars(trips_stmt.limit(200)).all()

        trip_rows: list[dict] = []
        for t in trips:
            driver = db.scalar(select(User).where(User.id == t.driver_id))
            claims = db.scalars(
                select(RequestClaim).where(
                    RequestClaim.trip_id == t.id,
                    RequestClaim.status.in_([ClaimStatus.accepted, ClaimStatus.completed]),
                )
            ).all()
            passengers: list[dict] = []
            for claim in claims:
                req = db.scalar(select(PassengerRequest).where(PassengerRequest.id == claim.request_id))
                if not req:
                    continue
                pax = db.scalar(select(User).where(User.id == req.passenger_id))
                if not pax:
                    continue
                passengers.append(
                    {
                        "id": pax.id,
                        "name": pax.name,
                        "gender": pax.gender.value if pax.gender else "-",
                        "request_id": req.id,
                        "claim_status": claim.status.value,
                    }
                )
            trip_rows.append(
                {
                    "id": t.id,
                    "from_location": t.from_location,
                    "to_location": t.to_location,
                    "start_time": t.start_time,
                    "status": t.status.value,
                    "driver_id": t.driver_id,
                    "driver_first_name": driver.first_name if driver else None,
                    "driver_last_name": driver.last_name if driver else None,
                    "driver_name": driver.name if driver else "-",
                    "passengers": passengers,
                }
            )

        if lookup_user_id_raw:
            try:
                lookup_id = int(lookup_user_id_raw)
                lookup_user = db.scalar(select(User).where(User.id == lookup_id))
                if lookup_user:
                    lookup_user_stats = {
                        "driver_trips": db.scalar(select(func.count(DriverTrip.id)).where(DriverTrip.driver_id == lookup_user.id)) or 0,
                        "passenger_requests": db.scalar(
                            select(func.count(PassengerRequest.id)).where(PassengerRequest.passenger_id == lookup_user.id)
                        )
                        or 0,
                        "given_ratings": db.scalar(select(func.count(TripRating.id)).where(TripRating.passenger_id == lookup_user.id))
                        or 0,
                        "received_ratings": db.scalar(select(func.count(TripRating.id)).where(TripRating.driver_id == lookup_user.id))
                        or 0,
                    }
                else:
                    lookup_error = "Bunday ID bilan foydalanuvchi topilmadi"
            except ValueError:
                lookup_error = "Foydalanuvchi ID raqam bo'lishi kerak"

        if driver_access_user_id_raw:
            try:
                did = int(driver_access_user_id_raw)
                driver_access_user = db.scalar(select(User).where(User.id == did))
                if not driver_access_user:
                    driver_access_error = "Bunday ID bilan foydalanuvchi topilmadi"
            except ValueError:
                driver_access_error = "Foydalanuvchi ID raqam bo'lishi kerak"
    finally:
        db.close()

    return templates.TemplateResponse(
        request=request,
        name="admin/dashboard.html",
        context={
            "stats": {
                "users_total": users_total,
                "drivers_total": drivers_total,
                "passengers_total": passengers_total,
                "trips_total": trips_total,
                "requests_total": requests_total,
                "claims_total": claims_total,
                "chats_total": chats_total,
                "messages_total": messages_total,
                "ratings_total": ratings_total,
            },
            "recent_users": recent_users,
            "recent_requests": recent_requests,
            "tab": tab,
            "trip_rows": trip_rows,
            "selected_trip_date": trip_date_raw or "",
            "lookup_user": lookup_user,
            "lookup_user_stats": lookup_user_stats,
            "lookup_error": lookup_error,
            "lookup_user_id": lookup_user_id_raw or "",
            "driver_access_user_id": driver_access_user_id_raw or "",
            "driver_access_user": driver_access_user,
            "driver_access_error": driver_access_error,
            "driver_access_status": driver_access_status or "",
        },
    )


@router.post("/driver-access")
def admin_driver_access(
    request: Request,
    user_id: int = Form(...),
    action: str = Form(...),
):
    if not _admin_required(request):
        return RedirectResponse(url="/admin/login", status_code=302)

    db: Session = SessionLocal()
    try:
        user = db.scalar(select(User).where(User.id == user_id))
        if not user:
            return RedirectResponse(
                url=f"/admin?tab=driver_access&driver_access_user_id={user_id}&driver_access_status=not_found",
                status_code=302,
            )

        if action == "block":
            user.driver_blocked = True
            user.driver_access_override = False
            user.driver_block_reason = "admin_block"
            user.driver_unblocked_at = None
            if user.role == UserRole.driver:
                user.role = UserRole.passenger
            status = "blocked"
        elif action == "unblock":
            user.driver_blocked = False
            user.driver_access_override = True
            user.driver_block_reason = "admin_unblock"
            user.driver_unblocked_at = datetime.now(timezone.utc)
            status = "unblocked"
        else:
            status = "bad_action"
        db.add(user)
        db.commit()
    finally:
        db.close()

    return RedirectResponse(
        url=f"/admin?tab=driver_access&driver_access_user_id={user_id}&driver_access_status={status}",
        status_code=302,
    )
