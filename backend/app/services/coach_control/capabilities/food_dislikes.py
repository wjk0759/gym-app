"""Food dislike preferences from the coach."""

from __future__ import annotations

import re
from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ....models import UserCustomFood, UserFoodDislike, utcnow
from ...food_text import ALIASES
from ...food_vision import FOODS
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="diet.dislike_food",
        domain="diet",
        kind="write",
        title="避开食物",
        description="把食物加入或移出“不喜欢”，后续餐单尽量避开",
        requires_confirmation=True,
        undo=True,
        events=("FoodDislikeUpdated",),
        refreshes=("profile",),
    )
)

ADD = re.compile(
    r"(?:不喜欢吃|不喜欢|讨厌吃|别安排|别推荐|以后别做|避开)"
    r"\s*[：:]?\s*(.+)"
)
REMOVE = re.compile(
    r"(?:可以吃|恢复吃|不讨厌|取消不喜欢|不用避开|"
    r"从不喜欢(?:里|中)?(?:去掉|移除|删掉))"
    r"\s*[：:]?\s*(.+)"
)


def _name_from(message: str, match: re.Match | None) -> str:
    if match is not None:
        value = match.group(1).strip(" ，,。；;：:")
        value = re.sub(r"^(?:这个|这道|这种)\s*(?:食物|菜)?\s*", "", value)
        value = re.sub(r"(?:这个|这道|这种)?\s*(?:食物|菜)$", "", value)
        value = re.sub(r"(?:了|吧|啦|呀|哦)$", "", value)
        value = value.strip()[:120]
        if value:
            return value
    natural = re.search(
        r"(?:把\s*)?(.+?)\s*(?:从不喜欢(?:里|中)?(?:去掉|移除|删掉)|"
        r"可以吃(?:了)?|能吃了?|恢复吃(?:了)?)",
        message,
    )
    if natural is not None:
        return natural.group(1).strip(" ，,。；;：:")[:120]
    return ""


def _canonical_food(name: str) -> str | None:
    """Return a stable canonical name, or None when several foods match."""
    value = name.strip()
    if not value:
        return None
    if value in FOODS:
        return value
    if value in ALIASES:
        return ALIASES[value]
    candidates = [
        key
        for key in (*FOODS, *ALIASES)
        if value in key or key in value
    ]
    if not candidates:
        return value
    canonical = {ALIASES.get(key, key) for key in candidates}
    if value in canonical:
        return value
    if len(canonical) == 1:
        return canonical.pop()
    return None


def _custom_food(
    db: Session,
    user_id: str,
    name: str,
) -> UserCustomFood | None:
    return db.execute(
        select(UserCustomFood).where(
            UserCustomFood.user_id == user_id,
            func.lower(UserCustomFood.name) == name.lower(),
            UserCustomFood.deleted_at.is_(None),
        )
    ).scalar_one_or_none()


def _dislike(
    db: Session,
    user_id: str,
    food_key: str,
) -> UserFoodDislike | None:
    return db.execute(
        select(UserFoodDislike).where(
            UserFoodDislike.user_id == user_id,
            UserFoodDislike.food_key == food_key,
        )
    ).scalar_one_or_none()


def resolve(db: Session, user_id: str, message: str) -> dict:
    remove_match = REMOVE.search(message)
    add_match = ADD.search(message)
    remove = remove_match is not None
    requested = _name_from(message, remove_match if remove else add_match)
    if not requested:
        return {
            "ready": False,
            "questions": ["想避开哪样食物？例如“不喜欢吃鸡胸肉”。"],
        }
    custom = _custom_food(db, user_id, requested)
    if custom is not None:
        name = custom.name
        food_key = f"custom:{custom.client_id}"
    else:
        name = _canonical_food(requested)
        if name is None:
            return {
                "ready": False,
                "questions": [
                    f"「{requested}」可能对应多种食物，"
                    "说得具体一点，例如“不喜欢吃三文鱼”。"
                ],
            }
        food_key = f"library:{name}"
    existing = _dislike(db, user_id, food_key)
    active = existing is not None and existing.deleted_at is None
    if remove and not active:
        return {
            "ready": False,
            "terminal": True,
            "questions": [f"「{name}」不在避开列表里。"],
        }
    if not remove and active:
        return {
            "ready": False,
            "terminal": True,
            "questions": [f"已经记住要避开「{name}」了。"],
        }
    return {
        "ready": True,
        "payload": {
            "food_key": food_key,
            "name": name,
            "dislike": not remove,
            "summary": (
                f"准备记住避开「{name}」，后续餐单尽量不安排"
                if not remove
                else f"准备恢复安排「{name}」"
            ),
        },
    }


def execute(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    food_key = str(payload.get("food_key") or "")
    name = str(payload.get("name") or "")[:120]
    if not food_key or not name:
        raise ValueError("食物信息不完整")
    item = _dislike(db, user_id, food_key)
    existed = item is not None
    before = {
        "existed": existed,
        "deleted_at": (
            item.deleted_at.isoformat()
            if item is not None and item.deleted_at is not None
            else None
        ),
    }
    if item is None:
        item = UserFoodDislike(
            user_id=user_id,
            food_key=food_key,
            name=name,
        )
        db.add(item)
    item.name = name
    if payload.get("dislike", True):
        item.deleted_at = None
    else:
        item.deleted_at = utcnow()
    db.flush()
    return {
        "before": before,
        "after": {
            "food_key": food_key,
            "name": name,
            "dislike": item.deleted_at is None,
        },
    }


def undo(
    db: Session,
    user_id: str,
    before: dict,
    payload: dict,
) -> dict:
    food_key = str(payload.get("food_key") or "")
    item = _dislike(db, user_id, food_key)
    if item is None:
        return {"restored": False}
    if not before.get("existed"):
        db.delete(item)
    else:
        deleted_at = before.get("deleted_at")
        item.deleted_at = (
            datetime.fromisoformat(str(deleted_at))
            if deleted_at
            else None
        )
    db.flush()
    return {"restored": True}
