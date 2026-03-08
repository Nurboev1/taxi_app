import csv
from datetime import date, datetime, timedelta, timezone
import io
import json
import os
from pathlib import Path
import subprocess
import time
from typing import Iterable
from uuid import uuid4

from fastapi import APIRouter, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse, Response
from fastapi.templating import Jinja2Templates
from jose import JWTError, jwt
from sqlalchemy import func, or_, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.core.security import ALGORITHM, hash_password, verify_password
from app.core.settings import settings
from app.db.session import SessionLocal
from app.models.admin_audit_log import AdminAuditLog
from app.models.admin_credential import AdminCredential
from app.models.chat import Chat, ChatMessage
from app.models.claim import RequestClaim
from app.models.notification import UserNotification
from app.models.rating import TripRating
from app.models.request import PassengerRequest
from app.models.support_ticket import SupportTicket
from app.models.support_ticket_message import SupportTicketMessage
from app.models.trip import DriverTrip
from app.models.user import User
from app.models.enums import ClaimStatus, RequestStatus, TripStatus, UserRole
from app.services.support_tickets import (
    SENDER_SUPPORT,
    TICKET_STATUS_CLOSED,
    TICKET_STATUS_IN_PROGRESS,
    TICKET_STATUS_OPEN,
    append_ticket_message,
    auto_close_stale_tickets,
)
from app.services.telegram_support import TelegramSupportError, send_bot_reply

router = APIRouter(prefix="/admin", tags=["admin"])
templates = Jinja2Templates(directory=str(Path(__file__).resolve().parent.parent / "templates"))

ADMIN_COOKIE = "admin_session"
ADMIN_ROLE_SUPERADMIN = "superadmin"
ADMIN_ROLE_SUPPORT = "support"
ADMIN_ROLE_OPS = "ops"
ADMIN_ROLES = (ADMIN_ROLE_SUPERADMIN, ADMIN_ROLE_SUPPORT, ADMIN_ROLE_OPS)
ADMIN_ROLE_LABELS = {
    ADMIN_ROLE_SUPERADMIN: "Superadmin",
    ADMIN_ROLE_SUPPORT: "Support",
    ADMIN_ROLE_OPS: "Ops",
}
ADMIN_TAB_ACCESS = {
    ADMIN_ROLE_SUPERADMIN: {
        "overview",
        "trips",
        "users",
        "driver_access",
        "resources",
        "errors",
        "security",
        "admin_accounts",
        "support_tickets",
        "search360",
    },
    ADMIN_ROLE_SUPPORT: {"overview", "trips", "users", "errors", "security", "support_tickets", "search360"},
    ADMIN_ROLE_OPS: {"overview", "resources", "errors", "security", "search360"},
}

SUPPORT_TICKET_ESCALATE_MINUTES = 30
SUPPORT_TICKET_AUTO_CLOSE_HOURS = 24
OVERVIEW_WINDOWS_HOURS = {
    "24h": 24,
    "7d": 24 * 7,
    "30d": 24 * 30,
    "90d": 24 * 90,
}
OVERVIEW_WINDOW_LABELS = {
    "24h": "So'nggi 24 soat",
    "7d": "So'nggi 7 kun",
    "30d": "So'nggi 30 kun",
    "90d": "So'nggi 90 kun",
}
SEARCH_KIND_VALUES = {"all", "user", "ticket", "trip", "request", "claim", "audit"}
SEARCH_KIND_ALIASES = {
    "u": "user",
    "user": "user",
    "users": "user",
    "t": "trip",
    "trip": "trip",
    "trips": "trip",
    "r": "request",
    "req": "request",
    "request": "request",
    "requests": "request",
    "c": "claim",
    "claim": "claim",
    "claims": "claim",
    "ticket": "ticket",
    "tickets": "ticket",
    "s": "ticket",
    "audit": "audit",
    "log": "audit",
    "logs": "audit",
    "all": "all",
}
SUPPORT_SAVED_REPLIES = [
    {
        "key": "password_reset",
        "label": "Parolni tiklash yo'riqnomasi",
        "text": (
            "Parolni tiklash uchun ilovada `Parolni unutdingizmi?` tugmasini bosing, "
            "telefon raqamingizni kiriting va OTP orqali yangi parol o'rnating."
        ),
    },
    {
        "key": "payment_check",
        "label": "To'lov tekshirilmoqda",
        "text": (
            "To'lov holatini tekshirishga berdik. Iltimos, to'lov vaqti va summani yozib yuboring. "
            "Tekshiruv yakuni bo'yicha alohida xabar beramiz."
        ),
    },
    {
        "key": "trip_delay",
        "label": "Safar kechikishi",
        "text": (
            "Safar bo'yicha holat tekshirilyapti. Driver/passenger bilan bog'lanib, "
            "aniq javobni qisqa vaqt ichida beramiz."
        ),
    },
    {
        "key": "driver_block_reason",
        "label": "Driver cheklov sababi",
        "text": (
            "Akkount vaqtincha cheklangan. Sabab va keyingi qadamlarni tekshirib, "
            "tasdiqdan so'ng kirishni qayta ochish bo'yicha javob beramiz."
        ),
    },
    {
        "key": "need_evidence",
        "label": "Dalil so'rash",
        "text": (
            "Iltimos, muammo bo'yicha dalil yuboring: screenshot, video yoki voice. "
            "Shunda tekshiruvni tezroq yakunlaymiz."
        ),
    },
]
SUPPORT_SAVED_REPLY_MAP = {item["key"]: item["text"] for item in SUPPORT_SAVED_REPLIES}


def _normalize_admin_role(role: str | None) -> str:
    value = (role or "").strip().lower()
    if value not in ADMIN_ROLES:
        return ADMIN_ROLE_SUPPORT
    return value


def _create_admin_token(username: str, role: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.admin_token_expire_minutes)
    payload = {"sub": "admin", "usr": username, "role": _normalize_admin_role(role), "exp": expire}
    return jwt.encode(payload, settings.secret_key, algorithm=ALGORITHM)


def _decode_admin_token(token: str | None) -> dict[str, str] | None:
    if not token:
        return None
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[ALGORITHM])
        sub = str(payload.get("sub", ""))
        username = ""
        role = payload.get("role")

        if sub.startswith("admin:"):
            # Legacy token support.
            username = sub.split(":", 1)[1]
            role = ADMIN_ROLE_SUPERADMIN if username == settings.admin_username else ADMIN_ROLE_SUPPORT
        elif sub == "admin":
            username = str(payload.get("usr", "")).strip()

        if not username:
            return None

        return {
            "username": username,
            "role": _normalize_admin_role(str(role or ADMIN_ROLE_SUPPORT)),
        }
    except JWTError:
        return None


def _get_admin_session(request: Request) -> dict[str, str] | None:
    return _decode_admin_token(request.cookies.get(ADMIN_COOKIE))


def _admin_required(request: Request, allowed_roles: Iterable[str] | None = None) -> bool:
    session_data = _get_admin_session(request)
    if not session_data:
        return False
    if allowed_roles is None:
        return True
    return session_data["role"] in set(allowed_roles)


def _can_access_tab(role: str, tab: str) -> bool:
    return tab in ADMIN_TAB_ACCESS.get(_normalize_admin_role(role), set())


def _load_admin_credential(db: Session, username: str) -> AdminCredential | None:
    try:
        return db.scalar(
            select(AdminCredential).where(
                AdminCredential.username == username
            )
        )
    except SQLAlchemyError:
        # Migration hali qo'llanmagan bo'lishi mumkin.
        return None


def _admin_password_matches(db: Session, username: str, password: str) -> bool:
    cred = _load_admin_credential(db, username)
    if cred:
        if not cred.is_active:
            return False
        return verify_password(password, cred.password_hash)
    return username == settings.admin_username and password == settings.admin_password


def _validate_admin_new_password(password: str) -> str:
    value = (password or "").strip()
    if len(value) < 8:
        raise ValueError("Yangi parol kamida 8 ta belgidan iborat bo'lishi kerak")
    if len(value.encode("utf-8")) > 72:
        raise ValueError("Yangi parol juda uzun. Maksimal 72 bayt")
    return value


def _validate_admin_username(username: str) -> str:
    value = (username or "").strip()
    if len(value) < 3 or len(value) > 100:
        raise ValueError("Login 3-100 oralig'ida bo'lishi kerak")
    if " " in value:
        raise ValueError("Login ichida probel bo'lmasin")
    return value


def _normalize_ip(raw: str | None) -> str | None:
    value = (raw or "").strip()
    if not value:
        return None
    return value[:128]


def _extract_request_client_ip(request: Request) -> str | None:
    x_forwarded_for = request.headers.get("x-forwarded-for")
    if x_forwarded_for:
        first = x_forwarded_for.split(",", 1)[0].strip()
        normalized = _normalize_ip(first)
        if normalized:
            return normalized
    x_real_ip = _normalize_ip(request.headers.get("x-real-ip"))
    if x_real_ip:
        return x_real_ip
    client_host = _normalize_ip(request.client.host if request.client else None)
    if client_host:
        return client_host
    return None


def _serialize_audit_state(value: dict[str, object] | None) -> str | None:
    if not value:
        return None
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def _normalize_search_kind(value: str | None) -> str:
    normalized = (value or "").strip().lower()
    return normalized if normalized in SEARCH_KIND_VALUES else "all"


def _parse_search_query(raw_query: str | None, fallback_kind: str) -> tuple[str, str]:
    query = (raw_query or "").strip()
    if not query:
        return "", fallback_kind
    if ":" not in query:
        return query, fallback_kind
    prefix, suffix = query.split(":", 1)
    mapped_kind = SEARCH_KIND_ALIASES.get(prefix.strip().lower())
    if mapped_kind and suffix.strip():
        return suffix.strip(), mapped_kind
    return query, fallback_kind


def _write_admin_audit_log(
    request: Request,
    db: Session,
    actor_username: str,
    action: str,
    target_username: str | None = None,
    details: str | None = None,
    before_state: dict[str, object] | None = None,
    after_state: dict[str, object] | None = None,
) -> None:
    request_id = (request.headers.get("x-request-id") or "").strip() or str(uuid4())
    user_agent = (request.headers.get("user-agent") or "").strip() or None
    db.add(
        AdminAuditLog(
            actor_username=actor_username,
            action=action,
            target_username=target_username,
            details=details,
            actor_ip=_extract_request_client_ip(request),
            actor_user_agent=user_agent[:512] if user_agent else None,
            request_id=request_id[:128],
            before_state=_serialize_audit_state(before_state),
            after_state=_serialize_audit_state(after_state),
            created_at=datetime.now(timezone.utc),
        )
    )


def _collect_resource_metrics() -> dict[str, object]:
    try:
        import psutil  # type: ignore
    except Exception:
        return {
            "available": False,
            "error": "psutil topilmadi. `pip install psutil` qiling.",
        }

    def _read_text(path: str) -> str | None:
        try:
            with open(path, "r", encoding="utf-8") as f:
                return f.read().strip()
        except Exception:
            return None

    def _is_running_in_container() -> bool:
        if os.path.exists("/.dockerenv"):
            return True
        cgroup = _read_text("/proc/1/cgroup") or ""
        return "docker" in cgroup or "kubepods" in cgroup or "containerd" in cgroup

    def _cgroup_v2_memory() -> tuple[int | None, int | None]:
        used_raw = _read_text("/sys/fs/cgroup/memory.current")
        limit_raw = _read_text("/sys/fs/cgroup/memory.max")
        if used_raw is None or limit_raw is None:
            return None, None
        try:
            used = int(used_raw)
            limit = None if limit_raw == "max" else int(limit_raw)
            return used, limit
        except ValueError:
            return None, None

    def _cgroup_v1_memory() -> tuple[int | None, int | None]:
        used_raw = _read_text("/sys/fs/cgroup/memory/memory.usage_in_bytes")
        limit_raw = _read_text("/sys/fs/cgroup/memory/memory.limit_in_bytes")
        if used_raw is None or limit_raw is None:
            return None, None
        try:
            used = int(used_raw)
            limit = int(limit_raw)
            # Huge value means "unlimited"
            if limit >= 9_000_000_000_000_000_000:
                limit = None
            return used, limit
        except ValueError:
            return None, None

    def _cgroup_cpu_percent() -> tuple[float | None, float | None]:
        # Returns (cpu_percent, cpu_limit_cores)
        cpu_max = _read_text("/sys/fs/cgroup/cpu.max")
        cpu_stat_before = _read_text("/sys/fs/cgroup/cpu.stat")
        if cpu_max is None or cpu_stat_before is None:
            return None, None

        try:
            quota_str, period_str = cpu_max.split()
            cpu_limit_cores = None if quota_str == "max" else (int(quota_str) / int(period_str))
        except Exception:
            cpu_limit_cores = None

        def _usage_usec(cpu_stat_text: str) -> int | None:
            for line in cpu_stat_text.splitlines():
                if line.startswith("usage_usec "):
                    try:
                        return int(line.split()[1])
                    except Exception:
                        return None
            return None

        u1 = _usage_usec(cpu_stat_before)
        if u1 is None:
            return None, cpu_limit_cores

        t1 = time.time()
        time.sleep(0.2)
        cpu_stat_after = _read_text("/sys/fs/cgroup/cpu.stat")
        if cpu_stat_after is None:
            return None, cpu_limit_cores
        u2 = _usage_usec(cpu_stat_after)
        if u2 is None:
            return None, cpu_limit_cores
        t2 = time.time()

        delta_usage_sec = (u2 - u1) / 1_000_000
        delta_wall_sec = max(0.001, t2 - t1)

        base_cores = cpu_limit_cores if cpu_limit_cores and cpu_limit_cores > 0 else float(psutil.cpu_count(logical=True) or 1)
        percent = (delta_usage_sec / (delta_wall_sec * base_cores)) * 100.0
        return max(0.0, min(100.0, percent)), cpu_limit_cores

    in_container = _is_running_in_container()
    scope = "container" if in_container else "host"

    vm = psutil.virtual_memory()
    disk = psutil.disk_usage("/")
    cpu_percent_host = psutil.cpu_percent(interval=0.2)

    memory_used = vm.used
    memory_total = vm.total
    memory_percent = vm.percent
    cpu_percent = cpu_percent_host
    cpu_limit_cores = None

    if in_container:
        used, limit = _cgroup_v2_memory()
        if used is None:
            used, limit = _cgroup_v1_memory()
        if used is not None:
            memory_used = used
        if limit is not None and limit > 0:
            memory_total = limit
            memory_percent = (memory_used / memory_total) * 100.0

        cpu_pct_cgroup, cpu_limit = _cgroup_cpu_percent()
        if cpu_pct_cgroup is not None:
            cpu_percent = cpu_pct_cgroup
        cpu_limit_cores = cpu_limit

    return {
        "available": True,
        "scope": scope,
        "cpu_percent": round(cpu_percent, 1),
        "cpu_cores_logical": psutil.cpu_count(logical=True) or 0,
        "cpu_cores_physical": psutil.cpu_count(logical=False) or 0,
        "cpu_limit_cores": round(cpu_limit_cores, 2) if cpu_limit_cores is not None else None,
        "memory_used_gb": round(memory_used / (1024**3), 2),
        "memory_total_gb": round(memory_total / (1024**3), 2),
        "memory_percent": round(memory_percent, 1),
        "disk_used_gb": round(disk.used / (1024**3), 2),
        "disk_total_gb": round(disk.total / (1024**3), 2),
        "disk_percent": round(disk.percent, 1),
    }


def _collect_server_errors(service: str, lines: int = 300) -> dict[str, object]:
    normalized_service = (service or "").strip() or "safaruz-backend"
    safe_lines = max(50, min(lines, 2000))
    cmd = [
        "journalctl",
        "-u",
        normalized_service,
        "-n",
        str(safe_lines),
        "--no-pager",
        "--output=short-iso",
    ]
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=6,
            check=False,
        )
    except FileNotFoundError:
        return {
            "available": False,
            "service": normalized_service,
            "error": "journalctl topilmadi. Bu tab Linux systemd serverda ishlaydi.",
        }
    except Exception as exc:
        return {
            "available": False,
            "service": normalized_service,
            "error": f"log o'qishda xatolik: {exc}",
        }

    raw_output = (proc.stdout or "").strip()
    if proc.returncode != 0 and not raw_output:
        stderr = (proc.stderr or "").strip() or f"journalctl return code: {proc.returncode}"
        return {
            "available": False,
            "service": normalized_service,
            "error": stderr,
        }

    all_rows = raw_output.splitlines() if raw_output else []
    keywords = ("ERROR", "Error", "Exception", "Traceback", "CRITICAL", "FATAL", "failed", "Failed")
    error_rows = [line for line in all_rows if any(k in line for k in keywords)]

    return {
        "available": True,
        "service": normalized_service,
        "scanned_lines": len(all_rows),
        "error_count": len(error_rows),
        "rows": error_rows[-200:],
        "generated_at": datetime.now(timezone.utc),
    }


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
    username = username.strip()
    db: Session = SessionLocal()
    try:
        role = ADMIN_ROLE_SUPERADMIN
        login_ok = _admin_password_matches(db, username, password)
        if login_ok:
            cred = _load_admin_credential(db, username)
            if cred and cred.is_active:
                role = _normalize_admin_role(cred.role)
            elif username == settings.admin_username:
                role = ADMIN_ROLE_SUPERADMIN
            else:
                role = ADMIN_ROLE_SUPPORT
    finally:
        db.close()

    if not login_ok:
        return templates.TemplateResponse(
            request=request,
            name="admin/login.html",
            context={"error": "Login yoki parol noto'g'ri"},
        )

    token = _create_admin_token(username, role)
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
    admin_session = _get_admin_session(request)
    if not admin_session:
        return RedirectResponse(url="/admin/login", status_code=302)
    admin_role = admin_session["role"]
    admin_username = admin_session["username"]

    db: Session = SessionLocal()
    try:
        requested_tab = request.query_params.get("tab", "overview")
        tab = requested_tab if _can_access_tab(admin_role, requested_tab) else "overview"
        tab_forbidden = requested_tab != tab
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
        admin_password_status = request.query_params.get("admin_password_status")
        admin_accounts_status = request.query_params.get("admin_accounts_status")
        audit_actor = (request.query_params.get("audit_actor") or "").strip()
        audit_action = (request.query_params.get("audit_action") or "").strip()
        audit_target = (request.query_params.get("audit_target") or "").strip()
        audit_request_id = (request.query_params.get("audit_request_id") or "").strip()
        audit_export = ((request.query_params.get("audit_export") or "").strip().lower() == "csv")
        audit_limit_raw = (request.query_params.get("audit_limit") or "120").strip()
        try:
            audit_limit = int(audit_limit_raw)
        except ValueError:
            audit_limit = 120
        audit_limit = max(20, min(audit_limit, 1000))
        support_tickets_status = request.query_params.get("support_tickets_status")
        support_ticket_open = request.query_params.get("support_ticket_open", "").strip()
        support_ticket_filter = (request.query_params.get("support_ticket_filter", "open") or "open").strip().lower()
        if support_ticket_filter not in {"all", "open", "in_progress", "closed"}:
            support_ticket_filter = "open"
        overview_window = (request.query_params.get("overview_window", "7d") or "7d").strip().lower()
        if overview_window not in OVERVIEW_WINDOWS_HOURS:
            overview_window = "7d"
        overview_since = datetime.now(timezone.utc) - timedelta(hours=OVERVIEW_WINDOWS_HOURS[overview_window])
        search_query_raw = (request.query_params.get("search_query") or "").strip()
        search_kind = _normalize_search_kind(request.query_params.get("search_kind"))
        search_query, search_kind = _parse_search_query(search_query_raw, search_kind)
        search_query_id = int(search_query) if search_query.isdigit() else None
        search_query_input = search_query_raw
        error_service_raw = request.query_params.get("error_service", "safaruz-backend")
        error_lines_raw = request.query_params.get("error_lines", "300")
        lookup_user: User | None = None
        lookup_user_stats: dict[str, object] | None = None
        lookup_error: str | None = None
        driver_access_user: User | None = None
        driver_access_error: str | None = None
        admin_accounts: list[AdminCredential] = []
        admin_accounts_error: str | None = None
        admin_audit_logs: list[AdminAuditLog] = []
        support_tickets: list[SupportTicket] = []
        support_recent_for_overview: list[SupportTicket] = []
        support_ticket_messages: dict[int, list[SupportTicketMessage]] = {}
        support_ticket_sla: dict[int, dict[str, object]] = {}
        support_sla_summary = {
            "open_total": 0,
            "waiting_support": 0,
            "waiting_user": 0,
            "escalated": 0,
            "breached": 0,
        }
        overview_kpis: dict[str, object] = {}
        overview_alerts: list[dict[str, object]] = []
        overview_activity: list[dict[str, object]] = []
        overview_action_breakdown: list[dict[str, object]] = []
        overview_action_max = 1
        search_users: list[User] = []
        search_tickets: list[SupportTicket] = []
        search_trips: list[DriverTrip] = []
        search_requests: list[PassengerRequest] = []
        search_claims: list[RequestClaim] = []
        search_audit_logs: list[AdminAuditLog] = []
        search_timeline: list[dict[str, object]] = []
        search_focus_user: User | None = None
        search_focus_stats: dict[str, object] | None = None
        search_summary = {
            "users": 0,
            "tickets": 0,
            "trips": 0,
            "requests": 0,
            "claims": 0,
            "audit_logs": 0,
            "timeline": 0,
        }
        search_error: str | None = None
        support_open_now = 0
        support_new_period = 0
        support_waiting_support = 0
        support_breached = 0
        support_first_response_avg_minutes: float | None = None
        audit_actions_period = 0
        support_tickets_error: str | None = None
        resource_metrics = _collect_resource_metrics()
        try:
            error_lines = int(error_lines_raw)
        except ValueError:
            error_lines = 300
        server_errors = _collect_server_errors(error_service_raw, lines=error_lines)

        users_total = db.scalar(select(func.count(User.id))) or 0
        drivers_total = db.scalar(select(func.count(User.id)).where(User.role == UserRole.driver)) or 0
        passengers_total = db.scalar(select(func.count(User.id)).where(User.role == UserRole.passenger)) or 0
        trips_total = db.scalar(select(func.count(DriverTrip.id))) or 0
        requests_total = db.scalar(select(func.count(PassengerRequest.id))) or 0
        claims_total = db.scalar(select(func.count(RequestClaim.id))) or 0
        chats_total = db.scalar(select(func.count(Chat.id))) or 0
        messages_total = db.scalar(select(func.count(ChatMessage.id))) or 0
        ratings_total = db.scalar(select(func.count(TripRating.id))) or 0
        blocked_drivers_total = db.scalar(select(func.count(User.id)).where(User.driver_blocked.is_(True))) or 0
        users_without_password_total = db.scalar(select(func.count(User.id)).where(User.password_hash.is_(None))) or 0
        users_new_period = db.scalar(select(func.count(User.id)).where(User.created_at >= overview_since)) or 0
        trips_new_period = db.scalar(select(func.count(DriverTrip.id)).where(DriverTrip.created_at >= overview_since)) or 0
        trips_done_period = db.scalar(
            select(func.count(DriverTrip.id)).where(
                DriverTrip.status == TripStatus.done,
                DriverTrip.start_time >= overview_since,
            )
        ) or 0
        active_trips_now = db.scalar(
            select(func.count(DriverTrip.id)).where(
                DriverTrip.status.in_([TripStatus.open, TripStatus.full]),
            )
        ) or 0
        avg_trip_fill_pct_raw = db.scalar(
            select(
                func.avg(
                    (DriverTrip.seats_taken * 100.0) / func.nullif(DriverTrip.seats_total, 0)
                )
            ).where(DriverTrip.status.in_([TripStatus.open, TripStatus.full, TripStatus.done]))
        )
        requests_new_period = db.scalar(
            select(func.count(PassengerRequest.id)).where(PassengerRequest.created_at >= overview_since)
        ) or 0
        requests_active_now = db.scalar(
            select(func.count(PassengerRequest.id)).where(
                PassengerRequest.status.in_([RequestStatus.open, RequestStatus.locked, RequestStatus.chosen]),
            )
        ) or 0
        claims_period_total = db.scalar(
            select(func.count(RequestClaim.id)).where(RequestClaim.created_at >= overview_since)
        ) or 0
        claims_period_accepted = db.scalar(
            select(func.count(RequestClaim.id)).where(
                RequestClaim.created_at >= overview_since,
                RequestClaim.status.in_([ClaimStatus.accepted, ClaimStatus.completed]),
            )
        ) or 0
        messages_period = db.scalar(
            select(func.count(ChatMessage.id)).where(ChatMessage.created_at >= overview_since)
        ) or 0
        notifications_unread_total = db.scalar(
            select(func.count(UserNotification.id)).where(UserNotification.is_read.is_(False))
        ) or 0
        notifications_period = db.scalar(
            select(func.count(UserNotification.id)).where(UserNotification.created_at >= overview_since)
        ) or 0

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
                    avg_given = db.scalar(
                        select(func.avg(TripRating.stars)).where(
                            TripRating.passenger_id == lookup_user.id
                        )
                    )
                    avg_received = db.scalar(
                        select(func.avg(TripRating.stars)).where(
                            TripRating.driver_id == lookup_user.id
                        )
                    )
                    lookup_user_stats = {
                        "driver_trips_total": db.scalar(
                            select(func.count(DriverTrip.id)).where(
                                DriverTrip.driver_id == lookup_user.id
                            )
                        )
                        or 0,
                        "driver_trips_active": db.scalar(
                            select(func.count(DriverTrip.id)).where(
                                DriverTrip.driver_id == lookup_user.id,
                                DriverTrip.status.in_([TripStatus.open, TripStatus.full]),
                            )
                        )
                        or 0,
                        "driver_trips_done": db.scalar(
                            select(func.count(DriverTrip.id)).where(
                                DriverTrip.driver_id == lookup_user.id,
                                DriverTrip.status == TripStatus.done,
                            )
                        )
                        or 0,
                        "passenger_requests": db.scalar(
                            select(func.count(PassengerRequest.id)).where(
                                PassengerRequest.passenger_id == lookup_user.id
                            )
                        )
                        or 0,
                        "passenger_requests_active": db.scalar(
                            select(func.count(PassengerRequest.id)).where(
                                PassengerRequest.passenger_id == lookup_user.id,
                                PassengerRequest.status.in_(
                                    [
                                        RequestStatus.open,
                                        RequestStatus.locked,
                                        RequestStatus.chosen,
                                    ]
                                ),
                            )
                        )
                        or 0,
                        "claims_total": db.scalar(
                            select(func.count(RequestClaim.id)).where(
                                RequestClaim.driver_id == lookup_user.id
                            )
                        )
                        or 0,
                        "claims_pending": db.scalar(
                            select(func.count(RequestClaim.id)).where(
                                RequestClaim.driver_id == lookup_user.id,
                                RequestClaim.status == ClaimStatus.pending,
                            )
                        )
                        or 0,
                        "claims_accepted": db.scalar(
                            select(func.count(RequestClaim.id)).where(
                                RequestClaim.driver_id == lookup_user.id,
                                RequestClaim.status == ClaimStatus.accepted,
                            )
                        )
                        or 0,
                        "claims_rejected": db.scalar(
                            select(func.count(RequestClaim.id)).where(
                                RequestClaim.driver_id == lookup_user.id,
                                RequestClaim.status == ClaimStatus.rejected,
                            )
                        )
                        or 0,
                        "claims_completed": db.scalar(
                            select(func.count(RequestClaim.id)).where(
                                RequestClaim.driver_id == lookup_user.id,
                                RequestClaim.status == ClaimStatus.completed,
                            )
                        )
                        or 0,
                        "given_ratings": db.scalar(
                            select(func.count(TripRating.id)).where(
                                TripRating.passenger_id == lookup_user.id
                            )
                        )
                        or 0,
                        "given_ratings_avg": round(float(avg_given), 2)
                        if avg_given is not None
                        else 0.0,
                        "received_ratings": db.scalar(
                            select(func.count(TripRating.id)).where(
                                TripRating.driver_id == lookup_user.id
                            )
                        )
                        or 0,
                        "received_ratings_avg": round(float(avg_received), 2)
                        if avg_received is not None
                        else 0.0,
                        "chats_as_driver": db.scalar(
                            select(func.count(Chat.id)).where(
                                Chat.driver_id == lookup_user.id
                            )
                        )
                        or 0,
                        "chats_as_passenger": db.scalar(
                            select(func.count(Chat.id)).where(
                                Chat.passenger_id == lookup_user.id
                            )
                        )
                        or 0,
                        "messages_sent": db.scalar(
                            select(func.count(ChatMessage.id)).where(
                                ChatMessage.sender_id == lookup_user.id
                            )
                        )
                        or 0,
                        "notifications_total": db.scalar(
                            select(func.count(UserNotification.id)).where(
                                UserNotification.user_id == lookup_user.id
                            )
                        )
                        or 0,
                        "notifications_unread": db.scalar(
                            select(func.count(UserNotification.id)).where(
                                UserNotification.user_id == lookup_user.id,
                                UserNotification.is_read.is_(False),
                            )
                        )
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

        if _can_access_tab(admin_role, "admin_accounts"):
            try:
                admin_accounts = db.scalars(
                    select(AdminCredential).order_by(AdminCredential.created_at.desc())
                ).all()
                audit_stmt = select(AdminAuditLog).order_by(AdminAuditLog.created_at.desc())
                if audit_actor:
                    audit_stmt = audit_stmt.where(AdminAuditLog.actor_username.ilike(f"%{audit_actor}%"))
                if audit_action:
                    audit_stmt = audit_stmt.where(AdminAuditLog.action.ilike(f"%{audit_action}%"))
                if audit_target:
                    audit_stmt = audit_stmt.where(AdminAuditLog.target_username.ilike(f"%{audit_target}%"))
                if audit_request_id:
                    audit_stmt = audit_stmt.where(AdminAuditLog.request_id.ilike(f"%{audit_request_id}%"))
                admin_audit_logs = db.scalars(audit_stmt.limit(audit_limit)).all()
                audit_actions_period = db.scalar(
                    select(func.count(AdminAuditLog.id)).where(AdminAuditLog.created_at >= overview_since)
                ) or 0
                action_rows = db.execute(
                    select(
                        AdminAuditLog.action,
                        func.count(AdminAuditLog.id).label("action_count"),
                    )
                    .where(AdminAuditLog.created_at >= overview_since)
                    .group_by(AdminAuditLog.action)
                    .order_by(func.count(AdminAuditLog.id).desc())
                    .limit(6)
                ).all()
                overview_action_breakdown = [
                    {"action": row[0], "count": int(row[1] or 0)}
                    for row in action_rows
                ]
                if overview_action_breakdown:
                    overview_action_max = max(r["count"] for r in overview_action_breakdown) or 1
            except SQLAlchemyError:
                admin_accounts = []
                admin_audit_logs = []
                admin_accounts_error = "DB sxemasi eski. `alembic upgrade head` ishlating."

        if _can_access_tab(admin_role, "support_tickets"):
            try:
                auto_close_stale_tickets(db)
                tickets_stmt = select(SupportTicket).order_by(SupportTicket.created_at.desc())
                if support_ticket_filter != "all":
                    tickets_stmt = tickets_stmt.where(SupportTicket.status == support_ticket_filter)
                support_tickets = db.scalars(tickets_stmt.limit(300)).all()
                support_open_now = db.scalar(
                    select(func.count(SupportTicket.id)).where(
                        SupportTicket.status.in_([TICKET_STATUS_OPEN, TICKET_STATUS_IN_PROGRESS]),
                    )
                ) or 0
                support_new_period = db.scalar(
                    select(func.count(SupportTicket.id)).where(SupportTicket.created_at >= overview_since)
                ) or 0
                support_recent_for_overview = db.scalars(
                    select(SupportTicket).order_by(SupportTicket.created_at.desc()).limit(6)
                ).all()
                support_waiting_support = db.scalar(
                    select(func.count(SupportTicket.id)).where(
                        SupportTicket.status.in_([TICKET_STATUS_OPEN, TICKET_STATUS_IN_PROGRESS]),
                        SupportTicket.last_actor != SENDER_SUPPORT,
                    )
                ) or 0
                support_breached = db.scalar(
                    select(func.count(SupportTicket.id)).where(
                        SupportTicket.status.in_([TICKET_STATUS_OPEN, TICKET_STATUS_IN_PROGRESS]),
                        SupportTicket.last_actor == SENDER_SUPPORT,
                        SupportTicket.last_activity_at
                        < datetime.now(timezone.utc) - timedelta(hours=SUPPORT_TICKET_AUTO_CLOSE_HOURS),
                    )
                ) or 0
                period_ticket_rows = db.execute(
                    select(SupportTicket.id, SupportTicket.created_at)
                    .where(SupportTicket.created_at >= overview_since)
                    .order_by(SupportTicket.created_at.desc())
                    .limit(500)
                ).all()
                if period_ticket_rows:
                    period_ticket_created = {int(row[0]): row[1] for row in period_ticket_rows}
                    support_period_msgs = db.scalars(
                        select(SupportTicketMessage)
                        .where(
                            SupportTicketMessage.ticket_id.in_(list(period_ticket_created.keys())),
                            SupportTicketMessage.sender_role == SENDER_SUPPORT,
                        )
                        .order_by(
                            SupportTicketMessage.ticket_id.asc(),
                            SupportTicketMessage.created_at.asc(),
                        )
                    ).all()
                    first_response_at: dict[int, datetime] = {}
                    for msg in support_period_msgs:
                        if msg.ticket_id not in first_response_at:
                            first_response_at[msg.ticket_id] = msg.created_at
                    response_minutes = [
                        max(
                            0.0,
                            (
                                first_response_at[ticket_id]
                                - period_ticket_created[ticket_id]
                            ).total_seconds()
                            / 60.0,
                        )
                        for ticket_id in first_response_at
                    ]
                    if response_minutes:
                        support_first_response_avg_minutes = round(
                            sum(response_minutes) / len(response_minutes), 1
                        )
                ticket_ids = [t.id for t in support_tickets]
                if ticket_ids:
                    message_rows = db.scalars(
                        select(SupportTicketMessage)
                        .where(SupportTicketMessage.ticket_id.in_(ticket_ids))
                        .order_by(
                            SupportTicketMessage.ticket_id.asc(),
                            SupportTicketMessage.created_at.asc(),
                        )
                    ).all()
                    for row in message_rows:
                        support_ticket_messages.setdefault(row.ticket_id, []).append(row)

                now_utc = datetime.now(timezone.utc)
                for ticket in support_tickets:
                    is_open = ticket.status in {TICKET_STATUS_OPEN, TICKET_STATUS_IN_PROGRESS}
                    waiting_on = "none"
                    if is_open:
                        if ticket.last_actor == SENDER_SUPPORT:
                            waiting_on = "user"
                        else:
                            waiting_on = "support"
                    pending_minutes = max(0, int((now_utc - ticket.last_activity_at).total_seconds() // 60))
                    age_minutes = max(0, int((now_utc - ticket.created_at).total_seconds() // 60))
                    auto_close_deadline = None
                    auto_close_minutes_left = None
                    breached = False
                    if is_open and ticket.last_actor == SENDER_SUPPORT:
                        auto_close_deadline = ticket.last_activity_at + timedelta(hours=SUPPORT_TICKET_AUTO_CLOSE_HOURS)
                        auto_close_minutes_left = int((auto_close_deadline - now_utc).total_seconds() // 60)
                        breached = auto_close_minutes_left <= 0

                    escalated = waiting_on == "support" and pending_minutes >= SUPPORT_TICKET_ESCALATE_MINUTES
                    support_ticket_sla[ticket.id] = {
                        "waiting_on": waiting_on,
                        "pending_minutes": pending_minutes,
                        "age_minutes": age_minutes,
                        "auto_close_deadline": auto_close_deadline,
                        "auto_close_minutes_left": auto_close_minutes_left,
                        "breached": breached,
                        "escalated": escalated,
                    }
                    if is_open:
                        support_sla_summary["open_total"] += 1
                    if waiting_on == "support":
                        support_sla_summary["waiting_support"] += 1
                    if waiting_on == "user":
                        support_sla_summary["waiting_user"] += 1
                    if escalated:
                        support_sla_summary["escalated"] += 1
                    if breached:
                        support_sla_summary["breached"] += 1

                support_tickets.sort(
                    key=lambda ticket: (
                        0 if support_ticket_sla.get(ticket.id, {}).get("breached") else 1,
                        0 if support_ticket_sla.get(ticket.id, {}).get("escalated") else 1,
                        0 if support_ticket_sla.get(ticket.id, {}).get("waiting_on") == "support" else 1,
                        support_ticket_sla.get(ticket.id, {}).get("pending_minutes", 0) * -1,
                        ticket.id * -1,
                    )
                )
            except SQLAlchemyError:
                support_tickets = []
                support_recent_for_overview = []
                support_ticket_messages = {}
                support_ticket_sla = {}
                support_tickets_error = "DB sxemasi eski. `alembic upgrade head` ishlating."

        if _can_access_tab(admin_role, "search360"):
            try:
                if search_query:
                    q_like = f"%{search_query}%"

                    if search_kind in {"all", "user"}:
                        user_filters = [
                            User.phone.ilike(q_like),
                            User.name.ilike(q_like),
                            User.first_name.ilike(q_like),
                            User.last_name.ilike(q_like),
                        ]
                        if search_query_id is not None:
                            user_filters.insert(0, User.id == search_query_id)
                        search_users = db.scalars(
                            select(User)
                            .where(or_(*user_filters))
                            .order_by(User.created_at.desc())
                            .limit(20)
                        ).all()

                    if search_kind in {"all", "ticket"}:
                        ticket_filters = [
                            SupportTicket.phone.ilike(q_like),
                            SupportTicket.telegram_chat_id.ilike(q_like),
                            SupportTicket.telegram_username.ilike(q_like),
                            SupportTicket.subject.ilike(q_like),
                            SupportTicket.message.ilike(q_like),
                            SupportTicket.context_summary.ilike(q_like),
                        ]
                        if search_query_id is not None:
                            ticket_filters.extend(
                                [
                                    SupportTicket.id == search_query_id,
                                    SupportTicket.user_id == search_query_id,
                                ]
                            )
                        search_tickets = db.scalars(
                            select(SupportTicket)
                            .where(or_(*ticket_filters))
                            .order_by(SupportTicket.created_at.desc())
                            .limit(30)
                        ).all()

                    if search_kind in {"all", "trip"}:
                        trip_filters = [
                            DriverTrip.from_location.ilike(q_like),
                            DriverTrip.to_location.ilike(q_like),
                        ]
                        if search_query_id is not None:
                            trip_filters.extend(
                                [
                                    DriverTrip.id == search_query_id,
                                    DriverTrip.driver_id == search_query_id,
                                ]
                            )
                        search_trips = db.scalars(
                            select(DriverTrip)
                            .where(or_(*trip_filters))
                            .order_by(DriverTrip.start_time.desc())
                            .limit(30)
                        ).all()

                    if search_kind in {"all", "request"}:
                        request_filters = [
                            PassengerRequest.from_location.ilike(q_like),
                            PassengerRequest.to_location.ilike(q_like),
                        ]
                        if search_query_id is not None:
                            request_filters.extend(
                                [
                                    PassengerRequest.id == search_query_id,
                                    PassengerRequest.passenger_id == search_query_id,
                                ]
                            )
                        search_requests = db.scalars(
                            select(PassengerRequest)
                            .where(or_(*request_filters))
                            .order_by(PassengerRequest.created_at.desc())
                            .limit(30)
                        ).all()

                    if search_kind in {"all", "claim"}:
                        claim_filters = []
                        if search_query_id is not None:
                            claim_filters.extend(
                                [
                                    RequestClaim.id == search_query_id,
                                    RequestClaim.driver_id == search_query_id,
                                    RequestClaim.request_id == search_query_id,
                                    RequestClaim.trip_id == search_query_id,
                                ]
                            )
                        if claim_filters:
                            search_claims = db.scalars(
                                select(RequestClaim)
                                .where(or_(*claim_filters))
                                .order_by(RequestClaim.created_at.desc())
                                .limit(30)
                            ).all()

                    if search_kind in {"all", "audit"}:
                        audit_filters = [
                            AdminAuditLog.actor_username.ilike(q_like),
                            AdminAuditLog.action.ilike(q_like),
                            AdminAuditLog.target_username.ilike(q_like),
                            AdminAuditLog.details.ilike(q_like),
                            AdminAuditLog.request_id.ilike(q_like),
                        ]
                        search_audit_logs = db.scalars(
                            select(AdminAuditLog)
                            .where(or_(*audit_filters))
                            .order_by(AdminAuditLog.created_at.desc())
                            .limit(30)
                        ).all()

                    if search_users:
                        search_focus_user = search_users[0]
                    elif search_query_id is not None:
                        search_focus_user = db.scalar(select(User).where(User.id == search_query_id))
                    elif search_tickets:
                        first_ticket_uid = next(
                            (t.user_id for t in search_tickets if t.user_id is not None),
                            None,
                        )
                        if first_ticket_uid is not None:
                            search_focus_user = db.scalar(select(User).where(User.id == first_ticket_uid))

                    if search_focus_user is not None:
                        focus_user_id = search_focus_user.id
                        focus_tickets_open = db.scalar(
                            select(func.count(SupportTicket.id)).where(
                                SupportTicket.user_id == focus_user_id,
                                SupportTicket.status.in_([TICKET_STATUS_OPEN, TICKET_STATUS_IN_PROGRESS]),
                            )
                        ) or 0
                        focus_tickets_total = db.scalar(
                            select(func.count(SupportTicket.id)).where(SupportTicket.user_id == focus_user_id)
                        ) or 0
                        focus_notifications_unread = db.scalar(
                            select(func.count(UserNotification.id)).where(
                                UserNotification.user_id == focus_user_id,
                                UserNotification.is_read.is_(False),
                            )
                        ) or 0
                        focus_driver_trips = db.scalar(
                            select(func.count(DriverTrip.id)).where(DriverTrip.driver_id == focus_user_id)
                        ) or 0
                        focus_passenger_requests = db.scalar(
                            select(func.count(PassengerRequest.id)).where(PassengerRequest.passenger_id == focus_user_id)
                        ) or 0
                        focus_claims = db.scalar(
                            select(func.count(RequestClaim.id)).where(RequestClaim.driver_id == focus_user_id)
                        ) or 0
                        search_focus_stats = {
                            "support_open": focus_tickets_open,
                            "support_total": focus_tickets_total,
                            "notifications_unread": focus_notifications_unread,
                            "driver_trips": focus_driver_trips,
                            "passenger_requests": focus_passenger_requests,
                            "claims_as_driver": focus_claims,
                            "driver_blocked": search_focus_user.driver_blocked,
                            "role": search_focus_user.role.value if search_focus_user.role else "-",
                            "password_set": bool(search_focus_user.password_hash),
                        }

                        focus_recent_requests = db.scalars(
                            select(PassengerRequest)
                            .where(PassengerRequest.passenger_id == focus_user_id)
                            .order_by(PassengerRequest.created_at.desc())
                            .limit(10)
                        ).all()
                        for req in focus_recent_requests:
                            search_timeline.append(
                                {
                                    "at": req.created_at,
                                    "kind": "request",
                                    "title": f"Request #{req.id} ({req.status.value})",
                                    "meta": f"{req.from_location} -> {req.to_location}, seats={req.seats_needed}",
                                }
                            )

                        focus_recent_trips = db.scalars(
                            select(DriverTrip)
                            .where(DriverTrip.driver_id == focus_user_id)
                            .order_by(DriverTrip.start_time.desc())
                            .limit(10)
                        ).all()
                        for trip in focus_recent_trips:
                            search_timeline.append(
                                {
                                    "at": trip.start_time,
                                    "kind": "trip",
                                    "title": f"Trip #{trip.id} ({trip.status.value})",
                                    "meta": f"{trip.from_location} -> {trip.to_location}, {trip.seats_taken}/{trip.seats_total}",
                                }
                            )

                        focus_recent_tickets = db.scalars(
                            select(SupportTicket)
                            .where(SupportTicket.user_id == focus_user_id)
                            .order_by(SupportTicket.created_at.desc())
                            .limit(10)
                        ).all()
                        for ticket in focus_recent_tickets:
                            search_timeline.append(
                                {
                                    "at": ticket.created_at,
                                    "kind": "support",
                                    "title": f"Ticket #{ticket.id} ({ticket.status})",
                                    "meta": f"source={ticket.source}, last_actor={ticket.last_actor}",
                                }
                            )

                    for row in search_users:
                        search_timeline.append(
                            {
                                "at": row.created_at,
                                "kind": "user",
                                "title": f"User #{row.id}",
                                "meta": f"{row.phone}, role={row.role.value}",
                            }
                        )
                    for row in search_tickets:
                        search_timeline.append(
                            {
                                "at": row.created_at,
                                "kind": "ticket",
                                "title": f"Ticket #{row.id} ({row.status})",
                                "meta": f"user={row.user_id or '-'}, phone={row.phone or '-'}",
                            }
                        )
                    for row in search_trips:
                        search_timeline.append(
                            {
                                "at": row.start_time,
                                "kind": "trip",
                                "title": f"Trip #{row.id} ({row.status.value})",
                                "meta": f"driver={row.driver_id}, {row.from_location} -> {row.to_location}",
                            }
                        )
                    for row in search_requests:
                        search_timeline.append(
                            {
                                "at": row.created_at,
                                "kind": "request",
                                "title": f"Request #{row.id} ({row.status.value})",
                                "meta": f"passenger={row.passenger_id}, {row.from_location} -> {row.to_location}",
                            }
                        )
                    for row in search_claims:
                        search_timeline.append(
                            {
                                "at": row.created_at,
                                "kind": "claim",
                                "title": f"Claim #{row.id} ({row.status.value})",
                                "meta": f"trip={row.trip_id}, request={row.request_id}, driver={row.driver_id}",
                            }
                        )
                    for row in search_audit_logs:
                        search_timeline.append(
                            {
                                "at": row.created_at,
                                "kind": "audit",
                                "title": f"Audit: {row.action}",
                                "meta": f"actor={row.actor_username}, target={row.target_username or '-'}",
                            }
                        )

                    search_timeline.sort(
                        key=lambda row: row.get("at") or datetime.fromtimestamp(0, tz=timezone.utc),
                        reverse=True,
                    )
                    search_timeline = search_timeline[:120]
                    search_summary = {
                        "users": len(search_users),
                        "tickets": len(search_tickets),
                        "trips": len(search_trips),
                        "requests": len(search_requests),
                        "claims": len(search_claims),
                        "audit_logs": len(search_audit_logs),
                        "timeline": len(search_timeline),
                    }
                elif tab == "search360":
                    search_error = "Qidiruv uchun kamida 1 ta so'z kiriting."
            except SQLAlchemyError:
                search_error = "Qidiruvda DB xatoligi yuz berdi. Jurnalni tekshiring."

        claim_acceptance_rate = (
            round((claims_period_accepted / claims_period_total) * 100.0, 1)
            if claims_period_total > 0
            else 0.0
        )
        avg_trip_fill_pct = round(float(avg_trip_fill_pct_raw), 1) if avg_trip_fill_pct_raw is not None else 0.0
        support_visible = _can_access_tab(admin_role, "support_tickets")
        overview_kpis = {
            "window_key": overview_window,
            "window_label": OVERVIEW_WINDOW_LABELS.get(overview_window, overview_window),
            "users_new": users_new_period,
            "trips_new": trips_new_period,
            "trips_done": trips_done_period,
            "active_trips": active_trips_now,
            "requests_new": requests_new_period,
            "requests_active": requests_active_now,
            "claims_period_total": claims_period_total,
            "claim_acceptance_rate": claim_acceptance_rate,
            "messages_period": messages_period,
            "notifications_period": notifications_period,
            "notifications_unread": notifications_unread_total,
            "avg_trip_fill_pct": avg_trip_fill_pct,
            "blocked_drivers_total": blocked_drivers_total,
            "users_without_password_total": users_without_password_total,
            "support_visible": support_visible,
            "support_open_now": support_open_now,
            "support_new_period": support_new_period,
            "support_waiting_support": support_waiting_support,
            "support_breached": support_breached,
            "support_first_response_avg_minutes": support_first_response_avg_minutes,
            "audit_actions_period": audit_actions_period,
        }

        if support_visible and support_breached > 0:
            overview_alerts.append(
                {
                    "level": "danger",
                    "title": "Support breach",
                    "value": support_breached,
                    "hint": "24 soat oynasidan oshgan ochiq/in_progress ticketlar bor.",
                }
            )
        if support_visible and support_waiting_support > 0:
            overview_alerts.append(
                {
                    "level": "warn",
                    "title": "Support navbati",
                    "value": support_waiting_support,
                    "hint": "Support javobini kutayotgan ticketlar.",
                }
            )
        if blocked_drivers_total > 0:
            overview_alerts.append(
                {
                    "level": "warn",
                    "title": "Bloklangan haydovchilar",
                    "value": blocked_drivers_total,
                    "hint": "Driver access tekshiruvini va appeal oqimini ko'rib chiqing.",
                }
            )
        if users_without_password_total > 0:
            overview_alerts.append(
                {
                    "level": "info",
                    "title": "Parolsiz userlar",
                    "value": users_without_password_total,
                    "hint": "Eski userlar uchun password onboarding kampaniyasi kerak bo'lishi mumkin.",
                }
            )
        server_error_count = int(server_errors.get("error_count", 0)) if server_errors.get("available") else 0
        if server_error_count > 0:
            overview_alerts.append(
                {
                    "level": "danger",
                    "title": "Server xatoliklari",
                    "value": server_error_count,
                    "hint": "Errors tabdan so'nggi stack trace'larni tekshiring.",
                }
            )
        if not overview_alerts:
            overview_alerts.append(
                {
                    "level": "ok",
                    "title": "Stable",
                    "value": "OK",
                    "hint": "Hozircha kritik alert kuzatilmadi.",
                }
            )

        for user in recent_users[:5]:
            overview_activity.append(
                {
                    "at": user.created_at,
                    "kind": "new_user",
                    "title": f"Yangi user #{user.id}",
                    "meta": f"{user.phone} | role={user.role.value}",
                }
            )

        recent_done_trips = db.scalars(
            select(DriverTrip)
            .where(DriverTrip.status == TripStatus.done)
            .order_by(DriverTrip.start_time.desc())
            .limit(6)
        ).all()
        for trip in recent_done_trips:
            overview_activity.append(
                {
                    "at": trip.start_time,
                    "kind": "trip_done",
                    "title": f"Trip #{trip.id} yakunlandi",
                    "meta": f"{trip.from_location} -> {trip.to_location}",
                }
            )

        if support_visible:
            for ticket in support_recent_for_overview[:6]:
                overview_activity.append(
                    {
                        "at": ticket.created_at,
                        "kind": "support_ticket",
                        "title": f"Support ticket #{ticket.id}",
                        "meta": f"status={ticket.status}, user={ticket.user_id or '-'}",
                    }
                )

        if _can_access_tab(admin_role, "admin_accounts"):
            for log in admin_audit_logs[:6]:
                overview_activity.append(
                    {
                        "at": log.created_at,
                        "kind": "admin_action",
                        "title": f"Admin action: {log.action}",
                        "meta": f"actor={log.actor_username}, target={log.target_username or '-'}",
                    }
                )

        overview_activity.sort(
            key=lambda row: row.get("at") or datetime.fromtimestamp(0, tz=timezone.utc),
            reverse=True,
        )
        overview_activity = overview_activity[:16]
    finally:
        db.close()

    if tab == "admin_accounts" and audit_export and _can_access_tab(admin_role, "admin_accounts"):
        buffer = io.StringIO()
        writer = csv.writer(buffer)
        writer.writerow(
            [
                "created_at",
                "actor_username",
                "action",
                "target_username",
                "details",
                "actor_ip",
                "request_id",
                "actor_user_agent",
                "before_state",
                "after_state",
            ]
        )
        for row in admin_audit_logs:
            writer.writerow(
                [
                    row.created_at.isoformat() if row.created_at else "",
                    row.actor_username or "",
                    row.action or "",
                    row.target_username or "",
                    row.details or "",
                    row.actor_ip or "",
                    row.request_id or "",
                    row.actor_user_agent or "",
                    row.before_state or "",
                    row.after_state or "",
                ]
            )
        filename = f"admin_audit_logs_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}.csv"
        return Response(
            content=buffer.getvalue(),
            media_type="text/csv; charset=utf-8",
            headers={"Content-Disposition": f'attachment; filename="{filename}"'},
        )

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
            "overview_window": overview_window,
            "overview_window_labels": OVERVIEW_WINDOW_LABELS,
            "overview_kpis": overview_kpis,
            "overview_alerts": overview_alerts,
            "overview_activity": overview_activity,
            "overview_action_breakdown": overview_action_breakdown,
            "overview_action_max": overview_action_max,
            "search_query": search_query_input,
            "search_kind": search_kind,
            "search_summary": search_summary,
            "search_users": search_users,
            "search_tickets": search_tickets,
            "search_trips": search_trips,
            "search_requests": search_requests,
            "search_claims": search_claims,
            "search_audit_logs": search_audit_logs,
            "search_timeline": search_timeline,
            "search_focus_user": search_focus_user,
            "search_focus_stats": search_focus_stats,
            "search_error": search_error,
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
            "admin_password_status": admin_password_status or "",
            "admin_accounts_status": admin_accounts_status or "",
            "admin_accounts": admin_accounts,
            "admin_accounts_error": admin_accounts_error,
            "admin_audit_logs": admin_audit_logs,
            "audit_actor": audit_actor,
            "audit_action": audit_action,
            "audit_target": audit_target,
            "audit_request_id": audit_request_id,
            "audit_limit": audit_limit,
            "support_tickets_status": support_tickets_status or "",
            "support_ticket_filter": support_ticket_filter,
            "support_ticket_open": support_ticket_open,
            "support_tickets": support_tickets,
            "support_ticket_messages": support_ticket_messages,
            "support_ticket_sla": support_ticket_sla,
            "support_sla_summary": support_sla_summary,
            "support_saved_replies": SUPPORT_SAVED_REPLIES,
            "support_tickets_error": support_tickets_error,
            "resource_metrics": resource_metrics,
            "server_errors": server_errors,
            "error_service": error_service_raw,
            "error_lines": error_lines,
            "admin_username": admin_username,
            "admin_role": admin_role,
            "admin_role_labels": ADMIN_ROLE_LABELS,
            "tab_access": ADMIN_TAB_ACCESS.get(admin_role, set()),
            "tab_forbidden": tab_forbidden,
        },
    )


@router.post("/driver-access")
def admin_driver_access(
    request: Request,
    user_id: int = Form(...),
    action: str = Form(...),
):
    admin_session = _get_admin_session(request)
    if not admin_session:
        return RedirectResponse(url="/admin/login", status_code=302)
    if admin_session["role"] != ADMIN_ROLE_SUPERADMIN:
        return RedirectResponse(
            url=f"/admin?tab=overview",
            status_code=302,
        )

    db: Session = SessionLocal()
    try:
        user = db.scalar(select(User).where(User.id == user_id))
        if not user:
            return RedirectResponse(
                url=f"/admin?tab=driver_access&driver_access_user_id={user_id}&driver_access_status=not_found",
                status_code=302,
            )
        before_state = {
            "role": user.role.value if user.role else None,
            "driver_blocked": user.driver_blocked,
            "driver_access_override": user.driver_access_override,
            "driver_block_reason": user.driver_block_reason,
            "driver_unblocked_at": user.driver_unblocked_at.isoformat() if user.driver_unblocked_at else None,
        }

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
        _write_admin_audit_log(
            request=request,
            db=db,
            actor_username=admin_session["username"],
            action=f"driver_access_{status}",
            target_username=str(user.id),
            details=f"user_id={user.id}",
            before_state=before_state,
            after_state={
                "role": user.role.value if user.role else None,
                "driver_blocked": user.driver_blocked,
                "driver_access_override": user.driver_access_override,
                "driver_block_reason": user.driver_block_reason,
                "driver_unblocked_at": user.driver_unblocked_at.isoformat() if user.driver_unblocked_at else None,
            },
        )
        db.commit()
    finally:
        db.close()

    return RedirectResponse(
        url=f"/admin?tab=driver_access&driver_access_user_id={user_id}&driver_access_status={status}",
        status_code=302,
    )


@router.post("/support-tickets/status")
def admin_support_ticket_status(
    request: Request,
    ticket_id: int = Form(...),
    new_status: str = Form(...),
    support_ticket_filter: str = Form(default="open"),
):
    admin_session = _get_admin_session(request)
    if not admin_session:
        return RedirectResponse(url="/admin/login", status_code=302)
    if admin_session["role"] != ADMIN_ROLE_SUPERADMIN:
        return RedirectResponse(
            url="/admin?tab=overview",
            status_code=302,
        )

    normalized_status = (new_status or "").strip().lower()
    if normalized_status not in {"open", "in_progress", "closed"}:
        return RedirectResponse(
            url="/admin?tab=support_tickets&support_tickets_status=invalid_status",
            status_code=302,
        )

    normalized_filter = (support_ticket_filter or "open").strip().lower()
    if normalized_filter not in {"all", "open", "in_progress", "closed"}:
        normalized_filter = "open"

    db: Session = SessionLocal()
    try:
        ticket = db.scalar(select(SupportTicket).where(SupportTicket.id == ticket_id))
        if not ticket:
            return RedirectResponse(
                url=f"/admin?tab=support_tickets&support_ticket_filter={normalized_filter}&support_tickets_status=not_found",
                status_code=302,
            )
        before_state = {
            "status": ticket.status,
            "last_actor": ticket.last_actor,
            "last_activity_at": ticket.last_activity_at.isoformat() if ticket.last_activity_at else None,
        }
        ticket.status = normalized_status
        ticket.updated_at = datetime.now(timezone.utc)
        db.add(ticket)
        _write_admin_audit_log(
            request=request,
            db=db,
            actor_username=admin_session["username"],
            action="support_ticket_status_updated",
            target_username=str(ticket.user_id) if ticket.user_id is not None else None,
            details=f"ticket_id={ticket.id},status={normalized_status}",
            before_state=before_state,
            after_state={
                "status": ticket.status,
                "last_actor": ticket.last_actor,
                "last_activity_at": ticket.last_activity_at.isoformat() if ticket.last_activity_at else None,
            },
        )
        db.commit()
    except SQLAlchemyError:
        db.rollback()
        return RedirectResponse(
            url=f"/admin?tab=support_tickets&support_ticket_filter={normalized_filter}&support_tickets_status=db_error",
            status_code=302,
        )
    finally:
        db.close()

    return RedirectResponse(
        url=f"/admin?tab=support_tickets&support_ticket_filter={normalized_filter}&support_tickets_status=updated",
        status_code=302,
    )


@router.post("/support-tickets/reply")
def admin_support_ticket_reply(
    request: Request,
    ticket_id: int = Form(...),
    reply_text: str = Form(...),
    reply_template_key: str = Form(default=""),
    support_ticket_filter: str = Form(default="open"),
):
    admin_session = _get_admin_session(request)
    if not admin_session:
        return RedirectResponse(url="/admin/login", status_code=302)
    if admin_session["role"] not in {ADMIN_ROLE_SUPERADMIN, ADMIN_ROLE_SUPPORT}:
        return RedirectResponse(
            url="/admin?tab=overview",
            status_code=302,
        )

    normalized_filter = (support_ticket_filter or "open").strip().lower()
    if normalized_filter not in {"all", "open", "in_progress", "closed"}:
        normalized_filter = "open"

    selected_template_key = (reply_template_key or "").strip()
    text = (reply_text or "").strip()
    if not text and selected_template_key:
        text = SUPPORT_SAVED_REPLY_MAP.get(selected_template_key, "").strip()
        if not text:
            return RedirectResponse(
                url=(
                    f"/admin?tab=support_tickets&support_ticket_filter={normalized_filter}"
                    f"&support_tickets_status=invalid_reply_template&support_ticket_open={ticket_id}"
                ),
                status_code=302,
            )
    if len(text) < 1:
        return RedirectResponse(
            url=(
                f"/admin?tab=support_tickets&support_ticket_filter={normalized_filter}"
                f"&support_tickets_status=empty_reply&support_ticket_open={ticket_id}"
            ),
            status_code=302,
        )

    db: Session = SessionLocal()
    try:
        auto_close_stale_tickets(db)
        ticket = db.scalar(select(SupportTicket).where(SupportTicket.id == ticket_id))
        if not ticket:
            return RedirectResponse(
                url=f"/admin?tab=support_tickets&support_ticket_filter={normalized_filter}&support_tickets_status=not_found",
                status_code=302,
            )
        if ticket.status == TICKET_STATUS_CLOSED:
            return RedirectResponse(
                url=(
                    f"/admin?tab=support_tickets&support_ticket_filter={normalized_filter}"
                    f"&support_tickets_status=ticket_closed&support_ticket_open={ticket_id}"
                ),
                status_code=302,
            )
        if not ticket.telegram_chat_id:
            return RedirectResponse(
                url=(
                    f"/admin?tab=support_tickets&support_ticket_filter={normalized_filter}"
                    f"&support_tickets_status=no_chat&support_ticket_open={ticket_id}"
                ),
                status_code=302,
            )

        outbound = (
            "SafarUz Support javobi:\n"
            f"{text}\n\n"
            "Agar muammo hal bo'lgan bo'lsa /close deb ticketni yopishingiz mumkin."
        )
        send_bot_reply(chat_id=ticket.telegram_chat_id, text=outbound)

        before_state = {
            "status": ticket.status,
            "last_actor": ticket.last_actor,
            "last_activity_at": ticket.last_activity_at.isoformat() if ticket.last_activity_at else None,
        }
        ticket.status = TICKET_STATUS_IN_PROGRESS
        append_ticket_message(db=db, ticket=ticket, sender_role=SENDER_SUPPORT, message=text)
        _write_admin_audit_log(
            request=request,
            db=db,
            actor_username=admin_session["username"],
            action="support_ticket_reply",
            target_username=str(ticket.user_id) if ticket.user_id is not None else None,
            details=(
                f"ticket_id={ticket.id}"
                + (f",template={selected_template_key}" if selected_template_key else "")
            ),
            before_state=before_state,
            after_state={
                "status": ticket.status,
                "last_actor": ticket.last_actor,
                "last_activity_at": ticket.last_activity_at.isoformat() if ticket.last_activity_at else None,
            },
        )
        db.commit()
    except TelegramSupportError:
        db.rollback()
        return RedirectResponse(
            url=(
                f"/admin?tab=support_tickets&support_ticket_filter={normalized_filter}"
                f"&support_tickets_status=telegram_failed&support_ticket_open={ticket_id}"
            ),
            status_code=302,
        )
    except SQLAlchemyError:
        db.rollback()
        return RedirectResponse(
            url=(
                f"/admin?tab=support_tickets&support_ticket_filter={normalized_filter}"
                f"&support_tickets_status=db_error&support_ticket_open={ticket_id}"
            ),
            status_code=302,
        )
    finally:
        db.close()

    return RedirectResponse(
        url=(
            f"/admin?tab=support_tickets&support_ticket_filter={normalized_filter}"
            f"&support_tickets_status=replied&support_ticket_open={ticket_id}"
        ),
        status_code=302,
    )


@router.post("/change-password")
def admin_change_password(
    request: Request,
    current_password: str = Form(...),
    new_password: str = Form(...),
    new_password_confirm: str = Form(...),
):
    admin_session = _get_admin_session(request)
    if not admin_session:
        return RedirectResponse(url="/admin/login", status_code=302)
    admin_username = admin_session["username"]
    admin_role = admin_session["role"]

    if new_password != new_password_confirm:
        return RedirectResponse(
            url="/admin?tab=security&admin_password_status=confirm_mismatch",
            status_code=302,
        )

    try:
        normalized_new_password = _validate_admin_new_password(new_password)
    except ValueError:
        return RedirectResponse(
            url="/admin?tab=security&admin_password_status=invalid_new_password",
            status_code=302,
        )

    db: Session = SessionLocal()
    try:
        if not _admin_password_matches(db, admin_username, current_password):
            return RedirectResponse(
                url="/admin?tab=security&admin_password_status=wrong_current_password",
                status_code=302,
            )

        credential = _load_admin_credential(db, admin_username)
        had_credential = credential is not None
        now = datetime.now(timezone.utc)
        hashed = hash_password(normalized_new_password)
        if credential is None:
            credential = AdminCredential(
                username=admin_username,
                password_hash=hashed,
                role=_normalize_admin_role(admin_role),
                is_active=True,
                created_by=admin_username,
                created_at=now,
                updated_at=now,
            )
        else:
            credential.password_hash = hashed
            credential.updated_at = now
        db.add(credential)
        _write_admin_audit_log(
            request=request,
            db=db,
            actor_username=admin_username,
            action="admin_password_changed",
            target_username=admin_username,
            before_state={"credential_exists": had_credential},
            after_state={"credential_exists": True},
        )
        db.commit()
    except SQLAlchemyError:
        db.rollback()
        return RedirectResponse(
            url="/admin?tab=security&admin_password_status=db_error",
            status_code=302,
        )
    finally:
        db.close()

    return RedirectResponse(
        url="/admin?tab=security&admin_password_status=changed",
        status_code=302,
    )


@router.post("/admin-accounts/create")
def admin_create_account(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
    password_confirm: str = Form(...),
    role: str = Form(...),
):
    admin_session = _get_admin_session(request)
    if not admin_session:
        return RedirectResponse(url="/admin/login", status_code=302)
    if admin_session["role"] != ADMIN_ROLE_SUPERADMIN:
        return RedirectResponse(
            url="/admin?tab=admin_accounts&admin_accounts_status=forbidden",
            status_code=302,
        )

    try:
        normalized_username = _validate_admin_username(username)
    except ValueError:
        return RedirectResponse(
            url="/admin?tab=admin_accounts&admin_accounts_status=invalid_username",
            status_code=302,
        )

    if password != password_confirm:
        return RedirectResponse(
            url="/admin?tab=admin_accounts&admin_accounts_status=confirm_mismatch",
            status_code=302,
        )

    try:
        normalized_password = _validate_admin_new_password(password)
    except ValueError:
        return RedirectResponse(
            url="/admin?tab=admin_accounts&admin_accounts_status=invalid_password",
            status_code=302,
        )

    normalized_role = (role or "").strip().lower()
    if normalized_role not in ADMIN_ROLES:
        return RedirectResponse(
            url="/admin?tab=admin_accounts&admin_accounts_status=invalid_role",
            status_code=302,
        )

    db: Session = SessionLocal()
    try:
        existing = _load_admin_credential(db, normalized_username)
        if existing:
            return RedirectResponse(
                url="/admin?tab=admin_accounts&admin_accounts_status=exists",
                status_code=302,
            )

        now = datetime.now(timezone.utc)
        account = AdminCredential(
            username=normalized_username,
            password_hash=hash_password(normalized_password),
            role=normalized_role,
            is_active=True,
            created_by=admin_session["username"],
            created_at=now,
            updated_at=now,
        )
        db.add(account)
        _write_admin_audit_log(
            request=request,
            db=db,
            actor_username=admin_session["username"],
            action="admin_account_created",
            target_username=normalized_username,
            details=f"role={normalized_role}",
            after_state={"role": normalized_role, "is_active": True},
        )
        db.commit()
    except SQLAlchemyError:
        db.rollback()
        return RedirectResponse(
            url="/admin?tab=admin_accounts&admin_accounts_status=db_error",
            status_code=302,
        )
    finally:
        db.close()

    return RedirectResponse(
        url="/admin?tab=admin_accounts&admin_accounts_status=created",
        status_code=302,
    )


@router.post("/admin-accounts/toggle-active")
def admin_toggle_account_active(
    request: Request,
    username: str = Form(...),
):
    admin_session = _get_admin_session(request)
    if not admin_session:
        return RedirectResponse(url="/admin/login", status_code=302)
    if admin_session["role"] != ADMIN_ROLE_SUPERADMIN:
        return RedirectResponse(
            url="/admin?tab=admin_accounts&admin_accounts_status=forbidden",
            status_code=302,
        )

    normalized_username = (username or "").strip()
    db: Session = SessionLocal()
    try:
        account = _load_admin_credential(db, normalized_username)
        if not account:
            return RedirectResponse(
                url="/admin?tab=admin_accounts&admin_accounts_status=toggle_not_found",
                status_code=302,
            )

        if normalized_username == admin_session["username"] and account.is_active:
            return RedirectResponse(
                url="/admin?tab=admin_accounts&admin_accounts_status=toggle_self_forbidden",
                status_code=302,
            )

        account.is_active = not account.is_active
        account.updated_at = datetime.now(timezone.utc)
        db.add(account)
        _write_admin_audit_log(
            request=request,
            db=db,
            actor_username=admin_session["username"],
            action="admin_account_toggled",
            target_username=normalized_username,
            details=f"is_active={account.is_active}",
            before_state={"is_active": not account.is_active},
            after_state={"is_active": account.is_active},
        )
        db.commit()
        status = "toggle_active" if account.is_active else "toggle_inactive"
    except SQLAlchemyError:
        db.rollback()
        return RedirectResponse(
            url="/admin?tab=admin_accounts&admin_accounts_status=db_error",
            status_code=302,
        )
    finally:
        db.close()

    return RedirectResponse(
        url=f"/admin?tab=admin_accounts&admin_accounts_status={status}",
        status_code=302,
    )


@router.post("/admin-accounts/reset-password")
def admin_reset_account_password(
    request: Request,
    username: str = Form(...),
    new_password: str = Form(...),
    new_password_confirm: str = Form(...),
):
    admin_session = _get_admin_session(request)
    if not admin_session:
        return RedirectResponse(url="/admin/login", status_code=302)
    if admin_session["role"] != ADMIN_ROLE_SUPERADMIN:
        return RedirectResponse(
            url="/admin?tab=admin_accounts&admin_accounts_status=forbidden",
            status_code=302,
        )

    normalized_username = (username or "").strip()
    if new_password != new_password_confirm:
        return RedirectResponse(
            url="/admin?tab=admin_accounts&admin_accounts_status=reset_confirm_mismatch",
            status_code=302,
        )
    try:
        normalized_password = _validate_admin_new_password(new_password)
    except ValueError:
        return RedirectResponse(
            url="/admin?tab=admin_accounts&admin_accounts_status=reset_invalid_password",
            status_code=302,
        )

    db: Session = SessionLocal()
    try:
        account = _load_admin_credential(db, normalized_username)
        if not account:
            return RedirectResponse(
                url="/admin?tab=admin_accounts&admin_accounts_status=reset_not_found",
                status_code=302,
            )

        account.password_hash = hash_password(normalized_password)
        account.updated_at = datetime.now(timezone.utc)
        db.add(account)
        _write_admin_audit_log(
            request=request,
            db=db,
            actor_username=admin_session["username"],
            action="admin_account_password_reset",
            target_username=normalized_username,
            before_state={"password_changed": False},
            after_state={"password_changed": True},
        )
        db.commit()
    except SQLAlchemyError:
        db.rollback()
        return RedirectResponse(
            url="/admin?tab=admin_accounts&admin_accounts_status=db_error",
            status_code=302,
        )
    finally:
        db.close()

    return RedirectResponse(
        url="/admin?tab=admin_accounts&admin_accounts_status=reset_ok",
        status_code=302,
    )
