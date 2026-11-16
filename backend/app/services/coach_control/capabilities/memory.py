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
FORGET_CAPABILITY = register(
    Capability(
        id="memory.forget",
        domain="profile",
        kind="write",
        title="删除记忆",
        description="停用一条长期记忆，教练不再主动引用",
        requires_confirmation=True,
        undo=True,
        events=("MemoryForgotten",),
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


def _normalize_memory(value: str) -> str:
    return re.sub(r"[\s，,。；;、：:！!？?]+", "", value).lower()


def _memory_keywords(value: str) -> set[str]:
    text = _normalize_memory(value)
    if len(text) <= 2:
        return {text} if text else set()
    return {text[index : index + 2] for index in range(len(text) - 1)}


_CN_NUMBERS = {
    "一": 1,
    "二": 2,
    "两": 2,
    "三": 3,
    "四": 4,
    "五": 5,
    "六": 6,
    "七": 7,
    "八": 8,
    "九": 9,
    "十": 10,
}


def _cn_number(value: str) -> int | None:
    if value.isdigit():
        return int(value)
    return _CN_NUMBERS.get(value)


def resolve_forget(db: Session, user_id: str, message: str) -> dict:
    target = re.sub(
        r"^.*?(?:忘掉|忘记|删除|删掉|去掉|别再记(?:住)?|不要记(?:住)?)"
        r"[：:，,\s]*",
        "",
        message.strip(),
    )
    target = re.sub(
        r"^(?:关于|有关|我那条|那条|这条|我的)\s*",
        "",
        target,
    )
    target = re.sub(r"(?:这条|那条)$", "", target)
    target = re.sub(r"(?:记忆|偏好)$", "", target)
    target = re.sub(r"的$", "", target)
    target = target.strip(" 。.")
    memories = (
        db.execute(
            select(AIMemory)
            .where(
                AIMemory.user_id == user_id,
                AIMemory.active.is_(True),
            )
            .order_by(AIMemory.updated_at.desc(), AIMemory.created_at.desc())
        )
        .scalars()
        .all()
    )
    if not memories:
        return {"ready": False, "questions": ["还没有可删除的长期记忆。"]}
    ordinal = re.search(r"第\s*([一二两三四五六七八九十\d]+)\s*条", message)
    if ordinal is not None:
        index = _cn_number(ordinal.group(1))
        if index is None or not 1 <= index <= len(memories):
            return {
                "ready": False,
                "questions": ["没有这一条记忆，重新说一个序号试试。"],
            }
        item = memories[index - 1]
        return {
            "ready": True,
            "payload": {
                "memory_id": item.id,
                "content": item.content,
                "summary": f"准备删除记忆「{item.content[:60]}」",
            },
        }
    if target:
        normalized = _normalize_memory(target)
        matches = [
            item
            for item in memories
            if normalized and normalized in _normalize_memory(item.content)
        ]
        if not matches:
            keywords = _memory_keywords(target)
            scored = [
                (
                    sum(
                        1
                        for keyword in keywords
                        if keyword in _normalize_memory(item.content)
                    ),
                    item,
                )
                for item in memories
            ]
            best = max((score for score, _ in scored), default=0)
            if best > 0:
                matches = [
                    item for score, item in scored if score == best
                ]
    else:
        matches = list(memories)
    if not matches:
        return {
            "ready": False,
            "questions": ["没找到这条记忆，可以说得更具体一点。"],
        }
    if len(matches) > 1:
        examples = "；".join(
            item.content[:30] for item in matches[:3]
        )
        return {
            "ready": False,
            "questions": [
                f"找到 {len(matches)} 条相关记忆（{examples}），要删哪一条？"
            ],
        }
    item = matches[0]
    return {
        "ready": True,
        "payload": {
            "memory_id": item.id,
            "content": item.content,
            "summary": f"准备删除记忆「{item.content[:60]}」",
        },
    }


def execute_forget(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    item = db.get(AIMemory, str(payload.get("memory_id") or ""))
    if item is None or item.user_id != user_id or not item.active:
        raise LookupError("记忆不存在")
    before = {
        "memory": {
            "id": item.id,
            "content": item.content,
            "kind": item.kind,
            "memory_key": item.memory_key,
            "source": item.source,
            "confidence": item.confidence,
        }
    }
    item.active = False
    db.flush()
    return {
        "before": before,
        "memory_id": item.id,
        "content": item.content,
    }


def undo_forget(
    db: Session,
    user_id: str,
    before: dict,
    payload: dict,
) -> dict:
    memory_id = str(
        (before or {}).get("memory", {}).get("id")
        or payload.get("memory_id")
        or ""
    )
    item = db.get(AIMemory, memory_id)
    if item is None or item.user_id != user_id:
        raise LookupError("记忆不存在")
    item.active = True
    db.flush()
    return {"restored": True, "memory_id": item.id}

