"""Server-side Pro entitlements, one-time trials and weekly usage.

The iOS client only renders this snapshot. All premium decisions are made
here so a patched client cannot unlock or reset local state.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..models import FeatureTrial, FeatureUsage, UserEntitlement, utcnow

# China has no DST. A fixed UTC+8 offset avoids a hard dependency on the
# optional tzdata package in slim containers and on Windows test machines.
BUSINESS_TZ = timezone(timedelta(hours=8))

FEATURE_TRAINING_PLAN = "training_plan"
FEATURE_MEAL_PLAN = "meal_plan"
FEATURE_COACH_AI = "coach_ai"
FEATURE_FOOD_PHOTO = "food_photo"
FEATURE_BODY_PHOTO = "body_photo"
FEATURE_AI_VISION = "ai_vision"
COACH_WEEKLY_LIMIT = 3


@dataclass(frozen=True)
class Entitlement:
    active: bool
    expires_at: datetime | None
    sources: tuple[str, ...]


def _as_utc(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def active_entitlement(
    db: Session,
    user_id: str,
    *,
    now: datetime | None = None,
    plan_code: str = "pro",
) -> Entitlement:
    current = now or utcnow()
    rows = db.execute(
        select(UserEntitlement).where(
            UserEntitlement.user_id == user_id,
            UserEntitlement.plan_code == plan_code,
            UserEntitlement.revoked_at.is_(None),
            UserEntitlement.starts_at <= current,
            UserEntitlement.expires_at > current,
        )
    ).scalars().all()
    if not rows:
        return Entitlement(False, None, ())
    expires = max(_as_utc(row.expires_at) for row in rows if row.expires_at)
    sources = tuple(sorted({row.source for row in rows}))
    return Entitlement(True, expires, sources)


def has_pro(db: Session, user_id: str) -> bool:
    return active_entitlement(db, user_id).active


def business_today(now: datetime | None = None) -> date:
    current = now or utcnow()
    return current.astimezone(BUSINESS_TZ).date()


def week_start_for(day: date) -> date:
    return day - timedelta(days=day.weekday())


def coach_usage(
    db: Session,
    user_id: str,
    *,
    now: datetime | None = None,
) -> tuple[int, date, datetime]:
    period = week_start_for(business_today(now))
    row = db.get(FeatureUsage, (user_id, FEATURE_COACH_AI, period))
    used = row.used_count if row else 0
    reset = datetime.combine(
        period + timedelta(days=7), datetime.min.time(), tzinfo=BUSINESS_TZ
    )
    return used, period, reset.astimezone(timezone.utc)


def access_snapshot(db: Session, user_id: str) -> dict:
    entitlement = active_entitlement(db, user_id)
    training = db.get(FeatureTrial, (user_id, FEATURE_TRAINING_PLAN))
    meal = db.get(FeatureTrial, (user_id, FEATURE_MEAL_PLAN))
    used, _, reset = coach_usage(db, user_id)
    remaining = (
        None if entitlement.active else max(0, COACH_WEEKLY_LIMIT - used)
    )
    return {
        "is_pro": entitlement.active,
        "pro_expires_at": (
            _as_utc(entitlement.expires_at).isoformat()
            if entitlement.expires_at
            else None
        ),
        "pro_sources": list(entitlement.sources),
        "features": {
            FEATURE_TRAINING_PLAN: {
                "trial_used": training is not None,
                "trial_source": training.source if training else None,
                "trial_used_at": (
                    _as_utc(training.used_at).isoformat() if training else None
                ),
                "can_generate": entitlement.active,
                "requires_pro": not entitlement.active,
            },
            FEATURE_MEAL_PLAN: {
                "trial_used": meal is not None,
                "trial_available": meal is None,
                "can_generate": entitlement.active or meal is None,
                "requires_pro": not entitlement.active and meal is not None,
            },
            FEATURE_COACH_AI: {
                "weekly_limit": COACH_WEEKLY_LIMIT,
                "used": used,
                "remaining": remaining,
                "reset_at": reset.isoformat(),
                "can_send": entitlement.active or (remaining or 0) > 0,
            },
        },
    }


def _raise_pro_required(feature_key: str) -> None:
    raise HTTPException(
        status_code=403,
        detail={
            "code": "PRO_REQUIRED",
            "feature": feature_key,
            "message": "该功能需要 Pro",
        },
    )


def require_training_plan_generation(
    db: Session,
    user_id: str,
    *,
    onboarding: bool = False,
) -> str:
    """Return ``pro``, ``onboarding`` or ``trial`` for a generation request."""
    if has_pro(db, user_id):
        return "pro"
    trial = db.get(FeatureTrial, (user_id, FEATURE_TRAINING_PLAN))
    if onboarding and trial is None:
        return "onboarding"
    _raise_pro_required(FEATURE_TRAINING_PLAN)


def require_meal_plan_generation(db: Session, user_id: str) -> str:
    if has_pro(db, user_id):
        return "pro"
    trial = db.get(FeatureTrial, (user_id, FEATURE_MEAL_PLAN))
    if trial is None:
        return "trial"
    _raise_pro_required(FEATURE_MEAL_PLAN)


def require_feature(db: Session, user_id: str, feature_key: str) -> None:
    """Direct Pro gate with no trial for photo/video analysis."""
    if not has_pro(db, user_id):
        _raise_pro_required(feature_key)


def consume_trial(
    db: Session,
    user_id: str,
    feature_key: str,
    *,
    source: str,
    valid_until: datetime | None = None,
    result_ref: str | None = None,
) -> bool:
    """Record a successful one-time trial. Duplicate calls are no-ops."""
    if db.get(FeatureTrial, (user_id, feature_key)) is not None:
        return False
    db.add(
        FeatureTrial(
            user_id=user_id,
            feature_key=feature_key,
            source=source,
            valid_until=valid_until,
            result_ref=result_ref,
        )
    )
    try:
        db.commit()
        return True
    except IntegrityError:
        db.rollback()
        return False


def reserve_coach_message(db: Session, user_id: str) -> bool:
    """Atomically reserve one weekly coach message for a free user."""
    if has_pro(db, user_id):
        return True
    period = week_start_for(business_today())
    row = db.execute(
        select(FeatureUsage)
        .where(
            FeatureUsage.user_id == user_id,
            FeatureUsage.feature_key == FEATURE_COACH_AI,
            FeatureUsage.period_start == period,
        )
        .with_for_update()
    ).scalar_one_or_none()
    if row is None:
        db.add(
            FeatureUsage(
                user_id=user_id,
                feature_key=FEATURE_COACH_AI,
                period_start=period,
                used_count=1,
            )
        )
    elif row.used_count >= COACH_WEEKLY_LIMIT:
        return False
    else:
        row.used_count += 1
    db.commit()
    return True


def release_coach_message(db: Session, user_id: str, *, period: date) -> None:
    """Return a reserved message after an AI failure."""
    if has_pro(db, user_id):
        return
    row = db.execute(
        select(FeatureUsage)
        .where(
            FeatureUsage.user_id == user_id,
            FeatureUsage.feature_key == FEATURE_COACH_AI,
            FeatureUsage.period_start == period,
        )
        .with_for_update()
    ).scalar_one_or_none()
    if row is not None and row.used_count > 0:
        row.used_count -= 1
        db.commit()
