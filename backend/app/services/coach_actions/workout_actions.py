from __future__ import annotations

from datetime import datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import (
    AgentActionEvent,
    Exercise,
    Program,
    ProgramDay,
    SetLog,
    WorkoutSession,
)
from ..training_stage import refresh_training_stage
from .registry import ActionSpec, register
from .schemas import (
    DeleteWorkoutPayload,
    LogWorkoutPayload,
    UpdateWorkoutPayload,
    WorkoutSetIn,
)

DIET_TZ = ZoneInfo("Asia/Shanghai")


def _owned_day_id(db: Session, user_id: str, day_id: str | None) -> str | None:
    if not day_id:
        return None
    return db.execute(
        select(ProgramDay.id)
        .join(Program, Program.id == ProgramDay.program_id)
        .where(ProgramDay.id == day_id, Program.user_id == user_id)
    ).scalar_one_or_none()


def _validate_slugs(db: Session, sets: list[WorkoutSetIn]) -> None:
    slugs = {item.slug for item in sets}
    if not slugs:
        return
    known = {
        row[0]
        for row in db.execute(
            select(Exercise.slug).where(Exercise.slug.in_(slugs))
        ).all()
    }
    missing = slugs - known
    if missing:
        raise ValueError(f"动作不存在：{', '.join(sorted(missing))}")


def _owned_session(
    db: Session, user_id: str, session_id: str
) -> WorkoutSession:
    session = db.execute(
        select(WorkoutSession).where(
            WorkoutSession.id == session_id,
            WorkoutSession.user_id == user_id,
        )
    ).scalar_one_or_none()
    if session is None:
        raise LookupError("训练记录不存在")
    return session


def _session_payload(session: WorkoutSession) -> dict:
    return {
        "id": session.id,
        "client_id": session.client_id,
        "started_at": session.started_at.isoformat(),
        "finished_at": session.finished_at.isoformat()
        if session.finished_at
        else None,
        "duration_min": session.duration_min,
        "feeling": session.feeling,
        "notes": session.notes,
        "program_day_id": session.program_day_id,
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


def _event_result(db: Session, user_id: str, action_id: str) -> dict:
    event = db.execute(
        select(AgentActionEvent).where(
            AgentActionEvent.user_id == user_id,
            AgentActionEvent.action_id == action_id,
        )
    ).scalar_one_or_none()
    if event is None or not isinstance(event.detail, dict):
        raise LookupError("操作记录不存在")
    result = event.detail.get("result")
    return result if isinstance(result, dict) else {}


def _apply_session_snapshot(
    db: Session,
    session: WorkoutSession,
    snapshot: dict,
) -> None:
    session.started_at = datetime.fromisoformat(snapshot["started_at"])
    session.finished_at = (
        datetime.fromisoformat(snapshot["finished_at"])
        if snapshot.get("finished_at")
        else None
    )
    session.duration_min = snapshot.get("duration_min")
    session.feeling = snapshot.get("feeling")
    session.notes = snapshot.get("notes")
    session.program_day_id = snapshot.get("program_day_id")
    session.sets.clear()
    db.flush()
    for index, item in enumerate(snapshot.get("sets") or [], start=1):
        session.sets.append(
            SetLog(
                exercise_slug=item["slug"],
                set_index=int(item.get("set_index") or index),
                weight_kg=float(item.get("weight_kg") or 0),
                reps=int(item.get("reps") or 0),
                rpe=float(item.get("rpe") or 7),
                completed=bool(item.get("completed", True)),
            )
        )


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

    _validate_slugs(db, payload.sets)

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


def execute_update_workout(
    db: Session,
    user_id: str,
    action_id: str,
    payload: UpdateWorkoutPayload,
) -> dict:
    session = _owned_session(db, user_id, payload.session_id)
    before = _session_payload(session)
    if payload.date is not None:
        if payload.date > datetime.now(DIET_TZ).date():
            raise ValueError("不能把训练改到未来日期")
        start_local = datetime.combine(
            payload.date,
            time(hour=18),
            tzinfo=DIET_TZ,
        )
        session.started_at = start_local.astimezone(timezone.utc)
    if payload.duration_minutes is not None:
        session.duration_min = payload.duration_minutes
        session.finished_at = session.started_at + timedelta(
            minutes=payload.duration_minutes
        )
    if payload.notes is not None:
        session.notes = payload.notes
    if payload.sets is not None:
        _validate_slugs(db, payload.sets)
        session.sets.clear()
        # Flush deletes before reusing the same (session, slug, set_index)
        # unique keys for the replacement rows.
        db.flush()
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
    db.flush()
    refresh_training_stage(db, user_id)
    return {
        "before_workout": before,
        "updated_workout": _session_payload(session),
    }


def execute_delete_workout(
    db: Session,
    user_id: str,
    action_id: str,
    payload: DeleteWorkoutPayload,
) -> dict:
    session = _owned_session(db, user_id, payload.session_id)
    snapshot = _session_payload(session)
    db.delete(session)
    db.flush()
    refresh_training_stage(db, user_id)
    return {"deleted_workout": snapshot}


def undo_update_workout(
    db: Session,
    user_id: str,
    action_id: str,
    payload: UpdateWorkoutPayload,
) -> dict:
    before = _event_result(db, user_id, action_id).get("before_workout")
    if not isinstance(before, dict):
        raise LookupError("没有可撤销的训练修改")
    session = _owned_session(db, user_id, payload.session_id)
    _apply_session_snapshot(db, session, before)
    db.flush()
    refresh_training_stage(db, user_id)
    return {"restored": True, "updated_workout": _session_payload(session)}


def undo_delete_workout(
    db: Session,
    user_id: str,
    action_id: str,
    payload: DeleteWorkoutPayload,
) -> dict:
    snapshot = _event_result(db, user_id, action_id).get("deleted_workout")
    if not isinstance(snapshot, dict):
        raise LookupError("没有可恢复的训练记录")
    session = db.get(WorkoutSession, snapshot["id"])
    if session is not None and session.user_id != user_id:
        raise LookupError("训练记录不存在")
    if session is None:
        session = WorkoutSession(
            id=snapshot["id"],
            user_id=user_id,
            client_id=snapshot.get("client_id"),
            source=snapshot.get("source") or "coach",
            started_at=datetime.fromisoformat(snapshot["started_at"]),
        )
        db.add(session)
    _apply_session_snapshot(db, session, snapshot)
    db.flush()
    refresh_training_stage(db, user_id)
    return {"restored": True, "created_workout": _session_payload(session)}


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
register(
    "update_workout_log",
    ActionSpec(
        payload_model=UpdateWorkoutPayload,
        execute=execute_update_workout,
        undo=undo_update_workout,
    ),
)
register(
    "delete_workout_log",
    ActionSpec(
        payload_model=DeleteWorkoutPayload,
        execute=execute_delete_workout,
        undo=undo_delete_workout,
    ),
)
