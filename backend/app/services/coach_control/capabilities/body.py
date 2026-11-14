"""Body metric capability."""

from __future__ import annotations

import re
from datetime import date, datetime, time, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from ....models import BodyMetric
from ...food_text import DIET_TZ, food_log_context
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="body.log_weight",
        domain="body",
        kind="write",
        title="记录身体数据",
        description="记录体重、体脂或围度",
        requires_confirmation=True,
        undo=True,
        events=("BodyMetricLogged",),
    )
)

METRIC_FIELDS = {
    "weight_kg": "体重",
    "body_fat_pct": "体脂",
    "waist_cm": "腰围",
    "arm_cm": "臂围",
    "thigh_cm": "腿围",
}


def _match(
    message: str,
    pattern: str,
) -> float | None:
    match = re.search(pattern, message, flags=re.IGNORECASE)
    return float(match.group(1)) if match else None


def resolve(message: str) -> dict:
    weight = None
    weight_match = re.search(
        r"(?:体重|称重|称了|称一下)?\s*(\d{2,3}(?:\.\d+)?)\s*(kg|公斤|斤)",
        message,
        flags=re.IGNORECASE,
    )
    if weight_match:
        weight = float(weight_match.group(1))
        if weight_match.group(2) == "斤":
            weight = weight / 2
    elif any(word in message for word in ("体重", "称重", "称了", "称一下")):
        weight = _match(
            message,
            r"(?:体重|称重|称了|称一下)\s*(?:是|为|:|：)?\s*(\d{2,3}(?:\.\d+)?)",
        )

    body_fat = _match(
        message,
        r"(?:体脂率?)\s*(?:是|为|:|：)?\s*(\d{1,2}(?:\.\d+)?)\s*%?",
    )
    waist = _match(
        message,
        r"腰围\s*(?:是|为|:|：)?\s*(\d{2,3}(?:\.\d+)?)\s*(?:cm|厘米)?",
    )
    arm = _match(
        message,
        r"(?:手臂围|臂围)\s*(?:是|为|:|：)?\s*(\d{1,2}(?:\.\d+)?)\s*(?:cm|厘米)?",
    )
    thigh = _match(
        message,
        r"(?:大腿围|腿围)\s*(?:是|为|:|：)?\s*(\d{1,2}(?:\.\d+)?)\s*(?:cm|厘米)?",
    )

    checks = (
        (weight, 20, 300, "体重数字看起来不太对，再确认一下？"),
        (body_fat, 3, 65, "体脂数字看起来不太对，再确认一下？"),
        (waist, 30, 200, "腰围数字看起来不太对，再确认一下？"),
        (arm, 10, 80, "臂围数字看起来不太对，再确认一下？"),
        (thigh, 15, 100, "腿围数字看起来不太对，再确认一下？"),
    )
    for value, low, high, question in checks:
        if value is not None and not low <= value <= high:
            return {"ready": False, "questions": [question]}

    payload: dict = {"date": food_log_context(message)["date"]}
    if weight is not None:
        payload["weight_kg"] = round(weight, 1)
    if body_fat is not None:
        payload["body_fat_pct"] = round(body_fat, 1)
    if waist is not None:
        payload["waist_cm"] = round(waist, 1)
    if arm is not None:
        payload["arm_cm"] = round(arm, 1)
    if thigh is not None:
        payload["thigh_cm"] = round(thigh, 1)

    if len(payload) == 1:
        return {
            "ready": False,
            "questions": ["想记录体重、体脂，还是腰围/臂围/腿围？"],
        }
    return {"ready": True, "payload": payload}


def execute(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    existing = db.execute(
        select(BodyMetric).where(
            BodyMetric.user_id == user_id,
            BodyMetric.client_id == action_id,
        )
    ).scalar_one_or_none()
    if existing is None:
        measured = datetime.combine(
            date.fromisoformat(str(payload["date"])),
            time(hour=7),
            tzinfo=DIET_TZ,
        ).astimezone(timezone.utc)
        existing = BodyMetric(
            user_id=user_id,
            client_id=action_id,
            measured_at=measured,
            weight_kg=payload.get("weight_kg"),
            body_fat_pct=payload.get("body_fat_pct"),
            waist_cm=payload.get("waist_cm"),
            arm_cm=payload.get("arm_cm"),
            thigh_cm=payload.get("thigh_cm"),
        )
        db.add(existing)
        db.flush()
    return {
        "created_metric": {
            "date": payload["date"],
            **{
                key: float(payload[key])
                for key in METRIC_FIELDS
                if payload.get(key) is not None
            },
        }
    }


def undo(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    metric = db.execute(
        select(BodyMetric).where(
            BodyMetric.user_id == user_id,
            BodyMetric.client_id == action_id,
        )
    ).scalar_one_or_none()
    if metric is not None:
        db.delete(metric)
        db.flush()
    return {"deleted": metric is not None}
