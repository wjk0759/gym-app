from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from ..deps import CurrentUser, DBSession
from ..models import Exercise, Program, ProgramDay, Profile, SetLog, WorkoutSession
from ..schemas import WorkoutIn

router = APIRouter(prefix="/workouts", tags=["workouts"])


def _parse_dt(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="时间格式需为 ISO 8601") from exc


def _validate_slugs(db: DBSession, sets: list) -> None:
    if not sets:
        return
    slugs = {item.slug for item in sets}
    existing = {
        row[0]
        for row in db.execute(
            select(Exercise.slug).where(Exercise.slug.in_(slugs))
        ).all()
    }
    missing = slugs - existing
    if missing:
        raise HTTPException(
            status_code=422, detail=f"动作不存在：{', '.join(sorted(missing))}"
        )


def _owned_program_day_id(
    db: DBSession, user_id: str, program_day_id: str | None
) -> str | None:
    """Only link a workout to a plan day owned by the current user.

    The iOS app can have a locally generated plan whose day ids do not exist on
    the server yet. Syncing the workout itself must not fail because of that;
    the association is simply left empty until the plan is synced.
    """
    if not program_day_id:
        return None
    owned = db.execute(
        select(ProgramDay.id)
        .join(Program, Program.id == ProgramDay.program_id)
        .where(
            ProgramDay.id == program_day_id,
            Program.user_id == user_id,
        )
    ).scalar_one_or_none()
    return owned


@router.post("", status_code=201)
def create_workout(payload: WorkoutIn, user_id: CurrentUser, db: DBSession):
    started_at = _parse_dt(payload.started_at)
    if started_at is None:
        raise HTTPException(status_code=400, detail="started_at 必填")
    finished_at = _parse_dt(payload.finished_at)
    _validate_slugs(db, payload.sets)
    program_day_id = _owned_program_day_id(db, user_id, payload.program_day_id)

    duration = None
    if finished_at:
        duration = max(0, int((finished_at - started_at).total_seconds() / 60))

    session = WorkoutSession(
        user_id=user_id,
        program_day_id=program_day_id,
        started_at=started_at,
        finished_at=finished_at,
        duration_min=duration,
        feeling=payload.feeling,
        notes=payload.notes,
    )
    for item in payload.sets:
        session.sets.append(
            SetLog(
                exercise_slug=item.slug,
                set_index=item.set_index,
                weight_kg=item.weight_kg,
                reps=item.reps,
                rpe=item.rpe,
                completed=item.completed,
            )
        )

    db.add(session)
    db.commit()
    return {"id": session.id, "duration_min": duration}


@router.get("")
def list_workouts(
    user_id: CurrentUser,
    db: DBSession,
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
    limit: int = Query(default=20, ge=1, le=100),
    include_sets: bool = Query(default=False),
):
    query = (
        select(WorkoutSession)
        .options(selectinload(WorkoutSession.sets))
        .where(WorkoutSession.user_id == user_id)
    )
    if date_from:
        query = query.where(
            WorkoutSession.started_at
            >= datetime.combine(date_from, datetime.min.time(), tzinfo=timezone.utc)
        )
    if date_to:
        query = query.where(
            WorkoutSession.started_at
            < datetime.combine(
                date_to + timedelta(days=1), datetime.min.time(), tzinfo=timezone.utc
            )
        )
    rows = (
        db.execute(query.order_by(WorkoutSession.started_at.desc()).limit(limit))
        .scalars()
        .all()
    )
    items = []
    for item in rows:
        payload = {
            "id": item.id,
            "program_day_id": item.program_day_id,
            "started_at": item.started_at.isoformat(),
            "finished_at": item.finished_at.isoformat() if item.finished_at else None,
            "duration_min": item.duration_min,
            "feeling": item.feeling,
            "notes": item.notes,
            "set_count": len(item.sets),
        }
        if include_sets:
            payload["sets"] = [
                {
                    "slug": log.exercise_slug,
                    "set_index": log.set_index,
                    "weight_kg": log.weight_kg,
                    "reps": log.reps,
                    "rpe": log.rpe,
                    "completed": log.completed,
                }
                for log in item.sets
            ]
        items.append(payload)
    return {"items": items}


@router.get("/summary")
def summary(user_id: CurrentUser, db: DBSession, weeks: int = Query(default=4, ge=1, le=26)):
    since = datetime.now(timezone.utc) - timedelta(weeks=weeks)
    sessions = (
        db.execute(
            select(WorkoutSession)
            .options(selectinload(WorkoutSession.sets))
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.started_at >= since,
            )
        )
        .scalars()
        .all()
    )

    total_volume = 0.0
    by_week: dict[str, dict] = {}
    for session in sessions:
        volume = sum(
            (log.weight_kg or 0) * (log.reps or 0)
            for log in session.sets
            if log.completed
        )
        total_volume += volume
        year, week, _ = session.started_at.isocalendar()
        key = f"{year}-W{week:02d}"
        bucket = by_week.setdefault(key, {"week": key, "sessions": 0, "volume_kg": 0.0})
        bucket["sessions"] += 1
        bucket["volume_kg"] += volume

    durations = [item.duration_min for item in sessions if item.duration_min]
    profile = db.get(Profile, user_id)
    planned = (profile.weekly_days or 3) * weeks if profile else weeks * 3

    return {
        "sessions": len(sessions),
        "completion_rate": round(min(1.0, len(sessions) / planned), 2) if planned else 0,
        "total_volume_kg": round(total_volume, 1),
        "avg_duration_min": round(sum(durations) / len(durations)) if durations else 0,
        "by_week": [by_week[key] for key in sorted(by_week)],
    }


@router.get("/{workout_id}")
def get_workout(workout_id: str, user_id: CurrentUser, db: DBSession):
    session = (
        db.execute(
            select(WorkoutSession)
            .options(selectinload(WorkoutSession.sets))
            .where(
                WorkoutSession.id == workout_id,
                WorkoutSession.user_id == user_id,
            )
        )
        .scalar_one_or_none()
    )
    if session is None:
        raise HTTPException(status_code=404, detail="训练记录不存在")
    return {
        "id": session.id,
        "program_day_id": session.program_day_id,
        "started_at": session.started_at.isoformat(),
        "finished_at": session.finished_at.isoformat() if session.finished_at else None,
        "duration_min": session.duration_min,
        "feeling": session.feeling,
        "notes": session.notes,
        "sets": [
            {
                "slug": item.exercise_slug,
                "set_index": item.set_index,
                "weight_kg": item.weight_kg,
                "reps": item.reps,
                "rpe": item.rpe,
                "completed": item.completed,
            }
            for item in session.sets
        ],
    }


@router.patch("/{workout_id}")
def update_workout(
    workout_id: str,
    payload: WorkoutIn,
    user_id: CurrentUser,
    db: DBSession,
):
    session = (
        db.execute(
            select(WorkoutSession)
            .options(selectinload(WorkoutSession.sets))
            .where(
                WorkoutSession.id == workout_id,
                WorkoutSession.user_id == user_id,
            )
        )
        .scalar_one_or_none()
    )
    if session is None:
        raise HTTPException(status_code=404, detail="训练记录不存在")

    started_at = _parse_dt(payload.started_at)
    if started_at is None:
        raise HTTPException(status_code=400, detail="started_at 必填")
    finished_at = _parse_dt(payload.finished_at)
    _validate_slugs(db, payload.sets)
    program_day_id = _owned_program_day_id(db, user_id, payload.program_day_id)
    duration = (
        max(0, int((finished_at - started_at).total_seconds() / 60))
        if finished_at
        else None
    )
    session.started_at = started_at
    session.finished_at = finished_at
    session.duration_min = duration
    if program_day_id is not None:
        session.program_day_id = program_day_id
    session.feeling = payload.feeling
    session.notes = payload.notes
    session.sets.clear()
    for item in payload.sets:
        session.sets.append(
            SetLog(
                exercise_slug=item.slug,
                set_index=item.set_index,
                weight_kg=item.weight_kg,
                reps=item.reps,
                rpe=item.rpe,
                completed=item.completed,
            )
        )
    db.commit()
    return {"id": session.id, "duration_min": duration}


@router.delete("/{workout_id}")
def delete_workout(workout_id: str, user_id: CurrentUser, db: DBSession):
    session = db.execute(
        select(WorkoutSession).where(
            WorkoutSession.id == workout_id,
            WorkoutSession.user_id == user_id,
        )
    ).scalar_one_or_none()
    if session is None:
        raise HTTPException(status_code=404, detail="训练记录不存在")
    db.delete(session)
    db.commit()
    return {"status": "deleted", "id": workout_id}
