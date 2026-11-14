"""Domain-event consumers that feed the coach inbox."""

from __future__ import annotations

from sqlalchemy.orm import Session

from ...models import DomainEvent
from .events import create_inbox_item


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
