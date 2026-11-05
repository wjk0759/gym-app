from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import Profile, SetLog, WorkoutSession

BUSINESS_OFFSET = timedelta(hours=8)
STAGE_ORDER = ("beginner", "intermediate", "advanced")
STAGE_DAYS = {"beginner": 0, "intermediate": 60, "advanced": 120}


def stage_for_days(days: int) -> str:
    if days >= STAGE_DAYS["advanced"]:
        return "advanced"
    if days >= STAGE_DAYS["intermediate"]:
        return "intermediate"
    return "beginner"


def stage_rank(stage: str | None) -> int:
    try:
        return STAGE_ORDER.index(stage or "beginner")
    except ValueError:
        return 0


def _business_date(value: datetime) -> date:
    value = (
        value.replace(tzinfo=timezone.utc)
        if value.tzinfo is None
        else value.astimezone(timezone.utc)
    )
    return (value + BUSINESS_OFFSET).date()


def completed_training_days(db: Session, user_id: str) -> int:
    """Count distinct Asia/Shanghai days with at least one completed set."""
    started_at = db.execute(
        select(WorkoutSession.started_at)
        .join(SetLog, SetLog.session_id == WorkoutSession.id)
        .where(
            WorkoutSession.user_id == user_id,
            WorkoutSession.started_at.isnot(None),
            SetLog.completed.is_(True),
        )
        .distinct()
    ).scalars().all()
    return len({_business_date(value) for value in started_at if value is not None})


def refresh_training_stage(
    db: Session,
    user_id: str,
    *,
    promote_only: bool = True,
) -> str | None:
    """Promote the stored stage from completed training days.

    The stage is a milestone, so normal calls never demote it. The caller owns
    the transaction; this function only flushes the changed profile.
    """
    profile = db.get(Profile, user_id)
    if profile is None:
        return None
    candidate = stage_for_days(completed_training_days(db, user_id))
    current = profile.training_stage or "beginner"
    if not promote_only or stage_rank(candidate) > stage_rank(current):
        if profile.training_stage != candidate:
            profile.training_stage = candidate
            db.flush()
        return candidate
    return current
