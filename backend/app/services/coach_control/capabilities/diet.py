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
from ...food_text import (
    FoodResolution,
    food_log_context,
    meal_analysis,
    parse_food_date,
    parse_meal,
    resolve_food_text,
    rule_resolution_by_meal,
)
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
        refreshes=("diet", "review"),
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
        refreshes=("diet",),
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
        refreshes=("diet",),
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
        refreshes=("diet",),
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
        refreshes=("diet",),
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
    *,
    history_context: str | None = None,
    draft: dict | None = None,
) -> dict:
    draft = draft or {}
    context = food_log_context(message)
    parsed_date = parse_food_date(message)
    if parsed_date is None:
        raw_date = draft.get("date") or context["date"]
        parsed_date = (
            date.fromisoformat(raw_date)
            if isinstance(raw_date, str)
            else raw_date
        )
    analysis = meal_analysis(message)
    draft_text = str(draft.get("text") or "")
    draft_analysis = meal_analysis(draft_text) if draft_text else {}
    draft_meal = draft.get("meal")
    if not draft.get("items") and draft_analysis.get("meal"):
        # Old drafts stored only raw text; repair the meal from that text so a
        # stale lunch label cannot turn a dinner reference into lunch.
        draft_meal = draft_analysis["meal"]
    parsed_meal = analysis.get("meal") or draft_meal or context["meal"]
    groups = rule_resolution_by_meal(message)
    main_rules = None
    if analysis.get("mentions"):
        main_rules = groups.get(parsed_meal) or FoodResolution()
    blocked_names = [
        str(item.get("name") or "")
        for meal, resolution in groups.items()
        if meal != parsed_meal
        for item in resolution.items
    ]
    resolution = await resolve_food_text(
        db,
        user_id,
        message,
        meal=parsed_meal,
        target_date=parsed_date,
        history_context=history_context,
        draft=draft,
        rule_resolution=main_rules,
        blocked_names=blocked_names,
    )
    return {
        **resolution,
        "date": parsed_date.isoformat(),
        "meal": parsed_meal,
        "text": message,
        "meal_mentions": analysis.get("mentions")
        or ([draft.get("meal")] if draft.get("meal") else []),
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
