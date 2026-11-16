"""Read a saved meal plan and its recipe from the coach.

Answers "午餐吃什么 / 晚餐菜谱怎么做 / 看看明天的早餐" without generating a new
plan or writing data. If the day has no saved plan, the coach says so and offers
to generate one instead of inventing a menu.
"""

from __future__ import annotations

from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from ....models import utcnow
from ...food_text import DIET_TZ, parse_food_date
from ...meal_plans import get_day
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="diet.meal_detail",
        domain="diet",
        kind="read",
        title="查看餐单/菜谱",
        description="读取已保存的餐单、食材和做法，只读",
        requires_confirmation=False,
        undo=False,
        events=("DietMealViewed",),
    )
)

MEAL_LABELS = {
    "breakfast": "早餐",
    "lunch": "午餐",
    "dinner": "晚餐",
    "snack": "加餐",
}
MEAL_WORDS = (
    ("breakfast", ("早餐", "早饭", "早上")),
    ("lunch", ("午餐", "午饭", "中午")),
    ("dinner", ("晚餐", "晚饭", "晚上")),
    ("snack", ("加餐", "零食")),
)


def _day_label(value, today) -> str:
    if value == today:
        return "今天"
    if value == today - timedelta(days=1):
        return "昨天"
    if value == today + timedelta(days=1):
        return "明天"
    return f"{value.month}月{value.day}日"


def _meal_keys(message: str) -> list[str]:
    return [
        key
        for key, words in MEAL_WORDS
        if any(word in message for word in words)
    ]


def _items_text(value) -> str:
    items = [str(item).strip() for item in value or [] if str(item).strip()]
    return "、".join(items[:6])


def _meal_lines(meal: dict, label: str) -> list[str]:
    name = str(meal.get("name") or label)
    kcal = int(float(meal.get("kcal") or 0))
    headline = f"{name}（约 {kcal} kcal）" if kcal else name
    lines = [headline]
    items = _items_text(meal.get("items"))
    if items:
        lines.append(f"食材：{items}")
    for dish in (meal.get("dishes") or [])[:2]:
        if not isinstance(dish, dict):
            continue
        recipe = dish.get("recipe") or {}
        if not isinstance(recipe, dict):
            continue
        title = str(recipe.get("title") or "").strip()
        ingredients = _items_text(recipe.get("ingredients"))
        steps = [
            str(step).strip()
            for step in recipe.get("steps") or []
            if str(step).strip()
        ]
        if title:
            lines.append(f"菜谱：{title}")
        if ingredients:
            lines.append(f"配料：{ingredients}")
        if steps:
            numbered = " ".join(
                f"{index}. {step}"
                for index, step in enumerate(steps[:4], start=1)
            )
            lines.append(f"做法：{numbered}")
    return lines


def resolve(db: Session, user_id: str, message: str) -> dict:
    today = datetime.now(DIET_TZ).date()
    target_date = parse_food_date(message) or today
    label = _day_label(target_date, today)
    meal_keys = _meal_keys(message)
    record = get_day(db, user_id, target_date)
    if record is None:
        return {
            "ready": True,
            "payload": {
                "date": target_date.isoformat(),
                "meal": meal_keys[0] if meal_keys else None,
                "summary": (
                    f"{label}还没有保存的餐单。"
                    "你可以说“生成今天的饮食计划”，我再按目标排一份。"
                ),
                "wins": [],
                "watchouts": ["没有已保存的餐单，暂不能查看菜谱。"],
                "actions": [],
                "generated_at": utcnow().isoformat(),
            },
        }
    plan = record.plan or {}
    meals = [
        meal
        for meal in plan.get("meals") or []
        if isinstance(meal, dict) and meal.get("meal") in MEAL_LABELS
    ]
    if not meals:
        return {
            "ready": True,
            "payload": {
                "date": target_date.isoformat(),
                "meal": meal_keys[0] if meal_keys else None,
                "summary": f"{label}的餐单里还没有具体餐次。",
                "wins": [],
                "watchouts": ["这份餐单没有可查看的食材或做法。"],
                "actions": [],
                "generated_at": utcnow().isoformat(),
            },
        }

    if meal_keys:
        selected = [
            meal
            for meal in meals
            if str(meal.get("meal") or "") in meal_keys
        ]
        if not selected:
            available = "、".join(
                MEAL_LABELS[str(item["meal"])] for item in meals
            )
            wanted = "、".join(MEAL_LABELS[key] for key in meal_keys)
            return {
                "ready": True,
                "payload": {
                    "date": target_date.isoformat(),
                    "meal": meal_keys[0],
                    "summary": (
                        f"{label}的餐单里没有{wanted}；"
                        f"现有{available}。想看哪一餐？"
                    ),
                    "wins": [],
                    "watchouts": [],
                    "actions": [],
                    "generated_at": utcnow().isoformat(),
                },
            }
        blocks = [label]
        for meal in selected:
            key = str(meal.get("meal") or "")
            blocks.append(
                "\n".join(_meal_lines(meal, MEAL_LABELS.get(key, key)))
            )
        return {
            "ready": True,
            "payload": {
                "date": target_date.isoformat(),
                "meal": meal_keys[0],
                "summary": "\n\n".join(blocks)[:900],
                "wins": [],
                "watchouts": [],
                "actions": [],
                "generated_at": utcnow().isoformat(),
            },
        }

    overview: list[str] = [f"{label}餐单"]
    for meal in meals:
        key = str(meal.get("meal") or "")
        meal_label = MEAL_LABELS.get(key, key)
        name = str(meal.get("name") or meal_label)
        kcal = int(float(meal.get("kcal") or 0))
        items = _items_text(meal.get("items"))
        suffix = f" {kcal} kcal" if kcal else ""
        overview.append(
            f"{meal_label}：{name}{suffix}" + (f"（{items}）" if items else "")
        )
    return {
        "ready": True,
        "payload": {
            "date": target_date.isoformat(),
            "meal": None,
            "summary": "\n".join(overview)[:900],
            "wins": [],
            "watchouts": ["想看具体做法，可以说“午餐菜谱怎么做”。"],
            "actions": [],
            "generated_at": utcnow().isoformat(),
        },
    }
