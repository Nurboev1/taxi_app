import json
import logging
import os
from urllib import request
from urllib.error import HTTPError, URLError

from app.core.settings import settings

logger = logging.getLogger(__name__)


def _normalize_data(data: dict[str, str] | None) -> dict[str, str]:
    if not data:
        return {}
    return {str(k): str(v) for k, v in data.items()}


def _send_fcm_legacy(
    *,
    token: str,
    title: str,
    body: str | None = None,
    data: dict[str, str] | None = None,
) -> bool:
    server_key = settings.fcm_server_key.strip()
    if not server_key:
        return False

    payload: dict[str, object] = {
        "to": token,
        "priority": "high",
        "notification": {
            "title": title,
            "body": body or "",
            "sound": "default",
        },
        "data": _normalize_data(data),
    }

    req = request.Request(
        "https://fcm.googleapis.com/fcm/send",
        method="POST",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"key={server_key}",
        },
    )
    try:
        with request.urlopen(req, timeout=6) as resp:
            status = int(resp.status)
            raw = resp.read().decode("utf-8", errors="ignore")
            if not (200 <= status < 300):
                logger.error("FCM HTTP status error: %s body=%s", status, raw)
                return False
            try:
                payload = json.loads(raw) if raw else {}
            except json.JSONDecodeError:
                payload = {}
            success = int(payload.get("success", 0))
            failure = int(payload.get("failure", 0))
            if success > 0:
                return True
            if failure > 0:
                logger.error("FCM delivery failed: body=%s", raw)
            return False
    except HTTPError as e:
        body = e.read().decode("utf-8", errors="ignore")
        logger.error("FCM HTTP error: status=%s body=%s", e.code, body)
        return False
    except URLError as e:
        logger.error("FCM URL error: %s", e)
        return False
    except Exception as e:
        logger.exception("FCM unexpected error: %s", e)
        return False


def _send_fcm_v1(
    *,
    token: str,
    title: str,
    body: str | None = None,
    data: dict[str, str] | None = None,
) -> bool:
    service_account_file = settings.fcm_service_account_file.strip()
    if not service_account_file:
        return False
    if not os.path.exists(service_account_file):
        logger.error(
            "FCM v1 service account file not found: %s", service_account_file
        )
        return False

    try:
        from google.auth.transport.requests import Request as GoogleAuthRequest
        from google.oauth2 import service_account
    except Exception:
        logger.error(
            "FCM v1 requires google-auth package. Install backend requirements."
        )
        return False

    try:
        credentials = service_account.Credentials.from_service_account_file(
            service_account_file,
            scopes=["https://www.googleapis.com/auth/firebase.messaging"],
        )
        credentials.refresh(GoogleAuthRequest())
    except Exception as e:
        logger.exception("FCM v1 auth error: %s", e)
        return False

    project_id = settings.fcm_project_id.strip() or (credentials.project_id or "")
    if not project_id:
        logger.error("FCM v1 project_id not configured")
        return False

    payload: dict[str, object] = {
        "message": {
            "token": token,
            "notification": {
                "title": title,
                "body": body or "",
            },
            "data": _normalize_data(data),
            "android": {
                "priority": "HIGH",
                "notification": {"sound": "default"},
            },
        }
    }
    endpoint = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    req = request.Request(
        endpoint,
        method="POST",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {credentials.token}",
        },
    )
    try:
        with request.urlopen(req, timeout=8) as resp:
            return 200 <= int(resp.status) < 300
    except HTTPError as e:
        body_text = e.read().decode("utf-8", errors="ignore")
        logger.error("FCM v1 HTTP error: status=%s body=%s", e.code, body_text)
        return False
    except URLError as e:
        logger.error("FCM v1 URL error: %s", e)
        return False
    except Exception as e:
        logger.exception("FCM v1 unexpected error: %s", e)
        return False


def send_fcm_push(
    *, token: str, title: str, body: str | None = None, data: dict[str, str] | None = None
) -> bool:
    if not token.strip():
        logger.warning("FCM push skipped: user token is empty")
        return False

    # Prefer FCM HTTP v1 if service account is configured.
    if settings.fcm_service_account_file.strip():
        if _send_fcm_v1(token=token, title=title, body=body, data=data):
            return True
        logger.warning("FCM v1 send failed, trying legacy key if available")

    if _send_fcm_legacy(token=token, title=title, body=body, data=data):
        return True

    logger.warning(
        "FCM push failed: no valid provider (set FCM_SERVICE_ACCOUNT_FILE for v1 or FCM_SERVER_KEY for legacy)"
    )
    return False
