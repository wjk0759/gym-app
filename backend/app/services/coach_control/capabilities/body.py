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
        title="记录体重",
        description="记录今天的体重",
        requires_confirmation=True,
        undo=True,
        events=("BodyMetricLogged",),
    )
)


def resolve(message: str) -> dict:
    match = re.search(
        r"(\d{2,3}(?:\.\d+)?)\s*(kg|公斤|斤)?",
        message,
        flags=re.IGNORECASE,
    )
    if match is None:
        return {"ready": False, "questions": ["今天体重大概多少公斤？"]}
    value = float(match.group(1))
    if match.group(2) == "斤":
        value = value / 2
    if not 25 <= value <= 300:
        return {"ready": False, "questions": ["体重数字看起来不太对，再确认一下？"]}
    context = food_log_context(message)
    return {
        "ready": True,
        "payload": {
            "date": context["date"],
            "weight_kg": round(value, 1),
        },
    }


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
            weight_kg=float(payload["weight_kg"]),
        )
        db.add(existing)
        db.flush()
    return {
        "created_metric": {
            "date": payload["date"],
            "weight_kg": float(payload["weight_kg"]),
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
