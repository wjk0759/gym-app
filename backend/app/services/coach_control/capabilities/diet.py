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
    parse_amount_grams,
    parse_food_date,
    parse_meal,
    resolve_food_rules,
    resolve_food_text,
    rule_resolution_by_meal,
    split_meal_clauses,
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
        refreshes=("diet", "review"),
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
        refreshes=("diet", "review"),
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
        refreshes=("diet", "review"),
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
        refreshes=("diet", "review"),
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


MEAL_ORDER = {"breakfast": 0, "lunch": 1, "snack": 2, "dinner": 3}


def _draft_groups(draft: dict | None) -> dict[str, dict]:
    """Index a pending draft by meal, including the legacy single-meal shape."""
    groups: dict[str, dict] = {}
    for group in (draft or {}).get("meals") or []:
        if not isinstance(group, dict):
            continue
        meal = str(group.get("meal") or "").strip()
        if meal:
            groups[meal] = group
    legacy_meal = str((draft or {}).get("meal") or "").strip()
    if legacy_meal and legacy_meal not in groups:
        groups[legacy_meal] = dict(draft or {})
    return groups


def _single_meal_result(result: dict, meal: str, day: date) -> dict:
    return {
        **result,
        "date": day.isoformat(),
        "meal": meal,
    }


async def resolve(
    db: Session,
    user_id: str,
    message: str,
    *,
    history_context: str | None = None,
    draft: dict | None = None,
    default_meal: str | None = None,
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
    draft_groups = _draft_groups(draft)

    # A pending draft may already carry the meal label. A short answer such as
    # "250ml" has no label of its own, so bind it to the only draft group.
    inferred_draft_meal = (
        next(iter(draft_groups)) if len(draft_groups) == 1 else None
    )
    clauses = split_meal_clauses(message)
    if (
        inferred_draft_meal is None
        and len(clauses) == 1
        and clauses[0][0] is None
        and parse_amount_grams(message) is not None
    ):
        missing_groups = [
            meal
            for meal, group in draft_groups.items()
            if group.get("missing_slots")
        ]
        if len(missing_groups) == 1:
            inferred_draft_meal = missing_groups[0]
    explicit = analysis.get("explicit") or []
    parsed_meal = (
        explicit[0]
        if explicit
        else analysis.get("meal")
        or inferred_draft_meal
        or default_meal
        or context["meal"]
    )

    meal_results: list[dict] = []
    for clause_meal, clause_text in clauses:
        target_meal = (
            clause_meal
            or inferred_draft_meal
            or (parsed_meal if len(clauses) == 1 else None)
            or default_meal
            or context["meal"]
        )
        group_draft = draft_groups.get(target_meal) or {}
        group_rules = resolve_food_rules(clause_text)
        if not group_rules.items and not group_rules.questions and not (
            group_draft.get("items") or group_draft.get("missing_slots")
        ):
            continue
        group_date = parse_food_date(clause_text) or parsed_date
        result = await resolve_food_text(
            db,
            user_id,
            clause_text,
            meal=target_meal,
            target_date=group_date,
            history_context=history_context,
            draft=group_draft,
            rule_resolution=group_rules,
        )
        if not result.get("items") and not result.get("questions"):
            continue
        meal_results.append(
            _single_meal_result(result, target_meal, group_date)
        )

    # Keep meals that were already on the pending card/draft. A user adding
    # dinner to a lunch card should get one two-meal card, not lose lunch.
    result_meals = {str(group.get("meal") or "") for group in meal_results}
    for meal, group in draft_groups.items():
        if meal in result_meals:
            continue
        items = [
            dict(item)
            for item in group.get("items") or []
            if isinstance(item, dict)
        ]
        if not items:
            continue
        group_date = parsed_date
        raw_date = group.get("date")
        if isinstance(raw_date, str):
            try:
                group_date = date.fromisoformat(raw_date)
            except ValueError:
                group_date = parsed_date
        meal_results.append(
            {
                "meal": meal,
                "date": group_date.isoformat(),
                "items": items,
                "questions": [],
                "missing_slots": [],
                "source": "draft",
                "confidence": float(group.get("confidence") or 0.7),
            }
        )
    meal_results.sort(key=lambda group: MEAL_ORDER.get(str(group.get("meal")), 9))

    if meal_results:
        if len(meal_results) == 1:
            only = meal_results[0]
            return {
                **only,
                "text": message,
                "meal_mentions": analysis.get("mentions")
                or ([only["meal"]] if only.get("meal") else []),
            }
        flat_items = [
            item for group in meal_results for item in group.get("items") or []
        ]
        questions = [
            question
            for group in meal_results
            for question in group.get("questions") or []
        ]
        missing_slots = [
            slot
            for group in meal_results
            for slot in group.get("missing_slots") or []
        ]
        return {
            "meals": meal_results,
            "date": parsed_date.isoformat(),
            "meal": meal_results[0]["meal"],
            "items": flat_items,
            "questions": questions,
            "missing_slots": missing_slots,
            "source": "mixed",
            "confidence": round(
                sum(float(group.get("confidence") or 0) for group in meal_results)
                / len(meal_results),
                2,
            ),
            "text": message,
            "meal_mentions": analysis.get("mentions") or [],
        }

    # No explicit meal clause produced food: keep the old single-meal path.
    parsed_meal = analysis.get("meal") or inferred_draft_meal or context["meal"]
    groups = rule_resolution_by_meal(message)
    main_rules = None
    if analysis.get("mentions"):
        main_rules = groups.get(parsed_meal) or groups.get("__default__") or FoodResolution()
    resolution = await resolve_food_text(
        db,
        user_id,
        message,
        meal=parsed_meal,
        target_date=parsed_date,
        history_context=history_context,
        draft=draft,
        rule_resolution=main_rules,
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
