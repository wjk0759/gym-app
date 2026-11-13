from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import AgentActionEvent
from . import food_actions  # noqa: F401 - registers built-in actions
from .registry import REGISTRY


def execute_action(
    db: Session,
    user_id: str,
    action_id: str,
    action_type: str,
    payload: dict,
) -> dict:
    event = db.execute(
        select(AgentActionEvent).where(
            AgentActionEvent.user_id == user_id,
            AgentActionEvent.action_id == action_id,
        )
    ).scalar_one_or_none()
    if (
        event is not None
        and event.status == "executed"
        and isinstance(event.detail, dict)
        and event.detail.get("result") is not None
    ):
        return event.detail["result"]

    spec = REGISTRY.get(action_type)
    if spec is None:
        raise ValueError(f"暂不支持动作：{action_type}")

    data = spec.payload_model.model_validate(payload)
    try:
        result = spec.execute(db, user_id, action_id, data)
    except Exception as exc:
        if event is None:
            event = AgentActionEvent(
                user_id=user_id,
                action_id=action_id,
                action_type=action_type,
                status="failed",
            )
            db.add(event)
        event.action_type = action_type
        event.status = "failed"
        event.message = str(exc)[:500]
        event.detail = {"payload": data.model_dump(mode="json")}
        db.commit()
        raise

    if event is None:
        event = AgentActionEvent(
            user_id=user_id,
            action_id=action_id,
            action_type=action_type,
            status="executed",
        )
        db.add(event)
    event.action_type = action_type
    event.status = "executed"
    event.message = "服务端已执行"
    event.detail = {
        "payload": data.model_dump(mode="json"),
        "result": result,
    }
    db.commit()
    return result


def undo_action(
    db: Session,
    user_id: str,
    action_id: str,
) -> dict:
    event = db.execute(
        select(AgentActionEvent).where(
            AgentActionEvent.user_id == user_id,
            AgentActionEvent.action_id == action_id,
        )
    ).scalar_one_or_none()
    if event is None or event.status != "executed":
        raise LookupError("这次操作已经不能撤销")
    spec = REGISTRY.get(event.action_type)
    if spec is None or spec.undo is None:
        raise ValueError("这个操作不支持撤销")
    detail = event.detail if isinstance(event.detail, dict) else {}
    payload = spec.payload_model.model_validate(detail.get("payload") or {})
    result = spec.undo(db, user_id, action_id, payload)
    event.status = "undone"
    event.message = "服务端已撤销"
    event.detail = {**detail, "undo_result": result}
    db.commit()
    return result
