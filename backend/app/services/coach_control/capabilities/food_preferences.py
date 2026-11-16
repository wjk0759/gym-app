"""Favorite food preferences from the coach."""

from __future__ import annotations

import re
from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ....models import UserCustomFood, UserFoodFavorite, utcnow
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="diet.favorite_food",
        domain="diet",
        kind="write",
        title="收藏食物",
        description="把食物加入或移出收藏",
        requires_confirmation=True,
        undo=True,
        events=("FoodFavoriteUpdated",),
        refreshes=("profile",),
    )
)

ADD = re.compile(
    r"(?:收藏|收藏一下|加入收藏|放到收藏|加到收藏)"
    r"\s*[：:]?\s*(.+)"
)
REMOVE = re.compile(
    r"(?:取消收藏|移除收藏|不要收藏|从收藏(?:里|中)?(?:删掉|删除|移除))"
    r"\s*[：:]?\s*(.+)"
)


def _name(message: str, match: re.Match | None) -> str:
    if match is not None:
        value = match.group(1).strip(" ，,。；;：:")
        value = re.sub(r"^(?:这个|这道|食物)\s*", "", value)
        return value[:120]
    natural = re.search(
        r"把\s*(.+?)\s*(?:加入|加到|放到|放进)\s*收藏",
        message,
    )
    if natural is not None:
        return natural.group(1).strip(" ，,。；;：:")[:120]
    return ""


def _favorite(
    db: Session,
    user_id: str,
    food_key: str,
) -> UserFoodFavorite | None:
    return db.execute(
        select(UserFoodFavorite).where(
            UserFoodFavorite.user_id == user_id,
            UserFoodFavorite.food_key == food_key,
        )
    ).scalar_one_or_none()


def resolve(db: Session, user_id: str, message: str) -> dict:
    remove_match = REMOVE.search(message)
    add_match = ADD.search(message)
    remove = remove_match is not None
    name = _name(message, remove_match if remove else add_match)
    if not name:
        return {
            "ready": False,
            "questions": ["想收藏哪样食物？例如“收藏鸡胸肉”。"],
        }
    custom = db.execute(
        select(UserCustomFood).where(
            UserCustomFood.user_id == user_id,
            func.lower(UserCustomFood.name) == name.lower(),
            UserCustomFood.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if custom is not None:
        name = custom.name
        food_key = f"custom:{custom.client_id}"
    else:
        food_key = f"library:{name}"
    existing = _favorite(db, user_id, food_key)
    active = existing is not None and existing.deleted_at is None
    if remove and not active:
        return {
            "ready": False,
            "questions": [f"「{name}」不在收藏里。"],
        }
    if not remove and active:
        return {
            "ready": False,
            "questions": [f"「{name}」已经在收藏里了。"],
        }
    return {
        "ready": True,
        "payload": {
            "food_key": food_key,
            "name": name,
            "favorite": not remove,
            "summary": (
                f"准备收藏「{name}」"
                if not remove
                else f"准备取消收藏「{name}」"
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
        raise ValueError("收藏信息不完整")
    item = _favorite(db, user_id, food_key)
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
        item = UserFoodFavorite(
            user_id=user_id,
            food_key=food_key,
            name=name,
        )
        db.add(item)
    item.name = name
    if payload.get("favorite", True):
        item.deleted_at = None
    else:
        item.deleted_at = utcnow()
    db.flush()
    return {
        "before": before,
        "after": {
            "food_key": food_key,
            "name": name,
            "favorite": item.deleted_at is None,
        },
    }


def undo(
    db: Session,
    user_id: str,
    before: dict,
    payload: dict,
) -> dict:
    food_key = str(payload.get("food_key") or "")
    item = _favorite(db, user_id, food_key)
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
