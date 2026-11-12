"""Deterministic single-meal replacement.

Weekly AI plans already contain several variations of the same meal. Swapping
with another day's meal avoids an LLM call and keeps the user's day targets
unchanged: only the dish changes, the calorie/macro slot stays the same.
"""

from __future__ import annotations

from datetime import date

from sqlalchemy.orm import Session

from .diet import _fallback_dish, ensure_meal_macros
from .meal_plans import get_day, list_week, week_start_for

MEAL_KEYS = {"breakfast", "lunch", "dinner", "snack"}

# Used when a day has no weekly siblings, e.g. a single-day plan or an older
# plan generated before the week menu existed.
MEAL_ALTERNATIVES = {
    "breakfast": [
        ("番茄鸡蛋面", ["番茄 150g", "鸡蛋 2 个", "面条 80g"]),
        ("燕麦牛奶碗", ["燕麦 50g", "牛奶 250ml", "香蕉 100g", "坚果 10g"]),
        ("全麦鸡蛋三明治", ["全麦面包 80g", "鸡蛋 2 个", "生菜 80g", "番茄 100g"]),
    ],
    "lunch": [
        ("青椒牛肉盖饭", ["米饭 200g", "牛肉 150g", "青椒 150g", "橄榄油 8g"]),
        ("香菇鸡腿饭", ["米饭 200g", "鸡腿 180g", "香菇 100g", "西兰花 150g"]),
        ("番茄虾仁意面", ["意面 100g", "虾 150g", "番茄 200g", "橄榄油 8g"]),
    ],
    "dinner": [
        ("清蒸鲈鱼配杂粮饭", ["鲈鱼 200g", "杂粮饭 150g", "西兰花 200g"]),
        ("豆腐菌菇煲", ["北豆腐 200g", "菌菇 150g", "青菜 200g", "米饭 150g"]),
        ("番茄牛腩", ["牛腩 150g", "番茄 200g", "土豆 150g", "青菜 150g"]),
    ],
    "snack": [
        ("希腊酸奶水果杯", ["无糖酸奶 200g", "蓝莓 80g", "坚果 15g"]),
        ("牛奶全麦面包", ["牛奶 250ml", "全麦面包 60g"]),
        ("香蕉花生酱", ["香蕉 120g", "花生酱 15g"]),
    ],
}


def _candidate_names(meal: dict) -> str:
    return str(meal.get("name") or "").strip()


def swap_planned_meal(
    db: Session,
    user_id: str,
    target_date: date,
    meal_key: str,
) -> dict:
    if meal_key not in MEAL_KEYS:
        raise ValueError("不支持的餐次")
    record = get_day(db, user_id, target_date)
    if record is None or not record.plan:
        raise LookupError("当天还没有饮食计划")
    plan = ensure_meal_macros(record.plan)
    meals = [meal for meal in plan.get("meals", []) if isinstance(meal, dict)]
    index = next(
        (i for i, meal in enumerate(meals) if str(meal.get("meal")) == meal_key),
        None,
    )
    if index is None:
        raise LookupError("这一天没有这一餐")
    current = meals[index]
    current_name = _candidate_names(current)

    replacement = None
    seen: set[tuple[str, tuple[str, ...]]] = set()
    for row in list_week(
        db, user_id, record.week_start or week_start_for(target_date)
    ):
        if row.plan_date == target_date:
            continue
        sibling = ensure_meal_macros(row.plan or {})
        for meal in sibling.get("meals", []):
            if not isinstance(meal, dict) or str(meal.get("meal")) != meal_key:
                continue
            name = _candidate_names(meal)
            if not name or name == current_name:
                continue
            key = (name, tuple(str(item) for item in meal.get("items", [])))
            if key in seen:
                continue
            seen.add(key)
            replacement = meal
            break
        if replacement is not None:
            break

    if replacement is None:
        for name, items in MEAL_ALTERNATIVES.get(meal_key, []):
            if name == current_name:
                continue
            replacement = {
                "meal": meal_key,
                "name": name,
                "items": items,
                "dishes": [_fallback_dish(name, items)],
            }
            break
    if replacement is None:
        raise ValueError("没有找到可替换的餐")

    items = [
        str(item)[:100]
        for item in replacement.get("items", [])
        if str(item).strip()
    ][:10]
    dishes = replacement.get("dishes")
    if not isinstance(dishes, list) or not dishes:
        dishes = [_fallback_dish(_candidate_names(replacement), items)]
    swapped = {
        **current,
        "name": _candidate_names(replacement)[:20] or _candidate_names(current),
        "items": items or current.get("items", []),
        "dishes": dishes,
    }
    # Keep the original meal's calorie/macro slot so the day total is stable.
    plan["meals"] = list(meals)
    plan["meals"][index] = swapped
    record.plan = plan
    db.commit()

    result = dict(plan)
    result["strategy"] = record.strategy
    result["generated_by"] = record.generated_by or result.get("generated_by")
    result["warning"] = result.get("warning")
    result["swapped_meal"] = {
        "meal": meal_key,
        "from": current_name,
        "to": swapped["name"],
    }
    return result
