"""Create a custom food from a coach message."""

from __future__ import annotations

import re
from uuid import uuid4

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ....models import UserCustomFood, UserFoodFavorite, utcnow
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="diet.custom_food",
        domain="diet",
        kind="write",
        title="创建自定义食物",
        description="把用户描述的食物和营养值加入自定义食物库",
        requires_confirmation=True,
        undo=True,
        events=("CustomFoodCreated",),
        refreshes=("profile",),
    )
)


def _name(message: str) -> str:
    match = re.search(
        r"(?:添加|新建|创建|加)(?:一个|一份)?(?:自定义)?食物"
        r"\s*[：:]?\s*(.+)",
        message,
    )
    if match is None:
        match = re.search(
            r"把\s*(.+?)\s*(?:加到|加入|添加进?)\s*(?:我的)?自定义食物",
            message,
        )
        if match is None:
            return ""
        return match.group(1).strip(" ，,。；;：:")[:120]
    raw = match.group(1).strip(" ，,。；;：:")
    name = re.split(
        r"(?:每\s*\d+\s*(?:g|克|份)?|每份|kcal|千卡|大卡|蛋白质|碳水|脂肪|纤维|热量|gi)",
        raw,
        maxsplit=1,
        flags=re.IGNORECASE,
    )[0]
    return name.strip(" ，,。；;：:")[:120]


def _number(message: str, pattern: str) -> float | None:
    match = re.search(pattern, message, flags=re.IGNORECASE)
    return float(match.group(1)) if match is not None else None


def resolve(db: Session, user_id: str, message: str) -> dict:
    name = _name(message)
    if not name or name in {"自定义食物", "食物"}:
        return {
            "ready": False,
            "questions": [
                "想创建什么食物？例如“添加自定义食物鸡胸肉丸，每100g 150kcal，蛋白质20g”。"
            ],
        }
    existing = db.execute(
        select(UserCustomFood).where(
            UserCustomFood.user_id == user_id,
            func.lower(UserCustomFood.name) == name.lower(),
            UserCustomFood.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if existing is not None:
        return {
            "ready": False,
            "terminal": True,
            "questions": [f"自定义食物里已经有「{existing.name}」了。"],
        }
    kcal = _number(message, r"(\d+(?:\.\d+)?)\s*(?:kcal|千卡|大卡)")
    protein = _number(
        message, r"蛋白质\s*(\d+(?:\.\d+)?)\s*(?:g|克)"
    )
    carbs = _number(
        message, r"碳水(?:化合物)?\s*(\d+(?:\.\d+)?)\s*(?:g|克)"
    )
    fat = _number(message, r"脂肪\s*(\d+(?:\.\d+)?)\s*(?:g|克)")
    fiber = _number(message, r"纤维\s*(\d+(?:\.\d+)?)\s*(?:g|克)")
    default_grams = _number(
        message, r"每\s*(\d+(?:\.\d+)?)\s*(?:g|克)"
    )
    if all(
        value is None
        for value in (kcal, protein, carbs, fat)
    ):
        return {
            "ready": False,
            "questions": [
                "还差营养值。可以说“每100g 150kcal，蛋白质20g，碳水10g，脂肪3g”。"
            ],
        }
    if kcal is not None and not 0 <= kcal <= 1200:
        return {"ready": False, "questions": ["热量数字看起来不太对。"]}
    for value in (protein, carbs, fat, fiber):
        if value is not None and not 0 <= value <= 300:
            return {"ready": False, "questions": ["营养值看起来不太对。"]}
    values = {
        "kcal": round(kcal or 0, 1),
        "protein": round(protein or 0, 1),
        "carbs": round(carbs or 0, 1),
        "fat": round(fat or 0, 1),
        "fiber": round(fiber, 1) if fiber is not None else None,
        "default_grams": (
            round(default_grams, 1) if default_grams is not None else 100
        ),
    }
    macro_text = "、".join(
        part
        for part in (
            f"{values['kcal']:g} kcal" if kcal is not None else "",
            f"蛋白质 {values['protein']:g}g" if protein is not None else "",
            f"碳水 {values['carbs']:g}g" if carbs is not None else "",
            f"脂肪 {values['fat']:g}g" if fat is not None else "",
        )
        if part
    )
    return {
        "ready": True,
        "payload": {
            "client_id": str(uuid4()),
            "name": name,
            "category": "自定义",
            **values,
            "summary": f"准备创建自定义食物「{name}」：{macro_text}",
        },
    }


def execute(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    client_id = str(payload.get("client_id") or "")
    name = str(payload.get("name") or "").strip()[:120]
    if not client_id or not name:
        raise ValueError("自定义食物信息不完整")
    item = UserCustomFood(
        user_id=user_id,
        client_id=client_id,
        name=name,
        category=str(payload.get("category") or "自定义")[:40],
        kcal=float(payload.get("kcal") or 0),
        protein=float(payload.get("protein") or 0),
        carbs=float(payload.get("carbs") or 0),
        fat=float(payload.get("fat") or 0),
        fiber=payload.get("fiber"),
        default_grams=payload.get("default_grams"),
    )
    db.add(item)
    db.flush()
    return {
        "before": {"client_id": client_id, "existed": False},
        "after": {"client_id": client_id, "name": name},
    }


def undo(
    db: Session,
    user_id: str,
    before: dict,
    payload: dict,
) -> dict:
    client_id = str(
        (before or {}).get("client_id")
        or payload.get("client_id")
        or ""
    )
    item = db.execute(
        select(UserCustomFood).where(
            UserCustomFood.user_id == user_id,
            UserCustomFood.client_id == client_id,
        )
    ).scalar_one_or_none()
    if item is not None:
        db.delete(item)
        db.flush()
    favorite = db.execute(
        select(UserFoodFavorite).where(
            UserFoodFavorite.user_id == user_id,
            UserFoodFavorite.food_key == f"custom:{client_id}",
        )
    ).scalar_one_or_none()
    if favorite is not None and favorite.deleted_at is None:
        favorite.deleted_at = utcnow()
        db.flush()
    return {"removed": item is not None}
