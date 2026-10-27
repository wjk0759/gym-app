from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
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
    if payload.client_id:
        existing = db.execute(
            select(WorkoutSession).where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.client_id == payload.client_id,
            )
        ).scalar_one_or_none()
        if existing is not None:
            return {
                "id": existing.id,
                "client_id": existing.client_id,
                "duration_min": existing.duration_min,
                "duplicate": True,
            }

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
        client_id=payload.client_id,
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
    try:
        db.commit()
    except IntegrityError:
        # A concurrent retry won the unique(user_id, client_id) race.
        db.rollback()
        existing = (
            db.execute(
                select(WorkoutSession).where(
                    WorkoutSession.user_id == user_id,
                    WorkoutSession.client_id == payload.client_id,
                )
            ).scalar_one_or_none()
            if payload.client_id
            else None
        )
        if existing is not None:
            return {
                "id": existing.id,
                "client_id": existing.client_id,
                "duration_min": existing.duration_min,
                "duplicate": True,
            }
        raise
    return {
        "id": session.id,
        "client_id": session.client_id,
        "duration_min": duration,
        "duplicate": False,
    }


@router.get("")
def list_workouts(
    user_id: CurrentUser,
    db: DBSession,
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    include_sets: bool = Query(default=False),
):
    query = select(WorkoutSession).where(WorkoutSession.user_id == user_id)
    if include_sets:
        query = query.options(selectinload(WorkoutSession.sets))
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
    rows_all = (
        db.execute(
            query.order_by(
                WorkoutSession.started_at.desc(), WorkoutSession.id.desc()
            )
            .offset(offset)
            .limit(limit + 1)
        )
        .scalars()
        .all()
    )
    has_more = len(rows_all) > limit
    rows = rows_all[:limit]
    set_counts: dict[str, int] = {}
    if rows and not include_sets:
        ids = [item.id for item in rows]
        set_counts = dict(
            db.execute(
                select(SetLog.session_id, func.count(SetLog.id))
                .where(SetLog.session_id.in_(ids))
                .group_by(SetLog.session_id)
            ).all()
        )
    items = []
    for item in rows:
        payload = {
            "id": item.id,
            "client_id": item.client_id,
            "program_day_id": item.program_day_id,
            "started_at": item.started_at.isoformat(),
            "finished_at": item.finished_at.isoformat() if item.finished_at else None,
            "duration_min": item.duration_min,
            "feeling": item.feeling,
            "notes": item.notes,
            "set_count": (
                len(item.sets) if include_sets else int(set_counts.get(item.id, 0))
            ),
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
    return {
        "items": items,
        "limit": limit,
        "offset": offset,
        "has_more": has_more,
    }


@router.get("/summary")
def summary(user_id: CurrentUser, db: DBSession, weeks: int = Query(default=4, ge=1, le=26)):
    since = datetime.now(timezone.utc) - timedelta(weeks=weeks)
    volume_expr = func.coalesce(
        func.sum(SetLog.weight_kg * SetLog.reps), 0.0
    )
    rows = db.execute(
        select(
            WorkoutSession.id,
            WorkoutSession.started_at,
            WorkoutSession.duration_min,
            volume_expr.label("volume"),
        )
        .select_from(WorkoutSession)
        .outerjoin(
            SetLog,
            (SetLog.session_id == WorkoutSession.id) & SetLog.completed.is_(True),
        )
        .where(
            WorkoutSession.user_id == user_id,
            WorkoutSession.started_at >= since,
        )
        .group_by(
            WorkoutSession.id,
            WorkoutSession.started_at,
            WorkoutSession.duration_min,
        )
    ).all()

    total_volume = 0.0
    by_week: dict[str, dict] = {}
    for session_id, started_at, duration_min, volume in rows:
        volume = float(volume or 0)
        total_volume += volume
        year, week, _ = started_at.isocalendar()
        key = f"{year}-W{week:02d}"
        bucket = by_week.setdefault(
            key, {"week": key, "sessions": 0, "volume_kg": 0.0}
        )
        bucket["sessions"] += 1
        bucket["volume_kg"] += volume

    sessions_count = len(rows)
    durations = [row[2] for row in rows if row[2]]
    profile = db.get(Profile, user_id)
    planned = (profile.weekly_days or 3) * weeks if profile else weeks * 3

    return {
        "sessions": sessions_count,
        "completion_rate": round(min(1.0, sessions_count / planned), 2)
        if planned
        else 0,
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
        "client_id": session.client_id,
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
