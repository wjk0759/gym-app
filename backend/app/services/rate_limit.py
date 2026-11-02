"""Small per-process sliding-window limiter for expensive AI entry points.

This is intentionally dependency-free for the current single-worker beta. The
interface is stable so it can be replaced by Redis later without touching
routers.
"""

from __future__ import annotations

import threading
import time
from collections import deque

from fastapi import HTTPException

_lock = threading.Lock()
_events: dict[str, deque[float]] = {}
_MAX_KEYS = 10_000


def enforce(feature: str, user_id: str, limit: int, window_seconds: int) -> None:
    key = f"{feature}:{user_id}"
    now = time.monotonic()
    with _lock:
        if len(_events) > _MAX_KEYS:
            cutoff = now - window_seconds
            for old_key, values in list(_events.items()):
                if not values or values[-1] < cutoff:
                    _events.pop(old_key, None)
        bucket = _events.setdefault(key, deque())
        cutoff = now - window_seconds
        while bucket and bucket[0] < cutoff:
            bucket.popleft()
        if len(bucket) >= limit:
            retry_after = max(1, int(window_seconds - (now - bucket[0])))
            raise HTTPException(
                status_code=429,
                detail={
                    "code": "RATE_LIMITED",
                    "message": "请求过于频繁，请稍后再试",
                    "retry_after": retry_after,
                },
            )
        bucket.append(now)
