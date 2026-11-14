"""Edit or delete already logged food and workout records.

These used to be LLM-selected legacy actions. The control plane resolves the
target from the user's message and the existing records, so the confirmation
card shows exactly what will change.
"""

from __future__ import annotations

import re
from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from ....models import Exercise, FoodLog, ProgramDay, WorkoutSession
from ...coach_actions.food_actions import (
    execute_delete_food_log,
    execute_update_food_log,
    undo_delete_food_log,
    undo_update_food_log,
)
from ...coach_actions.schemas import (
    DeleteFoodLogPayload,
    DeleteWorkoutPayload,
    UpdateFoodLogPayload,
    UpdateWorkoutPayload,
    WorkoutSetIn,
)
from ...coach_actions.workout_actions import (
    execute_delete_workout as _execute_delete_workout,
)
from ...coach_actions.workout_actions import (
    execute_update_workout as _execute_update_workout,
)
from ...coach_actions.workout_actions import (
    undo_delete_workout as _undo_delete_workout,
)
from ...coach_actions.workout_actions import (
    undo_update_workout as _undo_update_workout,
)
from ...food_text import DIET_TZ, parse_food_date, parse_meal
from ..registry import Capability, register

UPDATE_FOOD = register(
    Capability(
        id="diet.update_log",
        domain="diet",
        kind="write",
        title="修改饮食记录",
        description="修改已经记录的食物份量或营养",
        requires_confirmation=True,
        undo=True,
        events=("FoodLogUpdated",),
        refreshes=("diet", "review"),
    )
)
DELETE_FOOD = register(
    Capability(
        id="diet.delete_log",
        domain="diet",
        kind="write",
        title="删除饮食记录",
        description="删除已经记录的一条食物",
        requires_confirmation=True,
        undo=True,
        events=("FoodLogDeleted",),
        refreshes=("diet", "review"),
    )
)
UPDATE_WORKOUT = register(
    Capability(
        id="training.update_workout",
        domain="training",
        kind="write",
        title="修改训练记录",
        description="修改已经记录的训练时长、备注或动作重量",
        requires_confirmation=True,
        undo=True,
        events=("WorkoutUpdated",),
        refreshes=("workouts", "plan", "schedule", "review"),
    )
)
DELETE_WORKOUT = register(
    Capability(
        id="training.delete_workout",
        domain="training",
        kind="write",
        title="删除训练记录",
        description="删除一条已经记录的训练",
        requires_confirmation=True,
        undo=True,
        events=("WorkoutDeleted",),
        refreshes=("workouts", "plan", "schedule", "review"),
    )
)


def _local_day(text: str) -> date:
    return parse_food_date(text) or datetime.now(DIET_TZ).date()


def _day_bounds(day: date) -> tuple[datetime, datetime]:
    start = datetime.combine(day, time.min, tzinfo=DIET_TZ).astimezone(
        timezone.utc
    )
    return start, start + timedelta(days=1)


def _food_logs(
    db: Session,
    user_id: str,
    day: date,
    meal: str | None,
) -> list[FoodLog]:
    start, end = _day_bounds(day)
    statement = select(FoodLog).where(
        FoodLog.user_id == user_id,
        FoodLog.logged_at >= start,
        FoodLog.logged_at < end,
    )
    if meal:
        statement = statement.where(FoodLog.meal == meal)
    return list(
        db.execute(statement.order_by(FoodLog.logged_at.desc()))
        .scalars()
        .all()
    )


def _find_food_log(
    db: Session,
    user_id: str,
    message: str,
) -> tuple[FoodLog | None, str | None]:
    day = _local_day(message)
    meal = parse_meal(message)
    logs = _food_logs(db, user_id, day, meal)
    if not logs:
        return None, f"{day.month}月{day.day}日没有找到饮食记录。"
    named = [item for item in logs if item.food_name and item.food_name in message]
    if len(named) == 1:
        return named[0], None
    if len(named) > 1:
        names = "、".join(item.food_name for item in named[:4])
        return None, f"找到多条记录：{names}。请说得更具体一点。"
    if re.search(r"刚才|刚刚|这条|最后|上一个|最近", message):
        return logs[0], None
    if len(logs) == 1:
        return logs[0], None
    names = "、".join(item.food_name for item in logs[:4])
    return None, f"要改哪一条？{names}。"


def _number(text: str, pattern: str) -> float | None:
    match = re.search(pattern, text, flags=re.IGNORECASE)
    if match is None:
        return None
    return float(match.group(1))


def _food_updates(message: str, log: FoodLog) -> dict | None:
    grams = _number(message, r"(\d+(?:\.\d+)?)\s*(?:g|克)")
    kcal = _number(message, r"(\d+(?:\.\d+)?)\s*(?:kcal|千卡|大卡|卡)")
    protein = _number(message, r"蛋白(?:质)?\s*(\d+(?:\.\d+)?)\s*(?:g|克)")
    carbs = _number(message, r"碳水\s*(\d+(?:\.\d+)?)\s*(?:g|克)")
    fat = _number(message, r"脂肪\s*(\d+(?:\.\d+)?)\s*(?:g|克)")
    fiber = _number(message, r"纤维\s*(\d+(?:\.\d+)?)\s*(?:g|克)")
    if all(
        value is None
        for value in (grams, kcal, protein, carbs, fat, fiber)
    ):
        return None

    updates: dict[str, float] = {}
    if grams is not None:
        updates["grams"] = round(grams, 1)
    if kcal is not None:
        updates["kcal"] = round(kcal, 1)
    if protein is not None:
        updates["protein_g"] = round(protein, 1)
    if carbs is not None:
        updates["carbs_g"] = round(carbs, 1)
    if fat is not None:
        updates["fat_g"] = round(fat, 1)
    if fiber is not None:
        updates["fiber_g"] = round(fiber, 1)

    # If only grams changed, scale the existing nutrition so the record stays
    # internally consistent instead of showing the old calories.
    if (
        grams is not None
        and kcal is None
        and protein is None
        and carbs is None
        and fat is None
        and fiber is None
        and log.grams
        and log.grams > 0
    ):
        ratio = grams / float(log.grams)
        updates["kcal"] = round(float(log.kcal or 0) * ratio, 1)
        updates["protein_g"] = round(float(log.protein or 0) * ratio, 1)
        updates["carbs_g"] = round(float(log.carbs or 0) * ratio, 1)
        updates["fat_g"] = round(float(log.fat or 0) * ratio, 1)
        updates["fiber_g"] = round(float(log.fiber or 0) * ratio, 1)
    return updates


def resolve_update_food(db: Session, user_id: str, message: str) -> dict:
    log, error = _find_food_log(db, user_id, message)
    if log is None:
        return {"ready": False, "questions": [error or "没有找到要修改的记录。"]}
    updates = _food_updates(message, log)
    if updates is None:
        return {
            "ready": False,
            "questions": ["要改成多少克，或者多少 kcal？"],
        }
    payload = {
        "client_id": log.client_id,
        "date": log.logged_at.astimezone(DIET_TZ).date().isoformat(),
        "meal": log.meal,
        "food_name": log.food_name,
        **updates,
    }
    parts = []
    if "grams" in updates:
        parts.append(f"{updates['grams']:g}g")
    if "kcal" in updates:
        parts.append(f"{updates['kcal']:g}kcal")
    detail = " / ".join(parts) if parts else "新的营养值"
    return {
        "ready": True,
        "payload": payload,
        "summary": f"准备把「{log.food_name}」改成 {detail}。",
    }


def resolve_delete_food(db: Session, user_id: str, message: str) -> dict:
    log, error = _find_food_log(db, user_id, message)
    if log is None:
        return {"ready": False, "questions": [error or "没有找到要删除的记录。"]}
    return {
        "ready": True,
        "payload": {"client_id": log.client_id},
        "summary": f"准备删除「{log.food_name}」这条饮食记录。",
    }


def _workout_title(db: Session, session: WorkoutSession) -> str:
    if session.program_day_id:
        day = db.get(ProgramDay, session.program_day_id)
        if day is not None:
            return day.title
    return session.notes or "训练"


def _workouts(
    db: Session,
    user_id: str,
    day: date,
) -> list[WorkoutSession]:
    start, end = _day_bounds(day)
    return list(
        db.execute(
            select(WorkoutSession)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.started_at >= start,
                WorkoutSession.started_at < end,
            )
            .order_by(WorkoutSession.started_at.desc())
        )
        .scalars()
        .all()
    )


def _find_workout(
    db: Session,
    user_id: str,
    message: str,
) -> tuple[WorkoutSession | None, str | None]:
    day = _local_day(message)
    sessions = _workouts(db, user_id, day)
    if not sessions:
        return None, f"{day.month}月{day.day}日没有找到训练记录。"
    named = [
        item
        for item in sessions
        if _workout_title(db, item) in message or (item.notes and item.notes in message)
    ]
    if len(named) == 1:
        return named[0], None
    if len(named) > 1:
        return None, "当天有多条训练记录，请说得更具体一点。"
    if re.search(r"刚才|刚刚|这条|最后|上一个|最近", message):
        return sessions[0], None
    if len(sessions) == 1:
        return sessions[0], None
    return None, "要改哪一条训练记录？可以说训练名称。"


def _workout_updates(
    db: Session,
    session: WorkoutSession,
    message: str,
) -> tuple[dict, str | None]:
    updates: dict = {}
    minutes = _number(message, r"(\d{2,3})\s*(?:分钟|min)")
    if minutes is not None:
        updates["duration_minutes"] = max(1, min(300, int(minutes)))

    weight = _number(message, r"(\d+(?:\.\d+)?)\s*(?:kg|公斤)")
    if weight is not None:
        set_rows = list(session.sets)
        if len(set_rows) == 1:
            updates["sets"] = [
                WorkoutSetIn(
                    slug=set_rows[0].exercise_slug,
                    set_index=set_rows[0].set_index,
                    weight_kg=round(weight, 1),
                    reps=set_rows[0].reps or 0,
                    rpe=set_rows[0].rpe or 7,
                    completed=set_rows[0].completed,
                )
            ]
        else:
            names = {
                row.exercise_slug: db.get(Exercise, row.exercise_slug)
                for row in set_rows
            }
            matched = [
                row
                for row in set_rows
                if names[row.exercise_slug] is not None
                and (names[row.exercise_slug].name_zh or "") in message
            ]
            if len(matched) != 1:
                return updates, "要改哪个动作的重量？"
            updates["sets"] = [
                WorkoutSetIn(
                    slug=row.exercise_slug,
                    set_index=row.set_index,
                    weight_kg=round(weight, 1)
                    if row.exercise_slug == matched[0].exercise_slug
                    else (row.weight_kg or 0),
                    reps=row.reps or 0,
                    rpe=row.rpe or 7,
                    completed=row.completed,
                )
                for row in set_rows
            ]
    if not updates:
        return {}, "要改时长、重量还是备注？"
    return updates, None


def resolve_update_workout(db: Session, user_id: str, message: str) -> dict:
    session, error = _find_workout(db, user_id, message)
    if session is None:
        return {"ready": False, "questions": [error or "没有找到训练记录。"]}
    updates, update_error = _workout_updates(db, session, message)
    if update_error:
        return {"ready": False, "questions": [update_error]}
    payload = {"session_id": session.id, **updates}
    title = _workout_title(db, session)
    detail = []
    if "duration_minutes" in updates:
        detail.append(f"{updates['duration_minutes']} 分钟")
    if "sets" in updates:
        detail.append("动作重量")
    return {
        "ready": True,
        "payload": payload,
        "summary": f"准备修改「{title}」：{'、'.join(detail)}。",
    }


def resolve_delete_workout(db: Session, user_id: str, message: str) -> dict:
    session, error = _find_workout(db, user_id, message)
    if session is None:
        return {"ready": False, "questions": [error or "没有找到训练记录。"]}
    return {
        "ready": True,
        "payload": {"session_id": session.id},
        "summary": f"准备删除「{_workout_title(db, session)}」这条训练记录。",
    }


def execute_update_food(db: Session, user_id: str, action_id: str, payload: dict) -> dict:
    return execute_update_food_log(
        db, user_id, action_id, UpdateFoodLogPayload.model_validate(payload)
    )


def undo_update_food(db: Session, user_id: str, action_id: str, payload: dict) -> dict:
    return undo_update_food_log(
        db, user_id, action_id, UpdateFoodLogPayload.model_validate(payload)
    )


def execute_delete_food(db: Session, user_id: str, action_id: str, payload: dict) -> dict:
    return execute_delete_food_log(
        db, user_id, action_id, DeleteFoodLogPayload.model_validate(payload)
    )


def undo_delete_food(db: Session, user_id: str, action_id: str, payload: dict) -> dict:
    return undo_delete_food_log(
        db, user_id, action_id, DeleteFoodLogPayload.model_validate(payload)
    )


def execute_update_workout(
    db: Session, user_id: str, action_id: str, payload: dict
) -> dict:
    return _execute_update_workout(
        db, user_id, action_id, UpdateWorkoutPayload.model_validate(payload)
    )


def undo_update_workout(
    db: Session, user_id: str, action_id: str, payload: dict
) -> dict:
    return _undo_update_workout(
        db, user_id, action_id, UpdateWorkoutPayload.model_validate(payload)
    )


def execute_delete_workout(
    db: Session, user_id: str, action_id: str, payload: dict
) -> dict:
    return _execute_delete_workout(
        db, user_id, action_id, DeleteWorkoutPayload.model_validate(payload)
    )


def undo_delete_workout(
    db: Session, user_id: str, action_id: str, payload: dict
) -> dict:
    return _undo_delete_workout(
        db, user_id, action_id, DeleteWorkoutPayload.model_validate(payload)
    )
