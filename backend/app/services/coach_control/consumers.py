"""Domain-event consumers that feed the coach inbox."""

from __future__ import annotations

from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import CoachInbox, DomainEvent, utcnow
from .events import create_inbox_item
from .readiness import snapshot as readiness_snapshot


def _create_readiness_nudge(db: Session, event: DomainEvent) -> None:
    """One recovery inbox item at most every three days.

    The nudge is generated from training load, so it stays silent for balanced
    or under-trained users and never claims sleep/HRV data we do not have.
    """
    recent = db.execute(
        select(CoachInbox.id)
        .where(
            CoachInbox.user_id == event.user_id,
            CoachInbox.kind == "recovery",
            CoachInbox.created_at >= utcnow() - timedelta(days=3),
        )
        .limit(1)
    ).scalar_one_or_none()
    if recent is not None:
        return
    readiness = readiness_snapshot(db, event.user_id)
    if readiness["status"] not in {"high_risk", "strained"}:
        return
    actions = readiness.get("actions") or []
    body = str(readiness.get("summary") or "").strip()
    if actions:
        body = f"{body} {actions[0]}".strip()
    create_inbox_item(
        db,
        event.user_id,
        kind="recovery",
        title=(
            "恢复压力偏高"
            if readiness["status"] == "high_risk"
            else "恢复窗口偏紧"
        ),
        body=body,
        payload={
            "event_id": event.id,
            "event_type": event.type,
            "prompt": "我恢复得怎么样？",
            "readiness": readiness,
        },
    )


def consume_event(db: Session, event: DomainEvent) -> None:
    if event.type in {"WorkoutLogged", "WorkoutCompleted"}:
        create_inbox_item(
            db,
            event.user_id,
            kind="workout",
            title="训练已记录",
            body="这次训练已保存。想看看本周完成率和下一步调整吗？",
            capability_id="review.weekly",
            payload={"event_id": event.id, "event_type": event.type},
        )
        _create_readiness_nudge(db, event)
        return
    if event.type in {"TrainingPlanGenerated", "TrainingPlanAdjusted"}:
        create_inbox_item(
            db,
            event.user_id,
            kind="plan",
            title="训练计划已更新",
            body="新版本计划已经生效，打开训练手账查看。",
            payload={"event_id": event.id, "event_type": event.type},
        )
        return
    if event.type == "PlannedMealSkipped":
        create_inbox_item(
            db,
            event.user_id,
            kind="diet",
            title="今天有一餐跳过了",
            body="想看看今天还缺多少热量和蛋白质吗？",
            payload={
                "event_id": event.id,
                "prompt": "今天饮食还缺什么？",
            },
        )
