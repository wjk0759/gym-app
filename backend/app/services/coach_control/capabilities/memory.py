"""Remember an explicit user preference in the coach memory table."""

from __future__ import annotations

import hashlib
import re

from sqlalchemy import select
from sqlalchemy.orm import Session

from ....models import AIMemory, utcnow
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="memory.remember",
        domain="profile",
        kind="write",
        title="记住偏好",
        description="把用户明确要求记住的偏好写入长期记忆",
        requires_confirmation=True,
        undo=True,
        events=("MemoryRemembered",),
        refreshes=("profile",),
    )
)


def resolve(message: str) -> dict:
    match = re.match(
        r"^(?:请)?(?:帮我)?(?:记住|记一下|记下)[：:，,\s]*(.+)$",
        message.strip(),
    )
    content = (match.group(1) if match else "").strip()
    if len(content) < 3:
        return {
            "ready": False,
            "questions": ["想让我记住什么？例如“记住我每周二四六练”。"],
        }
    return {
        "ready": True,
        "payload": {"content": content[:500]},
        "summary": f"准备记住：{content[:80]}。",
    }


def execute(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    content = str(payload.get("content") or "")[:500]
    # One active memory per memory_key is enforced by the production schema.
    # Never reuse "general": auto-extracted memories own it.
    digest = hashlib.sha1(content.encode("utf-8")).hexdigest()[:16]
    memory_key = f"explicit:{digest}"
    item = (
        db.execute(
            select(AIMemory).where(
                AIMemory.user_id == user_id,
                AIMemory.memory_key == memory_key,
                AIMemory.active.is_(True),
            )
        )
        .scalars()
        .first()
    )
    if item is None:
        item = AIMemory(
            user_id=user_id,
            kind="preference",
            memory_key=memory_key,
            content=content,
            source="coach_control",
            confidence=1.0,
            active=True,
        )
        db.add(item)
    else:
        item.content = content
        item.updated_at = utcnow()
    db.flush()
    return {"memory_id": item.id, "content": item.content}


def undo(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    item = (
        db.execute(
            select(AIMemory)
            .where(
                AIMemory.user_id == user_id,
                AIMemory.content == str(payload.get("content") or "")[:500],
                AIMemory.source == "coach_control",
                AIMemory.active.is_(True),
            )
            .order_by(AIMemory.created_at.desc(), AIMemory.id.desc())
        )
        .scalars()
        .first()
    )
    if item is not None:
        item.active = False
        db.flush()
    return {"restored": True}
