"""Durable cooldown, in-flight lock and idempotent replay for AI generations.

The per-process sliding-window limiter protects against bursts, but it cannot
stop a second worker or a restart from charging the provider twice. This module
keeps a small row per ``(user, feature)`` in MySQL:

* ``running`` blocks concurrent generations for the same user/feature.
* ``succeeded`` enforces a short cooldown between paid generations.
* A retried ``Idempotency-Key`` returns the previously persisted result ref
  instead of calling the model again.

Callers reserve before checking entitlements and abort if the request is
rejected, so a trial that was already consumed can still replay its result.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from math import ceil

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..config import settings
from ..models import FeatureGenerationState, utcnow

COOLDOWN_SECONDS = 60
REPLAY_TTL_SECONDS = 600
# Provider calls time out on the client after 180s; leave headroom so a late
# response does not overlap a retry, but do not block a user forever after a
# crashed worker.
IN_FLIGHT_TIMEOUT_SECONDS = 300

RUNNING = "running"
SUCCEEDED = "succeeded"


@dataclass(frozen=True)
class GenerationLease:
    feature_key: str
    idempotency_key: str | None
    replay_result_ref: str | None = None

    @property
    def is_replay(self) -> bool:
        return self.replay_result_ref is not None


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _normalize_key(value: str | None) -> str | None:
    if value is None:
        return None
    cleaned = value.strip()
    return cleaned or None


def _cooldown_seconds() -> int:
    return max(0, int(settings.generation_cooldown_seconds))


def _raise_generation_error(
    code: str,
    feature_key: str,
    message: str,
    retry_after: int,
) -> None:
    raise HTTPException(
        status_code=429,
        detail={
            "code": code,
            "feature": feature_key,
            "message": message,
            "retry_after": retry_after,
        },
    )


def _locked_state(
    db: Session,
    user_id: str,
    feature_key: str,
) -> FeatureGenerationState | None:
    return db.execute(
        select(FeatureGenerationState)
        .where(
            FeatureGenerationState.user_id == user_id,
            FeatureGenerationState.feature_key == feature_key,
        )
        .with_for_update()
    ).scalar_one_or_none()


def begin_generation(
    db: Session,
    user_id: str,
    feature_key: str,
    *,
    idempotency_key: str | None = None,
    now: datetime | None = None,
) -> GenerationLease:
    """Reserve a generation slot, or return a replay for the same key.

    Raises a structured 429 when another generation is still running or the
    previous successful generation is inside the cooldown window.
    """
    key = _normalize_key(idempotency_key)
    current = now or utcnow()

    for attempt in range(2):
        row = _locked_state(db, user_id, feature_key)
        if row is not None:
            age = max(0.0, (current - _as_utc(row.last_generated_at)).total_seconds())
            cooldown = _cooldown_seconds()
            if row.state == SUCCEEDED:
                if (
                    key is not None
                    and row.last_idempotency_key == key
                    and age <= REPLAY_TTL_SECONDS
                ):
                    return GenerationLease(
                        feature_key=feature_key,
                        idempotency_key=key,
                        replay_result_ref=row.last_result_ref,
                    )
                if age < cooldown:
                    _raise_generation_error(
                        "GENERATION_COOLDOWN",
                        feature_key,
                        "刚刚生成过，请稍后再试",
                        max(1, ceil(cooldown - age)),
                    )
            elif row.state == RUNNING and age < IN_FLIGHT_TIMEOUT_SECONDS:
                _raise_generation_error(
                    "GENERATION_IN_PROGRESS",
                    feature_key,
                    "正在生成中，请稍后查看结果",
                    max(1, ceil(IN_FLIGHT_TIMEOUT_SECONDS - age)),
                )

            row.state = RUNNING
            row.last_generated_at = current
            row.last_result_ref = None
            row.last_idempotency_key = key
            row.updated_at = current
        else:
            db.add(
                FeatureGenerationState(
                    user_id=user_id,
                    feature_key=feature_key,
                    state=RUNNING,
                    last_generated_at=current,
                    last_idempotency_key=key,
                    updated_at=current,
                )
            )

        try:
            db.commit()
            return GenerationLease(feature_key=feature_key, idempotency_key=key)
        except IntegrityError:
            # Two workers inserted the first row at the same time. Re-read the
            # winner; the second pass applies its cooldown/in-flight decision.
            db.rollback()
            if attempt == 1:
                raise

    raise AssertionError("unreachable")


def complete_generation(
    db: Session,
    lease: GenerationLease,
    *,
    user_id: str,
    result_ref: str,
    now: datetime | None = None,
) -> None:
    """Mark the reserved generation as successful and start the cooldown."""
    current = now or utcnow()
    row = _locked_state(db, user_id, lease.feature_key)
    if row is None or row.state != RUNNING:
        return
    if row.last_idempotency_key != lease.idempotency_key:
        return
    row.state = SUCCEEDED
    row.last_result_ref = result_ref
    row.last_generated_at = current
    row.updated_at = current
    db.commit()


def abort_generation(
    db: Session,
    lease: GenerationLease,
    *,
    user_id: str,
) -> None:
    """Release a reservation after a failure so the user can retry."""
    db.rollback()
    row = _locked_state(db, user_id, lease.feature_key)
    if (
        row is None
        or row.state != RUNNING
        or row.last_idempotency_key != lease.idempotency_key
    ):
        return
    db.delete(row)
    db.commit()
