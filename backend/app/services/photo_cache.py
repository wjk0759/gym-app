"""Idempotent replay for sanitized photo-analysis results.

Photo endpoints may retry after a timeout or a dropped response. The server
already has a per-user in-flight lock and a short cooldown, but without a
result cache a retry still pays the vision provider twice. This module stores
only the small text/JSON result for a client-supplied ``Idempotency-Key``; the
original image is never persisted.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import delete
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..models import FeatureResultCache, utcnow

RESULT_CACHE_TTL_SECONDS = 300


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def normalize_key(value: str | None) -> str | None:
    if not isinstance(value, str):
        return None
    cleaned = value.strip()
    return cleaned or None


def get_cached_result(
    db: Session,
    user_id: str,
    feature_key: str,
    idempotency_key: str | None,
    *,
    now: datetime | None = None,
) -> dict | None:
    key = normalize_key(idempotency_key)
    if key is None:
        return None
    row = db.get(FeatureResultCache, (user_id, feature_key, key))
    if row is None:
        return None
    if _as_utc(row.expires_at) <= (now or utcnow()):
        # Let the next write clean it up. Deleting here could race with another
        # worker that just refreshed the same key.
        return None
    return row.result


def cleanup_expired(
    db: Session,
    *,
    now: datetime | None = None,
) -> int:
    """Delete expired sanitized results so the cache does not grow forever."""
    result = db.execute(
        delete(FeatureResultCache).where(
            FeatureResultCache.expires_at <= (now or utcnow())
        )
    )
    db.commit()
    return int(result.rowcount or 0)


def store_cached_result(
    db: Session,
    user_id: str,
    feature_key: str,
    idempotency_key: str | None,
    result: dict,
    *,
    ttl_seconds: int = RESULT_CACHE_TTL_SECONDS,
    now: datetime | None = None,
) -> None:
    key = normalize_key(idempotency_key)
    if key is None:
        return
    current = now or utcnow()
    cleanup_expired(db, now=current)
    expires_at = current + timedelta(seconds=max(1, ttl_seconds))
    row = db.get(FeatureResultCache, (user_id, feature_key, key))
    if row is None:
        db.add(
            FeatureResultCache(
                user_id=user_id,
                feature_key=feature_key,
                idempotency_key=key,
                result=result,
                expires_at=expires_at,
                created_at=current,
            )
        )
    else:
        row.result = result
        row.expires_at = expires_at
        row.created_at = current
    try:
        db.commit()
    except IntegrityError:
        # Two retries with the same key landed at once. Keep the first stored
        # result so replay semantics stay stable; never overwrite it with the
        # loser of the race.
        db.rollback()
