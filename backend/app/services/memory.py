"""Durable, deduplicated coach memories.

Raw chat remains in chat_messages. This module turns stable user facts from a
request into compact rows that are loaded into future coach contexts.
"""

from __future__ import annotations

import asyncio
import json
import logging
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..config import settings
from ..models import AIMemory, utcnow
from . import llm

MEMORY_KINDS = {
    "preference",
    "constraint",
    "schedule",
    "equipment",
    "injury",
    "goal",
    "behavior",
}
REPLACE_KEYS = {
    "weekly_schedule",
    "training_days",
    "session_minutes",
    "equipment",
    "injury",
    "goal",
}
MAX_MEMORIES = 80

logger = logging.getLogger(__name__)

MEMORY_PROMPT = """你是 FitAI 的记忆整理器。
从用户和教练的一轮对话中提取“未来会影响训练安排或教练回答”的稳定事实。
只输出 JSON，不要 Markdown：
{"memories":[{"kind":"schedule","key":"weekly_schedule","content":"用户每周二、四、六训练，每次 30 分钟","confidence":0.95}]}

规则：
1. 只记录稳定偏好、约束、日程、器械、伤病、目标或行为习惯；不要记录一次性问题、寒暄、系统提示或助手猜测。
2. content 用一句中文概括，最多 120 字；不要包含密码、手机号、地址或其他密钥。
3. 没有值得长期记住的事实就返回 {"memories":[]}。
4. 最多 3 条；confidence 范围 0–1，低于 0.6 不要返回。
5. kind 只能是：preference、constraint、schedule、equipment、injury、goal、behavior。
6. key 用稳定的短标识，例如 weekly_schedule、session_minutes、home_equipment、knee_pain、preferred_split。
"""


def _normalize_key(value: Any, kind: str) -> str:
    text = str(value or kind).strip().lower().replace(" ", "_")
    return text[:80] or kind


def _normalize_content(value: Any) -> str:
    return " ".join(str(value or "").strip().split())[:500]


def _is_specific_fact(fact: dict) -> bool:
    kind = str(fact.get("kind", "")).lower()
    key = str(fact.get("key", "")).lower()
    return kind in {"schedule", "equipment", "injury", "goal"} or key in REPLACE_KEYS


def _dedupe_extracted_facts(facts: list[dict]) -> list[dict]:
    """Avoid saving a generic preference that just repeats a precise fact."""
    specific = [fact for fact in facts if _is_specific_fact(fact)]
    if not specific:
        return facts
    filtered: list[dict] = []
    for fact in facts:
        kind = str(fact.get("kind", "")).lower()
        key = str(fact.get("key", "")).lower()
        content = _normalize_content(fact.get("content"))
        if kind == "preference" and key in {"preference", "general"} and any(
            token in content
            for token in ("每周", "训练日", "分钟", "器械", "哑铃", "杠铃", "出差")
        ):
            continue
        filtered.append(fact)
    return filtered


def list_memories(db: Session, user_id: str, limit: int = 20) -> list[AIMemory]:
    limit = max(1, min(50, int(limit)))
    return list(
        db.execute(
            select(AIMemory)
            .where(AIMemory.user_id == user_id, AIMemory.active.is_(True))
            .order_by(
                AIMemory.updated_at.desc(),
                AIMemory.created_at.desc(),
            )
            .limit(limit)
        )
        .scalars()
        .all()
    )


def _trim_old_memories(db: Session, user_id: str) -> None:
    count = db.execute(
        select(func.count(AIMemory.id)).where(
            AIMemory.user_id == user_id,
            AIMemory.active.is_(True),
        )
    ).scalar_one()
    if count <= MAX_MEMORIES:
        return
    old = (
        db.execute(
            select(AIMemory)
            .where(AIMemory.user_id == user_id, AIMemory.active.is_(True))
            .order_by(AIMemory.created_at.asc())
            .limit(count - MAX_MEMORIES)
        )
        .scalars()
        .all()
    )
    for item in old:
        item.active = False


def remember_facts(
    db: Session,
    user_id: str,
    facts: list[dict],
    *,
    source: str = "agent",
) -> list[AIMemory]:
    """Upsert compact facts, replacing schedule/equipment facts by stable key."""
    saved: list[AIMemory] = []
    for raw in facts[:3]:
        if not isinstance(raw, dict):
            continue
        kind = str(raw.get("kind", "preference")).strip().lower()
        if kind not in MEMORY_KINDS:
            continue
        content = _normalize_content(raw.get("content"))
        if not content or len(content) < 4:
            continue
        try:
            confidence = max(0.0, min(1.0, float(raw.get("confidence", 1.0))))
        except (TypeError, ValueError):
            confidence = 1.0
        if confidence < 0.6:
            continue
        key = _normalize_key(raw.get("key"), kind)

        existing = None
        if key in REPLACE_KEYS:
            existing = db.execute(
                select(AIMemory).where(
                    AIMemory.user_id == user_id,
                    AIMemory.active.is_(True),
                    AIMemory.memory_key == key,
                )
            ).scalars().first()
        if existing is None:
            existing = db.execute(
                select(AIMemory).where(
                    AIMemory.user_id == user_id,
                    AIMemory.active.is_(True),
                    AIMemory.kind == kind,
                    AIMemory.content == content,
                )
            ).scalars().first()

        if existing is not None:
            existing.kind = kind
            existing.memory_key = key
            existing.content = content
            existing.source = source
            existing.confidence = max(existing.confidence, confidence)
            existing.updated_at = utcnow()
            existing.active = True
            saved.append(existing)
        else:
            item = AIMemory(
                user_id=user_id,
                kind=kind,
                memory_key=key,
                content=content,
                source=source,
                confidence=confidence,
                active=True,
                updated_at=utcnow(),
            )
            db.add(item)
            saved.append(item)
    db.flush()
    _trim_old_memories(db, user_id)
    db.commit()
    return saved


async def extract_and_store(
    db: Session,
    user_id: str,
    user_message: str,
    assistant_reply: str,
    *,
    source: str = "agent",
) -> list[AIMemory]:
    """Use the model to distill one turn into a few durable facts."""
    if settings.use_mock_llm:
        return []
    try:
        # Memory extraction must not pin a DB transaction during its LLM call.
        db.commit()
        raw = await llm.complete_json(
            MEMORY_PROMPT,
            json.dumps(
                {
                    "user_message": user_message[:3000],
                    "assistant_reply": assistant_reply[:3000],
                },
                ensure_ascii=False,
            ),
        )
        facts = raw.get("memories", []) if isinstance(raw, dict) else []
        if not isinstance(facts, list):
            return []
        facts = [fact for fact in facts if isinstance(fact, dict)]
        return remember_facts(
            db,
            user_id,
            _dedupe_extracted_facts(facts),
            source=source,
        )
    except Exception:  # memory extraction must never break the coach reply
        return []


async def extract_and_store_background(
    user_id: str,
    user_message: str,
    assistant_reply: str,
    *,
    source: str = "agent",
) -> None:
    """Run optional memory extraction after the user-facing reply.

    A fresh session is required because the request-scoped session is closed
    when the response returns. Failures are logged and deliberately ignored.
    """
    from ..db import SessionLocal

    with SessionLocal() as db:
        try:
            await extract_and_store(
                db,
                user_id,
                user_message,
                assistant_reply,
                source=source,
            )
        except Exception:  # pragma: no cover - conservative background failure
            logger.exception("Agent memory extraction failed")
            db.rollback()


def schedule_memory_extraction(
    user_id: str,
    user_message: str,
    assistant_reply: str,
    *,
    source: str = "agent",
) -> None:
    try:
        task = asyncio.create_task(
            extract_and_store_background(
                user_id,
                user_message,
                assistant_reply,
                source=source,
            )
        )
        task.add_done_callback(_log_background_failure)
    except RuntimeError:
        # No running loop (e.g. unit tests invoking the service directly).
        return


def _log_background_failure(task: asyncio.Task) -> None:
    if task.cancelled():
        return
    exc = task.exception()
    if exc is not None:
        logger.warning("Agent memory task failed: %s", exc)
