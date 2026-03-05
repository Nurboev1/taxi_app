import json
from urllib import request

from app.core.settings import settings


def send_fcm_push(*, token: str, title: str, body: str | None = None, data: dict[str, str] | None = None) -> bool:
    server_key = settings.fcm_server_key.strip()
    if not server_key:
        return False
    if not token.strip():
        return False

    payload: dict[str, object] = {
        "to": token,
        "priority": "high",
        "notification": {
            "title": title,
            "body": body or "",
            "sound": "default",
        },
        "data": data or {},
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
            return 200 <= int(resp.status) < 300
    except Exception:
        return False

