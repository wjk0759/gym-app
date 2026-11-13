from __future__ import annotations

from datetime import datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import Exercise, Program, ProgramDay, SetLog, WorkoutSession
from ..training_stage import refresh_training_stage
from .registry import ActionSpec, register
from .schemas import LogWorkoutPayload

DIET_TZ = ZoneInfo("Asia/Shanghai")


def _owned_day_id(db: Session, user_id: str, day_id: str | None) -> str | None:
    if not day_id:
        return None
    return db.execute(
        select(ProgramDay.id)
        .join(Program, Program.id == ProgramDay.program_id)
        .where(ProgramDay.id == day_id, Program.user_id == user_id)
    ).scalar_one_or_none()


def _session_payload(session: WorkoutSession) -> dict:
    return {
        "id": session.id,
        "client_id": session.client_id,
        "started_at": session.started_at.isoformat(),
        "finished_at": session.finished_at.isoformat()
        if session.finished_at
        else None,
        "duration_min": session.duration_min,
        "source": session.source,
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


def execute_log_workout(
    db: Session,
    user_id: str,
    action_id: str,
    payload: LogWorkoutPayload,
) -> dict:
    today = datetime.now(DIET_TZ).date()
    if payload.date > today:
        raise ValueError("不能记录未来日期的训练")

    existing = db.execute(
        select(WorkoutSession).where(
            WorkoutSession.user_id == user_id,
            WorkoutSession.client_id == action_id,
        )
    ).scalar_one_or_none()
    if existing is not None:
        return {"already_logged": True, "created_workout": _session_payload(existing)}

    slugs = {item.slug for item in payload.sets}
    if slugs:
        known = {
            row[0]
            for row in db.execute(
                select(Exercise.slug).where(Exercise.slug.in_(slugs))
            ).all()
        }
        missing = slugs - known
        if missing:
            raise ValueError(f"动作不存在：{', '.join(sorted(missing))}")

    start_local = datetime.combine(
        payload.date,
        time(hour=18 if payload.kind == "strength" else 8),
        tzinfo=DIET_TZ,
    )
    started_at = start_local.astimezone(timezone.utc)
    finished_at = started_at + timedelta(minutes=max(1, payload.duration_minutes))
    session = WorkoutSession(
        user_id=user_id,
        client_id=action_id,
        program_day_id=_owned_day_id(db, user_id, payload.program_day_id),
        source="coach",
        started_at=started_at,
        finished_at=finished_at,
        duration_min=payload.duration_minutes,
        feeling=None,
        notes=payload.notes or payload.title,
    )
    # WorkoutSession has no day_title column; the iOS title is represented by
    # notes when the coach creates a manual/cardio entry.
    for index, item in enumerate(payload.sets, start=1):
        session.sets.append(
            SetLog(
                exercise_slug=item.slug,
                set_index=item.set_index or index,
                weight_kg=item.weight_kg,
                reps=item.reps,
                rpe=item.rpe,
                completed=item.completed,
            )
        )
    db.add(session)
    db.flush()
    refresh_training_stage(db, user_id)
    db.flush()
    return {
        "created_workout": _session_payload(session),
        "title": payload.title,
        "kind": payload.kind,
    }


def undo_log_workout(
    db: Session,
    user_id: str,
    action_id: str,
    payload,
) -> dict:
    session = db.execute(
        select(WorkoutSession).where(
            WorkoutSession.user_id == user_id,
            WorkoutSession.client_id == action_id,
        )
    ).scalar_one_or_none()
    if session is None:
        raise LookupError("训练记录不存在")
    db.delete(session)
    db.flush()
    refresh_training_stage(db, user_id)
    return {"deleted": True, "client_id": action_id}


register(
    "log_workout",
    ActionSpec(
        payload_model=LogWorkoutPayload,
        execute=execute_log_workout,
        undo=undo_log_workout,
    ),
)
