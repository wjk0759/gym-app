from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import PlanExercise, Program, ProgramDay, SetLog, WorkoutSession

HISTORY_WEEKS = 12
WORKING_REP_MIN = 5
WORKING_REP_MAX = 15
BUSINESS_OFFSET = timedelta(hours=8)


def _business_date(value: datetime):
    value = (
        value.replace(tzinfo=timezone.utc)
        if value.tzinfo is None
        else value.astimezone(timezone.utc)
    )
    return (value + BUSINESS_OFFSET).date()


def _e1rm(weight: float, reps: int) -> float | None:
    if reps < 1 or reps > 12:
        return None
    return round(weight * (1 + reps / 30), 1)


def _plan_targets(
    db: Session,
    user_id: str,
    slugs: set[str],
) -> dict[str, float]:
    if not slugs:
        return {}
    rows = db.execute(
        select(PlanExercise.exercise_slug, PlanExercise.weight_kg)
        .join(ProgramDay, ProgramDay.id == PlanExercise.program_day_id)
        .join(Program, Program.id == ProgramDay.program_id)
        .where(
            Program.user_id == user_id,
            PlanExercise.exercise_slug.in_(slugs),
            PlanExercise.weight_kg.isnot(None),
            PlanExercise.weight_kg > 0,
        )
        .order_by(
            Program.created_at.desc(),
            Program.version.desc(),
            ProgramDay.week_index,
            PlanExercise.order_index,
        )
    ).all()
    targets: dict[str, float] = {}
    for slug, weight in rows:
        if slug not in targets and weight is not None:
            targets[slug] = float(weight)
    return targets


def load_exercise_history(
    db: Session,
    user_id: str,
    slugs: set[str] | None = None,
    *,
    weeks: int = HISTORY_WEEKS,
) -> dict[str, dict]:
    """Return the last working set per exercise plus the last plan target.

    Real completed sets are authoritative. If an exercise has no logged set,
    ``plan_weight_kg`` is kept so the caller can use the user's last manually
    edited target without inventing a new load.
    """
    since = datetime.now(timezone.utc) - timedelta(weeks=weeks)
    query = (
        select(
            WorkoutSession.started_at,
            SetLog.exercise_slug,
            SetLog.weight_kg,
            SetLog.reps,
            SetLog.rpe,
        )
        .join(SetLog, SetLog.session_id == WorkoutSession.id)
        .where(
            WorkoutSession.user_id == user_id,
            WorkoutSession.started_at >= since,
            SetLog.completed.is_(True),
            SetLog.weight_kg.isnot(None),
            SetLog.weight_kg > 0,
            SetLog.reps.isnot(None),
            SetLog.reps > 0,
        )
        .order_by(
            WorkoutSession.started_at.desc(),
            SetLog.set_index,
        )
    )
    if slugs:
        query = query.where(SetLog.exercise_slug.in_(slugs))

    latest_by_slug: dict[str, tuple[datetime, list[dict]]] = {}
    session_keys: dict[str, set[datetime]] = {}
    for started_at, slug, weight, reps, rpe in db.execute(query).all():
        if started_at is None or weight is None or reps is None:
            continue
        session_keys.setdefault(slug, set()).add(started_at)
        current = latest_by_slug.get(slug)
        if current is None or started_at > current[0]:
            latest_by_slug[slug] = (started_at, [])
        if started_at == latest_by_slug[slug][0]:
            latest_by_slug[slug][1].append(
                {
                    "weight": float(weight),
                    "reps": int(reps),
                    "rpe": float(rpe) if rpe is not None else None,
                }
            )

    targets = _plan_targets(
        db,
        user_id,
        set(latest_by_slug) | set(slugs or set()),
    )
    history: dict[str, dict] = {}
    for slug, (started_at, sets) in latest_by_slug.items():
        if not sets:
            continue
        working = [
            item
            for item in sets
            if WORKING_REP_MIN <= item["reps"] <= WORKING_REP_MAX
        ] or sets
        anchor = max(working, key=lambda item: (item["weight"], item["reps"]))
        e1rms = [
            value
            for item in sets
            if (value := _e1rm(item["weight"], item["reps"])) is not None
        ]
        history[slug] = {
            "source": "log",
            "last_weight_kg": anchor["weight"],
            "last_reps": anchor["reps"],
            "last_rpe": anchor["rpe"],
            "last_date": _business_date(started_at).isoformat(),
            "session_count": len(session_keys.get(slug, set())),
            "best_e1rm": max(e1rms) if e1rms else None,
            "plan_weight_kg": targets.get(slug),
        }

    for slug, weight in targets.items():
        history.setdefault(
            slug,
            {
                "source": "plan",
                "last_weight_kg": None,
                "last_reps": None,
                "last_rpe": None,
                "last_date": None,
                "session_count": 0,
                "best_e1rm": None,
                "plan_weight_kg": weight,
            },
        )
    return history
