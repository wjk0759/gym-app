"""Distributed token bucket for expensive AI entry points.

A bucket is one row per ``(feature, user)``. Tokens are integer milli-units so
all workers share the same state without floating-point drift and without a
Redis dependency. The bucket refills continuously (``limit`` tokens per
``window_seconds``) and allows a burst up to ``limit``.

Rows are tiny and one per user/feature; a periodic cleanup can delete buckets
whose ``updated_at`` is older than a few days.
"""

from __future__ import annotations

from datetime import datetime, timezone
from math import ceil

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..models import RateLimitBucket, utcnow

TOKEN_SCALE = 1000


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _bucket_key(feature: str, user_id: str) -> str:
    return f"{feature}:{user_id}"[:120]


def _locked_bucket(db: Session, key: str) -> RateLimitBucket | None:
    return db.execute(
        select(RateLimitBucket)
        .where(RateLimitBucket.bucket_key == key)
        .with_for_update()
    ).scalar_one_or_none()


def _raise_limited(feature: str, retry_after: int) -> None:
    raise HTTPException(
        status_code=429,
        detail={
            "code": "RATE_LIMITED",
            "feature": feature,
            "message": "请求过于频繁，请稍后再试",
            "retry_after": retry_after,
        },
    )


def enforce(
    db: Session,
    feature: str,
    user_id: str,
    limit: int,
    window_seconds: int,
    *,
    now: datetime | None = None,
) -> None:
    """Consume one token or raise a structured 429."""
    if limit <= 0 or window_seconds <= 0:
        raise ValueError("limit and window_seconds must be positive")

    key = _bucket_key(feature, user_id)
    current = now or utcnow()
    capacity = limit * TOKEN_SCALE

    for attempt in range(2):
        bucket = _locked_bucket(db, key)
        if bucket is None:
            db.add(
                RateLimitBucket(
                    bucket_key=key,
                    tokens_milli=capacity - TOKEN_SCALE,
                    updated_at=current,
                )
            )
            try:
                db.commit()
                return
            except IntegrityError:
                # Another worker created the bucket first; re-read and apply
                # the normal refill/consume path on the second attempt.
                db.rollback()
                if attempt == 1:
                    raise
                continue

        elapsed = max(
            0.0, (current - _as_utc(bucket.updated_at)).total_seconds()
        )
        refill = int(elapsed * limit * TOKEN_SCALE / window_seconds)
        tokens = min(capacity, max(0, bucket.tokens_milli) + refill)
        if refill > 0:
            bucket.updated_at = current

        if tokens < TOKEN_SCALE:
            needed = TOKEN_SCALE - tokens
            retry_after = max(
                1, ceil(needed * window_seconds / (limit * TOKEN_SCALE))
            )
            _raise_limited(feature, retry_after)

        bucket.tokens_milli = tokens - TOKEN_SCALE
        db.commit()
        return

    raise AssertionError("unreachable")
