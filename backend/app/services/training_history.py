from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import (
    Exercise,
    PlanExercise,
    Program,
    ProgramDay,
    SetLog,
    WorkoutSession,
    utcnow,
)

HISTORY_WEEKS = 12
WORKING_REP_MIN = 5
WORKING_REP_MAX = 15
BUSINESS_OFFSET = timedelta(hours=8)

HISTORY_WINDOW_DAYS = 180
MAX_RECENT_SESSIONS = 3
MAX_HISTORY_SESSIONS = 10
MAX_SETS_PER_SESSION = 30
MAX_CONTEXT_SETS_PER_SESSION = 6
MAX_DETAIL_SETS = 80


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


def _history_e1rm(weight: Any, reps: Any) -> float | None:
    """Epley estimate used by the coach history payload.

    Unlike the progression helper, this keeps estimates above 12 reps because
    the coach may need to compare higher-rep sets.
    """
    try:
        w = float(weight or 0)
        r = int(reps or 0)
    except (TypeError, ValueError):
        return None
    if w <= 0 or r <= 0:
        return None
    return round(w * (1 + r / 30), 1)


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


def _set_payload(item: SetLog, *, include_e1rm: bool = False) -> dict:
    payload: dict[str, Any] = {
        "weight_kg": item.weight_kg,
        "reps": item.reps,
        "rpe": item.rpe,
    }
    if include_e1rm:
        payload["e1rm"] = _history_e1rm(item.weight_kg, item.reps)
    return payload


def _fetch_rows(
    db: Session,
    user_id: str,
    slugs: list[str],
):
    slugs = [slug for slug in slugs if slug]
    if not slugs:
        return []
    since = utcnow() - timedelta(days=HISTORY_WINDOW_DAYS)
    return db.execute(
        select(SetLog, WorkoutSession.started_at, WorkoutSession.duration_min)
        .join(WorkoutSession, SetLog.session_id == WorkoutSession.id)
        .where(
            WorkoutSession.user_id == user_id,
            SetLog.exercise_slug.in_(slugs),
            SetLog.completed.is_(True),
            WorkoutSession.started_at >= since,
        )
        .order_by(WorkoutSession.started_at.desc(), SetLog.set_index.asc())
    ).all()


def _group_by_slug(rows) -> dict[str, dict[str, dict]]:
    grouped: dict[str, dict[str, dict]] = {}
    for set_log, started_at, duration_min in rows:
        slug = set_log.exercise_slug
        sessions = grouped.setdefault(slug, {})
        session = sessions.setdefault(
            set_log.session_id,
            {
                "session_id": set_log.session_id,
                "date": _business_date(started_at).isoformat(),
                "duration_min": duration_min,
                "sets": [],
            },
        )
        if len(session["sets"]) < MAX_SETS_PER_SESSION:
            session["sets"].append(_set_payload(set_log))
    return grouped


def exercise_performance(
    db: Session,
    user_id: str,
    slugs: list[str],
) -> dict[str, dict]:
    """Return last/best/recent facts for the given exercises."""
    rows = _fetch_rows(db, user_id, slugs)
    grouped = _group_by_slug(rows)
    result: dict[str, dict] = {}

    for slug, sessions in grouped.items():
        ordered = list(sessions.values())
        if not ordered:
            continue
        last_session = ordered[0]
        last_set = max(
            last_session["sets"],
            key=lambda item: (
                float(item.get("weight_kg") or 0),
                int(item.get("reps") or 0),
            ),
            default=None,
        )
        best_set: dict[str, Any] | None = None
        for session in ordered:
            for item in session["sets"]:
                if best_set is None or (
                    float(item.get("weight_kg") or 0),
                    int(item.get("reps") or 0),
                ) > (
                    float(best_set.get("weight_kg") or 0),
                    int(best_set.get("reps") or 0),
                ):
                    best_set = item

        payload: dict[str, Any] = {
            "session_count": len(ordered),
            "recent": [
                {
                    **session,
                    "sets": session["sets"][:MAX_CONTEXT_SETS_PER_SESSION],
                }
                for session in ordered[:MAX_RECENT_SESSIONS]
            ],
        }
        if last_set is not None:
            payload["last"] = {
                "date": last_session["date"],
                "session_id": last_session["session_id"],
                **last_set,
            }
        if best_set is not None:
            payload["best"] = {
                "weight_kg": best_set["weight_kg"],
                "reps": best_set["reps"],
                "e1rm": _history_e1rm(
                    best_set["weight_kg"],
                    best_set["reps"],
                ),
            }
        result[slug] = payload

    return result


def exercise_history_payload(
    db: Session,
    user_id: str,
    slug: str,
    limit: int = 5,
) -> dict:
    slug = (slug or "").strip()
    if not slug:
        return {"ok": False, "error": "请提供动作 slug"}

    # Custom exercises may not be in the shared catalog. Their logged sets are
    # still valid history, so only the empty-slug case is an error.
    exercise = db.get(Exercise, slug)
    name_zh = (
        exercise.name_zh
        if exercise is not None and exercise.is_active
        else slug
    )

    limit = max(1, min(20, int(limit or 5)))
    rows = _fetch_rows(db, user_id, [slug])
    grouped = _group_by_slug(rows)
    sessions = list(grouped.get(slug, {}).values())[:limit]

    history_sets: list[dict] = []
    for session in sessions:
        for item in session["sets"]:
            item["e1rm"] = _history_e1rm(
                item.get("weight_kg"),
                item.get("reps"),
            )
            history_sets.append(item)

    best = max(
        history_sets,
        key=lambda item: (
            float(item.get("weight_kg") or 0),
            int(item.get("reps") or 0),
        ),
        default=None,
    )

    return {
        "ok": True,
        "slug": slug,
        "name_zh": name_zh,
        "sessions": sessions,
        "best": best,
    }


def workout_detail_payload(
    db: Session,
    user_id: str,
    session_id: str,
) -> dict:
    session_id = (session_id or "").strip()
    session = db.get(WorkoutSession, session_id) if session_id else None
    if session is None or session.user_id != user_id:
        return {"ok": False, "error": "没有找到这次训练"}

    rows = (
        db.execute(
            select(SetLog)
            .where(
                SetLog.session_id == session.id,
                SetLog.completed.is_(True),
            )
            .order_by(SetLog.exercise_slug.asc(), SetLog.set_index.asc())
        )
        .scalars()
        .all()
    )

    slugs = sorted({item.exercise_slug for item in rows})
    names: dict[str, str] = {}
    if slugs:
        for exercise in db.execute(
            select(Exercise).where(Exercise.slug.in_(slugs))
        ).scalars():
            names[exercise.slug] = exercise.name_zh

    grouped: dict[str, list[dict]] = {}
    for item in rows:
        grouped.setdefault(item.exercise_slug, []).append(
            {
                "set_index": item.set_index,
                "weight_kg": item.weight_kg,
                "reps": item.reps,
                "rpe": item.rpe,
            }
        )

    exercises = [
        {
            "slug": slug,
            "name_zh": names.get(slug, slug),
            "sets": sets[:MAX_DETAIL_SETS],
        }
        for slug, sets in grouped.items()
    ]

    return {
        "ok": True,
        "session": {
            "id": session.id,
            "date": _business_date(session.started_at).isoformat(),
            "duration_min": session.duration_min,
            "feeling": session.feeling,
            "notes": (session.notes or "")[:500],
        },
        "exercises": exercises,
        "truncated": any(
            len(sets) > MAX_DETAIL_SETS for sets in grouped.values()
        ),
    }
