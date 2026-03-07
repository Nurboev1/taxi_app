from datetime import datetime, timedelta, timezone
from threading import Lock


_RATE_LOCK = Lock()
_RATE_BUCKETS: dict[str, list[datetime]] = {}


def hit_rate_limit(
    key: str,
    limit: int,
    window_seconds: int,
) -> int:
    """
    Returns 0 if request is allowed.
    Returns wait seconds (>0) if rate-limited.
    """
    if limit <= 0 or window_seconds <= 0:
        return 0

    now = datetime.now(timezone.utc)
    window_start = now - timedelta(seconds=window_seconds)

    with _RATE_LOCK:
        hits = _RATE_BUCKETS.get(key, [])
        hits = [ts for ts in hits if ts >= window_start]

        if len(hits) >= limit:
            oldest = hits[0]
            retry_after = max(
                1,
                int((oldest + timedelta(seconds=window_seconds) - now).total_seconds()),
            )
            _RATE_BUCKETS[key] = hits
            return retry_after

        hits.append(now)
        _RATE_BUCKETS[key] = hits
        return 0
