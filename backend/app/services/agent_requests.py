"""Durable task state and idempotency for agent chat requests.

The router used to keep completed responses and in-flight locks in process
memory. That covered a quick retry on one worker, but a restart or a second
worker could call the model twice and create two AgentRuns. This module stores
one short-lived row per ``(user_id, request_id)``:

* ``running`` blocks a concurrent retry and reports ``retry_after``.
* ``completed`` returns the exact saved response.
* ``failed`` can be retried by taking over the row.
* Expired rows are cleaned up opportunistically.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..models import AgentRequestState, utcnow

REQUEST_TTL_SECONDS = 600
IN_FLIGHT_TIMEOUT_SECONDS = 330
FAILED_RETRY_SECONDS = 30


class AgentRequestInProgress(RuntimeError):
    """Another worker is still handling this request."""

    def __init__(self, retry_after: int):
        self.retry_after = max(1, int(retry_after))
        super().__init__("同一请求正在处理中")


@dataclass(frozen=True)
class AgentRequestClaim:
    request_id: str | None
    replay: dict | None = None
    attempts: int = 0

    @property
    def is_replay(self) -> bool:
        return self.replay is not None


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def normalize_request_id(value: str | None) -> str | None:
    if not isinstance(value, str):
        return None
    cleaned = value.strip()
    return cleaned or None


def _expired(row: AgentRequestState, now: datetime) -> bool:
    return _as_utc(row.expires_at) <= now


def cleanup_expired(db: Session, *, now: datetime | None = None) -> int:
    """Delete expired rows. Safe to call on every claim."""
    current = now or utcnow()
    result = db.execute(
        delete(AgentRequestState)
        .where(AgentRequestState.expires_at <= current)
        .execution_options(synchronize_session=False)
    )
    db.commit()
    # The bulk delete bypasses the identity map; make sure a later db.get()
    # cannot return an expired object that no longer exists in the database.
    db.expire_all()
    return int(result.rowcount or 0)


def _claim_row(
    db: Session,
    user_id: str,
    request_id: str,
    now: datetime,
) -> AgentRequestClaim:
    row = db.get(AgentRequestState, (user_id, request_id))
    if row is None or _expired(row, now):
        if row is not None:
            db.delete(row)
            db.commit()
        db.add(
            AgentRequestState(
                user_id=user_id,
                request_id=request_id,
                status="running",
                attempts=1,
                expires_at=now + timedelta(seconds=REQUEST_TTL_SECONDS),
                created_at=now,
                updated_at=now,
            )
        )
        db.commit()
        return AgentRequestClaim(request_id=request_id, attempts=1)

    if row.status == "completed" and row.response is not None:
        return AgentRequestClaim(
            request_id=request_id,
            replay=row.response,
            attempts=int(row.attempts or 0),
        )

    if row.status == "running":
        age = max(0.0, (now - _as_utc(row.updated_at)).total_seconds())
        if age < IN_FLIGHT_TIMEOUT_SECONDS:
            raise AgentRequestInProgress(
                max(1, int(IN_FLIGHT_TIMEOUT_SECONDS - age))
            )

    # Failed rows are immediately retryable; stale running rows are presumed
    # to belong to a crashed worker and are allowed to take over.
    row.status = "running"
    row.response = None
    row.error = None
    row.attempts = int(row.attempts or 0) + 1
    row.expires_at = now + timedelta(seconds=REQUEST_TTL_SECONDS)
    row.updated_at = now
    db.commit()
    return AgentRequestClaim(
        request_id=request_id,
        attempts=row.attempts,
    )


def claim_agent_request(
    db: Session,
    user_id: str,
    request_id: str | None,
    *,
    now: datetime | None = None,
) -> AgentRequestClaim:
    """Reserve a request, return a replay, or raise ``AgentRequestInProgress``."""
    key = normalize_request_id(request_id)
    if key is None:
        return AgentRequestClaim(request_id=None)
    current = now or utcnow()
    cleanup_expired(db, now=current)
    for attempt in range(2):
        try:
            return _claim_row(db, user_id, key, current)
        except IntegrityError:
            # Another worker inserted the row between our read and insert.
            db.rollback()
            if attempt == 1:
                raise
    raise AssertionError("unreachable")


def complete_agent_request(
    db: Session,
    user_id: str,
    request_id: str | None,
    *,
    run_id: str | None,
    response: dict,
    now: datetime | None = None,
) -> None:
    key = normalize_request_id(request_id)
    if key is None:
        return
    current = now or utcnow()
    row = db.get(AgentRequestState, (user_id, key))
    if row is None:
        return
    row.status = "completed"
    row.run_id = run_id
    row.response = response
    row.error = None
    row.expires_at = current + timedelta(seconds=REQUEST_TTL_SECONDS)
    row.updated_at = current
    db.commit()


def fail_agent_request(
    db: Session,
    user_id: str,
    request_id: str | None,
    *,
    error: str | None = None,
    run_id: str | None = None,
    now: datetime | None = None,
) -> None:
    key = normalize_request_id(request_id)
    if key is None:
        return
    current = now or utcnow()
    db.rollback()
    row = db.get(AgentRequestState, (user_id, key))
    if row is None:
        return
    row.status = "failed"
    row.run_id = run_id or row.run_id
    row.response = None
    row.error = (error or "")[:500] or None
    row.expires_at = current + timedelta(seconds=FAILED_RETRY_SECONDS)
    row.updated_at = current
    db.commit()


def get_agent_request(
    db: Session,
    user_id: str,
    request_id: str,
    *,
    now: datetime | None = None,
) -> dict | None:
    """Return public task state for one request, or None if unknown/expired."""
    key = normalize_request_id(request_id)
    if key is None:
        return None
    current = now or utcnow()
    row = db.get(AgentRequestState, (user_id, key))
    if row is None or _expired(row, current):
        return None
    retry_after = None
    if row.status == "running":
        age = max(0.0, (current - _as_utc(row.updated_at)).total_seconds())
        retry_after = max(1, int(IN_FLIGHT_TIMEOUT_SECONDS - age))
    return {
        "request_id": row.request_id,
        "status": row.status,
        "run_id": row.run_id,
        "response": row.response if row.status == "completed" else None,
        "error": row.error,
        "retry_after": retry_after,
        "attempts": row.attempts,
        "updated_at": row.updated_at.isoformat() if row.updated_at else None,
    }
