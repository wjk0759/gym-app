"""Goal update capability."""

from __future__ import annotations

import re
from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from ....models import Goal
from ...food_text import parse_food_date
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="profile.update_goal",
        domain="profile",
        kind="write",
        title="更新目标",
        description="修改目标类型、目标体重或目标日期",
        requires_confirmation=True,
        undo=True,
        events=("GoalUpdated",),
    )
)

GOAL_TYPES = {
    "减脂": "lose_fat",
    "减肥": "lose_fat",
    "增肌": "build_muscle",
    "塑形": "recomp",
    "重塑": "recomp",
    "耐力": "endurance",
    "体能": "endurance",
}


def resolve(message: str) -> dict:
    goal_type = None
    for label, value in GOAL_TYPES.items():
        if label in message:
            goal_type = value
            break
    weight = None
    match = re.search(
        r"(?:目标(?:体重)?|减到|增到|降到|涨到)\s*"
        r"(\d{2,3}(?:\.\d+)?)\s*(kg|公斤|斤)?",
        message,
        flags=re.IGNORECASE,
    )
    if match:
        weight = float(match.group(1))
        if match.group(2) == "斤":
            weight = weight / 2
    target_date = parse_food_date(message) if re.search(r"前|之前|目标日期", message) else None
    if goal_type is None and weight is None and target_date is None:
        return {
            "ready": False,
            "questions": ["想改目标类型、目标体重，还是目标日期？"],
        }
    payload: dict = {}
    if goal_type:
        payload["goal_type"] = goal_type
    if weight is not None:
        if not 25 <= weight <= 300:
            return {"ready": False, "questions": ["目标体重看起来不太对，再确认一下？"]}
        payload["target_weight_kg"] = round(weight, 1)
    if target_date:
        payload["target_date"] = target_date.isoformat()
    return {"ready": True, "payload": payload}


def _serialize(goal: Goal | None) -> dict:
    if goal is None:
        return {}
    return {
        "type": goal.type,
        "target_weight_kg": goal.target_weight_kg,
        "target_body_fat_pct": goal.target_body_fat_pct,
        "target_waist_cm": goal.target_waist_cm,
        "target_date": goal.target_date.isoformat() if goal.target_date else None,
        "status": goal.status,
    }


def execute(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    goal = db.execute(
        select(Goal).where(Goal.user_id == user_id, Goal.status == "active")
    ).scalar_one_or_none()
    before = _serialize(goal)
    if goal is None:
        goal = Goal(user_id=user_id, type="recomp", status="active")
        db.add(goal)
    if payload.get("goal_type"):
        goal.type = str(payload["goal_type"])
    if payload.get("target_weight_kg") is not None:
        goal.target_weight_kg = float(payload["target_weight_kg"])
    if payload.get("target_date"):
        goal.target_date = date.fromisoformat(str(payload["target_date"]))
    db.flush()
    return {"before": before, "after": _serialize(goal)}


def undo(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
    before: dict,
) -> dict:
    goal = db.execute(
        select(Goal).where(Goal.user_id == user_id, Goal.status == "active")
    ).scalar_one_or_none()
    if not before:
        if goal is not None:
            db.delete(goal)
            db.flush()
        return {"restored": True, "deleted": True}
    if goal is None:
        goal = Goal(user_id=user_id, type="recomp", status="active")
        db.add(goal)
    goal.type = str(before.get("type") or "recomp")
    goal.target_weight_kg = before.get("target_weight_kg")
    goal.target_body_fat_pct = before.get("target_body_fat_pct")
    goal.target_waist_cm = before.get("target_waist_cm")
    goal.target_date = (
        date.fromisoformat(before["target_date"])
        if before.get("target_date")
        else None
    )
    db.flush()
    return {"restored": True}
