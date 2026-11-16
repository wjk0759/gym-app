"""Body metric capability."""

from __future__ import annotations

import re
from datetime import date, datetime, time, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from ....models import BodyMetric, utcnow
from ...body_metrics import recompute_profile_cache
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
        refreshes=("body", "profile", "diet", "review"),
    )
)

METRIC_FIELDS = {
    "weight_kg": "体重",
    "body_fat_pct": "体脂",
    "waist_cm": "腰围",
    "arm_cm": "臂围",
    "thigh_cm": "腿围",
}

DELETE_CAPABILITY = register(
    Capability(
        id="body.delete_metric",
        domain="body",
        kind="write",
        title="删除身体数据",
        description="删除某一天的一条体重、体脂或围度记录",
        requires_confirmation=True,
        undo=True,
        events=("BodyMetricDeleted",),
        refreshes=("body", "profile", "diet", "review"),
    )
)

DELETE_FIELD_WORDS = {
    "weight_kg": ("体重", "称重", "称了", "上秤", "过秤"),
    "body_fat_pct": ("体脂",),
    "waist_cm": ("腰围",),
    "arm_cm": ("臂围", "手臂围"),
    "thigh_cm": ("腿围", "大腿围"),
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
        r"(?:体重|称重|称了|称一下|上秤|过秤)?\s*"
        r"(\d{2,3}(?:\.\d+)?)\s*(kg|公斤|斤)",
        message,
        flags=re.IGNORECASE,
    )
    if weight_match:
        weight = float(weight_match.group(1))
        if weight_match.group(2) == "斤":
            weight = weight / 2
    elif any(
        word in message
        for word in ("体重", "称重", "称了", "称一下", "上秤", "过秤")
    ):
        weight = _match(
            message,
            r"(?:体重|称重|称了|称一下|上秤|过秤)\s*"
            r"(?:是|为|:|：)?\s*(\d{2,3}(?:\.\d+)?)",
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


def _metric_snapshot(metric: BodyMetric) -> dict:
    return {
        "id": metric.id,
        "client_id": metric.client_id,
        "measured_at": metric.measured_at.isoformat(),
        "created_at": (
            metric.created_at.isoformat() if metric.created_at else None
        ),
        **{
            field: getattr(metric, field)
            for field in METRIC_FIELDS
        },
    }


def _metric_local_date(metric: BodyMetric) -> date:
    measured = metric.measured_at
    if measured.tzinfo is None:
        measured = measured.replace(tzinfo=timezone.utc)
    return measured.astimezone(DIET_TZ).date()


def resolve_delete(
    db: Session,
    user_id: str,
    message: str,
) -> dict:
    if re.search(r"所有|全部|批量|清空", message):
        return {
            "ready": False,
            "questions": ["一次只能删一条身体记录；告诉我是哪一天、哪一项。"],
        }
    fields = [
        field
        for field, words in DELETE_FIELD_WORDS.items()
        if any(word in message for word in words)
    ]
    target = food_log_context(message)["date"]
    recent = bool(re.search(r"最近|最新|上一条|上次", message))
    rows = (
        db.execute(
            select(BodyMetric)
            .where(BodyMetric.user_id == user_id)
            .order_by(
                BodyMetric.measured_at.desc(),
                BodyMetric.created_at.desc(),
            )
        )
        .scalars()
        .all()
    )
    chosen: BodyMetric | None = None
    for metric in rows:
        if fields and all(
            getattr(metric, field) is None for field in fields
        ):
            continue
        local_date = _metric_local_date(metric).isoformat()
        if not recent and local_date != target:
            continue
        chosen = metric
        break
    if chosen is None:
        label = (
            "、".join(METRIC_FIELDS[field] for field in fields)
            if fields
            else "身体"
        )
        when = "最近" if recent else target
        return {
            "ready": False,
            "questions": [f"没找到{when}的{label}记录。"],
        }
    local_date = _metric_local_date(chosen)
    selected_fields = fields or list(METRIC_FIELDS)
    parts = [
        f"{METRIC_FIELDS[field]} {getattr(chosen, field):g}"
        for field in selected_fields
        if getattr(chosen, field) is not None
    ]
    return {
        "ready": True,
        "payload": {
            "metric_id": chosen.id,
            "client_id": chosen.client_id,
            "fields": fields,
            "date": local_date.isoformat(),
            "summary": (
                f"删除 {local_date.month}月{local_date.day}日 的"
                + "、".join(parts)
                + " 记录"
            ),
        },
    }


def execute_delete(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    metric = db.get(BodyMetric, str(payload.get("metric_id") or ""))
    if metric is None or metric.user_id != user_id:
        raise LookupError("身体记录不存在")
    before = {"metric": _metric_snapshot(metric)}
    fields = [
        field
        for field in payload.get("fields") or []
        if field in METRIC_FIELDS
    ]
    if fields:
        for field in fields:
            setattr(metric, field, None)
        removed_row = all(
            getattr(metric, field) is None for field in METRIC_FIELDS
        )
        if removed_row:
            db.delete(metric)
    else:
        removed_row = True
        db.delete(metric)
    db.flush()
    recompute_profile_cache(db, user_id)
    return {
        "before": before,
        "deleted": removed_row,
        "cleared_fields": fields,
    }


def undo_delete(
    db: Session,
    user_id: str,
    before: dict,
    payload: dict,
) -> dict:
    snapshot = (before or {}).get("metric") or {}
    metric_id = str(snapshot.get("id") or "")
    if not metric_id:
        return {"restored": False}
    values = {
        field: snapshot.get(field)
        for field in METRIC_FIELDS
    }
    metric = db.get(BodyMetric, metric_id)
    if metric is None:
        if not snapshot.get("client_id") or not snapshot.get("measured_at"):
            return {"restored": False}
        created_at = snapshot.get("created_at")
        metric = BodyMetric(
            id=metric_id,
            user_id=user_id,
            client_id=str(snapshot["client_id"]),
            measured_at=datetime.fromisoformat(str(snapshot["measured_at"])),
            created_at=(
                datetime.fromisoformat(str(created_at))
                if created_at
                else utcnow()
            ),
            **values,
        )
        db.add(metric)
    else:
        for field, value in values.items():
            setattr(metric, field, value)
    db.flush()
    recompute_profile_cache(db, user_id)
    return {"restored": True}

