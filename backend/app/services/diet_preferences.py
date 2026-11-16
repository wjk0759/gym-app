"""Food preferences that affect generated meal plans.

The coach owns the dislike list; plan generation only reads it. Matching is
deliberately conservative: canonical names are preferred, one-character names
still match as substrings, and generated items are replaced with a same-category
food instead of leaving the meal empty.
"""

from __future__ import annotations

import re
import unicodedata

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import UserFoodDislike

_AMOUNT = re.compile(
    r"^(?P<name>.+?)(?P<amount>\s*\d+(?:\.\d+)?\s*"
    r"(?:g|克|kg|千克|ml|毫升|个|片|碗|份|勺|盒|瓶)?)$",
    re.IGNORECASE,
)
_BRACKETED = re.compile(r"[（(][^）)]*[）)]")

_CATEGORY_CANDIDATES = {
    "dairy": ("无糖豆浆", "牛奶", "无糖酸奶"),
    "fat": ("牛油果", "橄榄油", "坚果"),
    "protein": ("北豆腐", "鸡胸肉", "瘦牛肉", "虾仁", "鸡蛋"),
    "carb": ("糙米饭", "红薯", "藜麦", "全麦面包", "土豆"),
    "vegetable": ("菠菜", "芦笋", "西葫芦", "番茄", "黄瓜"),
    "fruit": ("苹果", "猕猴桃", "橙子", "香蕉"),
}
_CATEGORY_WORDS = (
    ("dairy", ("奶", "酸奶", "豆浆", "乳清")),
    ("fat", ("牛油果", "坚果", "橄榄油", "花生酱")),
    ("protein", ("鸡", "牛", "猪", "鱼", "虾", "蛋", "豆腐", "肉", "蛋白")),
    ("carb", ("米", "面", "燕麦", "红薯", "土豆", "玉米", "藜麦", "馒头")),
    ("vegetable", ("菜", "瓜", "椒", "菇", "笋", "番茄", "菠菜", "萝卜", "花")),
    ("fruit", ("果", "莓", "橙", "苹果", "香蕉", "猕猴桃", "梨")),
)
_GENERIC_MEAL_ITEM = "同类食材 适量"
_MEAL_LABELS = {
    "breakfast": "早餐",
    "lunch": "午餐",
    "dinner": "晚餐",
    "snack": "加餐",
}


def _normalize(value: str) -> str:
    return unicodedata.normalize("NFKC", str(value)).strip().lower()


def _term_variants(term: str) -> set[str]:
    value = str(term).strip()
    variants = {value}
    without_brackets = _BRACKETED.sub("", value).strip()
    if without_brackets:
        variants.add(without_brackets)
    return {item for item in variants if item}


def matches_avoid(text: str, terms: list[str]) -> bool:
    normalized = _normalize(text)
    if not normalized:
        return False
    for term in terms:
        for variant in _term_variants(term):
            if _normalize(variant) in normalized:
                return True
    return False


def active_disliked_food_names(db: Session, user_id: str) -> list[str]:
    rows = (
        db.execute(
            select(UserFoodDislike)
            .where(
                UserFoodDislike.user_id == user_id,
                UserFoodDislike.deleted_at.is_(None),
            )
            .order_by(UserFoodDislike.updated_at.desc())
        )
        .scalars()
        .all()
    )
    names: list[str] = []
    seen: set[str] = set()
    for item in rows:
        name = str(item.name or "").strip()
        key = _normalize(name)
        if name and key not in seen:
            seen.add(key)
            names.append(name)
    return names


def _category(text: str) -> str | None:
    for category, words in _CATEGORY_WORDS:
        if any(word in text for word in words):
            return category
    return None


def _substitute(item: str, terms: list[str]) -> str:
    match = _AMOUNT.match(item.strip())
    name = match.group("name").strip() if match else item.strip()
    amount = match.group("amount") if match else ""
    liquid = bool(re.search(r"\d+\s*(?:ml|毫升)", amount, re.IGNORECASE))
    category = "dairy" if liquid else _category(name)
    candidates = _CATEGORY_CANDIDATES.get(category or "", ())
    for candidate in candidates:
        if not matches_avoid(candidate, terms):
            return f"{candidate}{amount}"
    if liquid:
        return f"水{amount}"
    return ""


def _filter_items(
    items: list[str],
    terms: list[str],
) -> list[str]:
    result: list[str] = []
    for item in items:
        if not matches_avoid(item, terms):
            result.append(item)
            continue
        replacement = _substitute(item, terms)
        if replacement:
            result.append(replacement)
    return result


def _fallback_dish(items: list[str]) -> dict:
    return {
        "name": "家常餐",
        "items": items,
        "recipe": {
            "title": "家常餐",
            "ingredients": items[:6],
            "steps": ["按份量准备食材，少油少盐做熟，按家常口味调味。"],
            "tip": None,
        },
    }


def _apply_to_meals(meals: list, terms: list[str]) -> None:
    for meal in meals:
        if not isinstance(meal, dict):
            continue
        name = str(meal.get("name") or "")
        if name and matches_avoid(name, terms):
            meal["name"] = _MEAL_LABELS.get(
                str(meal.get("meal") or ""),
                "家常餐",
            )
        items = [
            str(item)
            for item in meal.get("items") or []
            if str(item).strip()
        ]
        filtered = _filter_items(items, terms)
        if not filtered:
            filtered = [_GENERIC_MEAL_ITEM]
        meal["items"] = filtered

        dishes = meal.get("dishes")
        if not isinstance(dishes, list):
            continue
        kept: list[dict] = []
        for dish in dishes:
            if not isinstance(dish, dict):
                continue
            recipe = dish.get("recipe") or {}
            haystack = [
                str(dish.get("name") or ""),
                *[str(item) for item in dish.get("items") or []],
                *[str(item) for item in recipe.get("ingredients") or []],
                *[str(item) for item in recipe.get("steps") or []],
            ]
            if any(matches_avoid(part, terms) for part in haystack):
                continue
            kept.append(dish)
        meal["dishes"] = kept or [_fallback_dish(filtered)]


def apply_food_avoidance(plan: dict, terms: list[str]) -> dict:
    if not terms or not isinstance(plan, dict):
        return plan
    meals = plan.get("meals")
    if isinstance(meals, list):
        _apply_to_meals(meals, terms)
    days = plan.get("days")
    if isinstance(days, list):
        for day in days:
            if not isinstance(day, dict):
                continue
            day_meals = day.get("meals")
            if isinstance(day_meals, list):
                _apply_to_meals(day_meals, terms)
    return plan
