"""Diet logging capability.

The model never supplies calories. The server resolves the text, builds the
payload and writes the same FoodLog rows used by the rest of the app.
"""

from __future__ import annotations

from datetime import date

from sqlalchemy.orm import Session

from ...coach_actions.food_actions import (
    execute_log_food,
    execute_log_planned_meal,
    execute_skip_planned_meal,
    undo_log_food,
    undo_skip_planned_meal,
)
from ...coach_actions.schemas import (
    LogFoodPayload,
    LogPlannedMealPayload,
    SkipPlannedMealPayload,
)
from ...diet_swap import swap_planned_meal, undo_planned_meal
from ...food_text import food_log_context, parse_meal, resolve_food_text
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="diet.log_food",
        domain="diet",
        kind="write",
        title="记录饮食",
        description="把用户描述的食物解析成营养估算并写入饮食记录",
        requires_confirmation=True,
        undo=True,
        events=("FoodLogged",),
    )
)
LOG_PLANNED = register(
    Capability(
        id="diet.log_planned_meal",
        domain="diet",
        kind="write",
        title="记录计划餐",
        description="按当天饮食计划记录整餐",
        requires_confirmation=True,
        undo=True,
        events=("PlannedMealLogged",),
    )
)
SKIP_PLANNED = register(
    Capability(
        id="diet.skip_planned_meal",
        domain="diet",
        kind="write",
        title="跳过计划餐",
        description="把当天某一餐标记为主动跳过",
        requires_confirmation=True,
        undo=True,
        events=("PlannedMealSkipped",),
    )
)
RESTORE_PLANNED = register(
    Capability(
        id="diet.restore_planned_meal",
        domain="diet",
        kind="write",
        title="恢复计划餐",
        description="恢复被主动跳过的计划餐",
        requires_confirmation=True,
        undo=True,
        events=("PlannedMealRestored",),
    )
)
SWAP_MEAL = register(
    Capability(
        id="diet.swap_meal",
        domain="diet",
        kind="write",
        title="换一餐",
        description="在周计划里换掉某一餐",
        requires_confirmation=True,
        undo=True,
        events=("DietMealSwapped",),
    )
)


def resolve_planned(
    message: str,
    *,
    require_explicit_meal: bool = True,
) -> dict:
    context = food_log_context(message)
    meal = parse_meal(message)
    if require_explicit_meal and meal is None:
        return {
            "ready": False,
            "questions": ["你要处理哪一餐？早餐、午餐、晚餐还是加餐？"],
        }
    return {
        "ready": True,
        "payload": {
            "date": context["date"],
            "meal": meal or context["meal"],
        },
    }


async def resolve(
    db: Session,
    user_id: str,
    message: str,
) -> dict:
    context = food_log_context(message)
    resolution = await resolve_food_text(
        db,
        user_id,
        message,
        meal=context["meal"],
        target_date=context["date"],
    )
    return {
        **resolution,
        "date": context["date"],
        "meal": context["meal"],
        "text": message,
    }


def execute(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    data = LogFoodPayload.model_validate(payload)
    return execute_log_food(db, user_id, action_id, data)


def undo(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    return undo_log_food(
        db,
        user_id,
        action_id,
        LogFoodPayload.model_validate(payload),
    )


def execute_planned(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    return execute_log_planned_meal(
        db,
        user_id,
        action_id,
        LogPlannedMealPayload.model_validate(payload),
    )


def undo_planned(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    return undo_log_food(
        db,
        user_id,
        action_id,
        LogFoodPayload.model_validate(
            {
                "date": payload.get("date"),
                "meal": payload.get("meal"),
                "items": [
                    {
                        "name": "计划餐",
                        "grams": 0,
                        "kcal": 0,
                        "protein_g": 0,
                        "carbs_g": 0,
                        "fat_g": 0,
                    }
                ],
            }
        ),
    )


def execute_skip(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    return execute_skip_planned_meal(
        db,
        user_id,
        action_id,
        SkipPlannedMealPayload.model_validate(payload),
    )


def undo_skip(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    return undo_skip_planned_meal(
        db,
        user_id,
        action_id,
        SkipPlannedMealPayload.model_validate(payload),
    )


def execute_restore(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    return undo_skip_planned_meal(
        db,
        user_id,
        action_id,
        SkipPlannedMealPayload.model_validate(payload),
    )


def execute_swap(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    return swap_planned_meal(
        db,
        user_id,
        date.fromisoformat(str(payload["date"])),
        str(payload["meal"]),
    )


def undo_swap(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    return undo_planned_meal(
        db,
        user_id,
        date.fromisoformat(str(payload["date"])),
        str(payload["meal"]),
    )


def undo_restore(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    return execute_skip_planned_meal(
        db,
        user_id,
        action_id,
        SkipPlannedMealPayload.model_validate(payload),
    )
