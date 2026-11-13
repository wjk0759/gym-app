from __future__ import annotations

from datetime import date, datetime, time, timezone
from uuid import uuid4
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import FoodLog
from ..coach_context import today_nutrition_context
from ..diet import ensure_meal_macros
from ..meal_plans import get_day
from .registry import ActionSpec, register
from .schemas import (
    DeleteFoodLogPayload,
    LogFoodPayload,
    LogPlannedMealPayload,
    UpdateFoodLogPayload,
)

MEAL_HOUR = {
    "breakfast": 8,
    "lunch": 12,
    "dinner": 18,
    "snack": 15,
}
DIET_TZ = ZoneInfo("Asia/Shanghai")


def _meal_time(day: date, meal: str) -> datetime:
    local = datetime.combine(
        day,
        time(hour=MEAL_HOUR.get(meal, 12)),
        tzinfo=DIET_TZ,
    )
    return local.astimezone(timezone.utc)


def _food_log_payload(item: FoodLog) -> dict:
    return {
        "client_id": item.client_id,
        "logged_at": item.logged_at.isoformat(),
        "meal": item.meal,
        "food_name": item.food_name,
        "grams": item.grams,
        "kcal": item.kcal,
        "protein": item.protein,
        "carbs": item.carbs,
        "fat": item.fat,
        "fiber": item.fiber or 0,
        "plan_date": item.plan_date.isoformat() if item.plan_date else None,
        "plan_meal": item.plan_meal,
        "source": item.source,
        "source_action_id": item.source_action_id,
        "source_group_id": item.source_group_id,
    }


def _nutrition(db: Session, user_id: str, day: date) -> dict:
    return today_nutrition_context(db, user_id, day)


def execute_log_food(
    db: Session,
    user_id: str,
    action_id: str,
    payload: LogFoodPayload,
) -> dict:
    group_id = str(uuid4())
    created: list[FoodLog] = []
    for item in payload.items:
        log = FoodLog(
            user_id=user_id,
            client_id=str(uuid4()),
            logged_at=_meal_time(payload.date, payload.meal),
            meal=payload.meal,
            food_name=item.name,
            grams=item.grams,
            kcal=item.kcal,
            protein=item.protein_g,
            carbs=item.carbs_g,
            fat=item.fat_g,
            fiber=item.fiber_g,
            source="coach",
            source_action_id=action_id,
            source_group_id=group_id,
            estimate_confidence=item.confidence,
        )
        db.add(log)
        created.append(log)
    db.flush()
    return {
        "group_id": group_id,
        "created_logs": [_food_log_payload(item) for item in created],
        "today_nutrition": _nutrition(db, user_id, payload.date),
    }


def execute_log_planned_meal(
    db: Session,
    user_id: str,
    action_id: str,
    payload: LogPlannedMealPayload,
) -> dict:
    record = get_day(db, user_id, payload.date)
    if record is None or not record.plan:
        raise LookupError("这一天没有饮食计划")
    plan = ensure_meal_macros(record.plan)
    meal = next(
        (
            item
            for item in plan.get("meals", [])
            if isinstance(item, dict) and item.get("meal") == payload.meal
        ),
        None,
    )
    if meal is None:
        raise LookupError("计划里没有这一餐")

    existing = db.execute(
        select(FoodLog).where(
            FoodLog.user_id == user_id,
            FoodLog.plan_date == payload.date,
            FoodLog.plan_meal == payload.meal,
        )
    ).scalar_one_or_none()
    if existing is not None:
        return {
            "already_logged": True,
            "created_logs": [_food_log_payload(existing)],
            "today_nutrition": _nutrition(db, user_id, payload.date),
        }

    group_id = str(uuid4())
    log = FoodLog(
        user_id=user_id,
        client_id=str(uuid4()),
        logged_at=_meal_time(payload.date, payload.meal),
        meal=payload.meal,
        food_name=f"{meal.get('name') or payload.meal}（计划餐）",
        grams=0,
        kcal=float(meal.get("kcal") or 0),
        protein=float(meal.get("protein_g") or 0),
        carbs=float(meal.get("carbs_g") or 0),
        fat=float(meal.get("fat_g") or 0),
        fiber=0,
        plan_date=payload.date,
        plan_meal=payload.meal,
        source="coach",
        source_action_id=action_id,
        source_group_id=group_id,
    )
    db.add(log)
    db.flush()
    return {
        "group_id": group_id,
        "created_logs": [_food_log_payload(log)],
        "today_nutrition": _nutrition(db, user_id, payload.date),
    }


def execute_update_food_log(
    db: Session,
    user_id: str,
    action_id: str,
    payload: UpdateFoodLogPayload,
) -> dict:
    log = db.execute(
        select(FoodLog).where(
            FoodLog.user_id == user_id,
            FoodLog.client_id == payload.client_id,
        )
    ).scalar_one_or_none()
    if log is None:
        raise LookupError("饮食记录不存在")
    values = payload.model_dump(exclude_none=True, exclude={"client_id"})
    if "date" in values:
        log.logged_at = _meal_time(values.pop("date"), values.get("meal", log.meal))
    if "meal" in values:
        log.meal = values.pop("meal")
    field_map = {
        "food_name": "food_name",
        "grams": "grams",
        "kcal": "kcal",
        "protein_g": "protein",
        "carbs_g": "carbs",
        "fat_g": "fat",
        "fiber_g": "fiber",
    }
    for field, value in values.items():
        attribute = field_map.get(field)
        if attribute is not None:
            setattr(log, attribute, value)
    if log.plan_date is not None:
        log.plan_date = log.logged_at.astimezone(DIET_TZ).date()
        log.plan_meal = log.meal
    db.flush()
    return {
        "updated_log": _food_log_payload(log),
        "today_nutrition": _nutrition(
            db, user_id, log.logged_at.astimezone(DIET_TZ).date()
        ),
    }


def execute_delete_food_log(
    db: Session,
    user_id: str,
    action_id: str,
    payload: DeleteFoodLogPayload,
) -> dict:
    log = db.execute(
        select(FoodLog).where(
            FoodLog.user_id == user_id,
            FoodLog.client_id == payload.client_id,
        )
    ).scalar_one_or_none()
    if log is None:
        raise LookupError("饮食记录不存在")
    day = log.logged_at.astimezone(DIET_TZ).date()
    snapshot = _food_log_payload(log)
    db.delete(log)
    db.flush()
    return {
        "deleted_log": snapshot,
        "today_nutrition": _nutrition(db, user_id, day),
    }


def undo_log_food(
    db: Session,
    user_id: str,
    action_id: str,
    payload,
) -> dict:
    logs = (
        db.execute(
            select(FoodLog).where(
                FoodLog.user_id == user_id,
                FoodLog.source_action_id == action_id,
            )
        )
        .scalars()
        .all()
    )
    day = payload.date
    for log in logs:
        db.delete(log)
    db.flush()
    return {
        "deleted": len(logs),
        "today_nutrition": _nutrition(db, user_id, day),
    }


register(
    "log_food",
    ActionSpec(
        payload_model=LogFoodPayload,
        execute=execute_log_food,
        undo=undo_log_food,
    ),
)
register(
    "log_planned_meal",
    ActionSpec(
        payload_model=LogPlannedMealPayload,
        execute=execute_log_planned_meal,
        undo=undo_log_food,
    ),
)
register(
    "update_food_log",
    ActionSpec(
        payload_model=UpdateFoodLogPayload,
        execute=execute_update_food_log,
    ),
)
register(
    "delete_food_log",
    ActionSpec(
        payload_model=DeleteFoodLogPayload,
        execute=execute_delete_food_log,
    ),
)
