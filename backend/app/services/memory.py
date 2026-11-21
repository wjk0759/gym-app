"""Durable, deduplicated coach memories.

Raw chat remains in chat_messages. This module turns stable user facts from a
request into compact rows that are loaded into future coach contexts.
"""

from __future__ import annotations

import asyncio
import json
import logging
import re
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from ..config import settings
from ..models import AIMemory, CoachTurn, Profile, utcnow
from . import llm
from .prompt_registry import prompt_version

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
SESSION_SUMMARY_KIND = "session_summary"
SESSION_SUMMARY_SOURCE = "coach_summary"
SESSION_SUMMARY_PROMPT = """你是「叫练」的会话摘要器。
把下面最近一段教练对话压缩成 4–6 句中文，供之后的教练继续对话使用。
保留：用户目标/偏好/约束、已确认的计划或饮食变更、未完成事项、重要决定。
不要编造，不要写寒暄，不要输出 Markdown，只输出摘要正文。"""
SESSION_SUMMARY_PROMPT_VERSION = prompt_version(
    "session_summary",
    SESSION_SUMMARY_PROMPT,
)

logger = logging.getLogger(__name__)

MEMORY_PROMPT = """你是「叫练」的记忆整理器。
只从用户的这一条消息里提取“未来会影响训练安排或教练回答”的稳定事实。
教练的回复不是事实来源：不要从教练的复述、建议、提问或推测里提取任何内容。
只输出 JSON，不要 Markdown：
{"memories":[{"kind":"schedule","key":"weekly_schedule","content":"用户每周二、四、六训练，每次 30 分钟","confidence":0.95}]}

规则：
1. 只记录用户明确说过的稳定偏好、约束、日程、器械、伤病、目标或行为习惯；不要记录一次性问题、寒暄、系统提示或助手猜测。
2. content 用一句中文概括，最多 120 字；不要包含密码、手机号、地址或其他密钥。
3. 没有值得长期记住的事实就返回 {"memories":[]}。
4. 最多 3 条；confidence 范围 0–1，低于 0.6 不要返回。
5. kind 只能是：preference、constraint、schedule、equipment、injury、goal、behavior。
6. key 用稳定的短标识，例如 weekly_schedule、session_minutes、home_equipment、knee_pain、preferred_split。
"""
MEMORY_PROMPT_VERSION = prompt_version("memory", MEMORY_PROMPT)


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


def _fact_conflicts_with_plan(
    db: Session,
    user_id: str,
    content: str,
) -> bool:
    """Drop memories that contradict the user's actual active plan.

    The extractor used to write "A/B 交替" while the real plan had A/B/C.
    Plan facts are cheap to verify, so verify them instead of trusting the
    model's paraphrase.
    """
    if not content or ("计划" not in content and "交替" not in content):
        return False
    from .queries import active_program

    program = active_program(db, user_id)
    if program is None:
        return False
    titles = " ".join(
        str(day.title or "")
        for day in program.days
        if day.week_index == 1
    )
    actual = set(re.findall(r"[A-Z]", titles))
    mentioned = set(re.findall(r"[A-Z]", content))
    if mentioned and actual and not mentioned <= actual:
        return True
    return bool("交替" in content and len(actual) >= 3 and len(mentioned) <= 2)


_BODY_NUMBER_RE = re.compile(r"\d{2,3}(?:\.\d+)?")


def memory_conflicts_with_profile(
    profile: Profile | None,
    memory_key: str,
    content: str,
) -> bool:
    """Drop old body facts that contradict the canonical profile.

    Profile and body metrics own height/weight. An old memory such as
    ``height_cm=180`` must not make the coach ask whether 175 or 180 is
    correct after the user edits the profile to 175.
    """
    if profile is None:
        return False
    text = f"{memory_key} {content}".lower()
    numbers = [
        float(value)
        for value in _BODY_NUMBER_RE.findall(content)
        if value
    ]
    if not numbers:
        return False
    if (
        profile.height_cm
        and ("height" in text or "身高" in text)
        and all(
            abs(value - float(profile.height_cm)) > 0.5
            for value in numbers
        )
    ):
        return True
    return bool(
        profile.weight_kg
        and ("weight" in text or "体重" in text)
        and all(
            abs(value - float(profile.weight_kg)) > 0.5
            for value in numbers
        )
    )


def list_memories(db: Session, user_id: str, limit: int = 20) -> list[AIMemory]:
    limit = max(1, min(50, int(limit)))
    profile = db.get(Profile, user_id)
    rows = list(
        db.execute(
            select(AIMemory)
            .where(
                AIMemory.user_id == user_id,
                AIMemory.active.is_(True),
                AIMemory.kind != "goal",
            )
            .order_by(
                AIMemory.updated_at.desc(),
                AIMemory.created_at.desc(),
            )
            .limit(max(limit * 4, 20))
        )
        .scalars()
        .all()
    )
    return [
        item
        for item in rows
        if not is_pending_action_fact(item.kind, item.content)
        and not memory_conflicts_with_profile(
            profile,
            item.memory_key,
            item.content,
        )
    ][:limit]


_GOAL_MEMORY_KEYS = (
    "training_goal",
    "training_phase",
    "weight_goal",
    "weight_loss_goal",
    "muscle_gain_goal",
    "muscle_gain_phase",
    "fat_loss_target",
)

_PENDING_ACTION_FACT_RE = re.compile(
    r"待确认执行|待确认|待执行|未确认|尚未执行|"
    r"已改到|已调整|已跳过|已删除|已换成|已经改|已经调整|"
    r"(?:将|把).{0,40}?(?:改到|调整到|改为|改成|换成|替换为|删掉|删除|跳过)|"
    r"要求.{0,24}?(?:改为|改成|换成|删除|跳过)|"
    r"要求.{0,24}?(?:增加|减少).{0,12}?(?:组|次|动作|训练|深蹲|卧推|硬拉|弓步)"
)
_SOFT_WISH_FACT_RE = re.compile(r"希望|想要|偏好|倾向于")
_PENDING_MARKERS = r"待确认|待执行|已改到|已调整|已跳过|已删除|已换成"


def is_pending_action_fact(kind: str, content: str) -> bool:
    """True when a memory describes an unconfirmed/executed plan change.

    The extractor used to write "已将周五 C 改到周六" after generating a
    confirmation card, even though the user never confirmed it. Such facts
    poison later schedule answers. A soft wish ("用户希望…") is allowed; an
    asserted/executed change is not.
    """
    text = content or ""
    if not _PENDING_ACTION_FACT_RE.search(text):
        return False
    return not (
        _SOFT_WISH_FACT_RE.search(text)
        and not re.search(_PENDING_MARKERS, text)
    )


def retire_goal_memories(db: Session, user_id: str) -> int:
    """Goal facts live in ``goals``/``profiles``, not in long-term memory.

    Old rows used to duplicate the goal and could contradict a pending or
    confirmed goal change. Retire them so the coach only reads the canonical
    active goal.
    """
    rows = list(
        db.execute(
            select(AIMemory).where(
                AIMemory.user_id == user_id,
                AIMemory.active.is_(True),
                or_(
                    AIMemory.kind == "goal",
                    AIMemory.memory_key.in_(_GOAL_MEMORY_KEYS),
                ),
            )
        )
        .scalars()
        .all()
    )
    for item in rows:
        item.active = False
    db.flush()
    return len(rows)


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
        key = _normalize_key(raw.get("key"), kind)
        content = _normalize_content(raw.get("content"))
        if (
            kind == "goal"
            or key in _GOAL_MEMORY_KEYS
            or re.search(
                r"目标改为|目标体重|体重目标|减脂目标|增肌目标|"
                r"增肌期|减脂期|训练目标",
                content,
            )
        ):
            # Goals are canonical in the goals/profile tables. A memory row
            # would go stale as soon as the user confirms a new target.
            continue
        if is_pending_action_fact(kind, content):
            # Never persist "已改到/待确认执行" from a confirmation card.
            continue
        if not content or len(content) < 4:
            continue
        try:
            confidence = max(0.0, min(1.0, float(raw.get("confidence", 1.0))))
        except (TypeError, ValueError):
            confidence = 1.0
        if confidence < 0.6:
            continue

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
    """Use the model to distill the user's own words into durable facts.

    ``assistant_reply`` stays in the signature for callers, but it is not sent
    to the extractor. In production smoke the model copied its own invented
    sentence ("你之前提过想用杠铃卧推...") into long-term memory, which then
    made the hallucination look like real history on the next turn.
    """
    if settings.use_mock_llm:
        return []
    # Punctuation-only or emoji-only turns carry no durable fact. Without this
    # guard the model sometimes echoes the example in the prompt ("每周二四六
    # 训练") when the user sends only "？？？？？？？？". Do not require a long
    # message: "我腰疼" is short but still worth extracting when called
    # directly.
    if not re.sub(r"[\s\W_]+", "", user_message):
        return []
    try:
        # Memory extraction must not pin a DB transaction during its LLM call.
        db.commit()
        raw = await llm.complete_json(
            MEMORY_PROMPT,
            json.dumps(
                {"user_message": user_message[:3000]},
                ensure_ascii=False,
            ),
            db=db,
            user_id=user_id,
            kind="memory",
            prompt_version=MEMORY_PROMPT_VERSION,
        )
        facts = raw.get("memories", []) if isinstance(raw, dict) else []
        if not isinstance(facts, list):
            return []
        facts = [fact for fact in facts if isinstance(fact, dict)]
        facts = [
            fact
            for fact in _dedupe_extracted_facts(facts)
            if not _fact_conflicts_with_plan(
                db,
                user_id,
                _normalize_content(fact.get("content")),
            )
        ]
        return remember_facts(
            db,
            user_id,
            facts,
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


def _as_utc(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def latest_session_summary(
    db: Session,
    user_id: str,
    session_id: str,
) -> str | None:
    item = db.execute(
        select(AIMemory).where(
            AIMemory.user_id == user_id,
            AIMemory.memory_key == f"session:{session_id}"[:80],
            AIMemory.kind == SESSION_SUMMARY_KIND,
            AIMemory.active.is_(True),
        )
    ).scalars().first()
    return item.content if item is not None else None


async def summarize_session(
    db: Session,
    user_id: str,
    session_id: str,
) -> AIMemory | None:
    """Compress the latest turns into one durable session summary."""
    turns = (
        db.execute(
            select(CoachTurn)
            .where(
                CoachTurn.user_id == user_id,
                CoachTurn.session_id == session_id,
            )
            .order_by(CoachTurn.created_at.desc(), CoachTurn.id.desc())
            .limit(20)
        )
        .scalars()
        .all()
    )
    if not turns:
        return None
    turns.reverse()
    last_turn = turns[-1]
    key = f"session:{session_id}"[:80]
    existing = db.execute(
        select(AIMemory).where(
            AIMemory.user_id == user_id,
            AIMemory.memory_key == key,
            AIMemory.kind == SESSION_SUMMARY_KIND,
        )
    ).scalars().first()
    if (
        existing is not None
        and existing.active
        and _as_utc(existing.updated_at) is not None
        and _as_utc(existing.updated_at) >= _as_utc(last_turn.created_at)
    ):
        return existing

    transcript = "\n".join(
        line
        for turn in turns
        for line in (
            [f"用户：{turn.input_text[:500]}"]
            + ([f"教练：{turn.reply[:500]}"] if turn.reply else [])
        )
    )
    if settings.use_mock_llm:
        summary = "；".join(turn.input_text[:80] for turn in turns[-4:])
        summary = f"最近对话：{summary}"[:1500]
    else:
        db.commit()
        try:
            summary = await llm.complete_text(
                SESSION_SUMMARY_PROMPT,
                transcript,
                temperature=0.2,
                db=db,
                user_id=user_id,
                kind="session_summary",
                prompt_version=SESSION_SUMMARY_PROMPT_VERSION,
            )
        except Exception:  # background summary must not break the coach
            logger.exception("Session summary generation failed")
            return existing
        summary = " ".join(summary.split())[:2000]

    if existing is None:
        existing = AIMemory(
            user_id=user_id,
            kind=SESSION_SUMMARY_KIND,
            memory_key=key,
            content=summary,
            source=SESSION_SUMMARY_SOURCE,
            confidence=0.8,
            active=True,
            updated_at=utcnow(),
        )
        db.add(existing)
    else:
        existing.content = summary
        existing.source = SESSION_SUMMARY_SOURCE
        existing.confidence = max(float(existing.confidence or 0), 0.8)
        existing.active = True
        existing.updated_at = utcnow()
    db.commit()
    return existing


async def _summarize_background(user_id: str, session_id: str) -> None:
    from ..db import SessionLocal

    with SessionLocal() as db:
        try:
            await summarize_session(db, user_id, session_id)
        except Exception:  # pragma: no cover - conservative background failure
            logger.exception("Session summary background task failed")
            db.rollback()


def schedule_session_summary(user_id: str, session_id: str) -> None:
    try:
        task = asyncio.create_task(
            _summarize_background(user_id, session_id)
        )
        task.add_done_callback(_log_background_failure)
    except RuntimeError:
        return


_QUERY_STOPWORDS = {
    "我们",
    "你们",
    "这个",
    "那个",
    "一下",
    "今天",
    "明天",
    "后天",
    "怎么",
    "什么",
    "可以",
    "还是",
    "然后",
    "就是",
    "现在",
    "刚才",
    "刚刚",
}


def _query_tokens(query: str) -> set[str]:
    tokens: set[str] = set()
    for chunk in re.findall(r"[\u4e00-\u9fff]{2,}", query):
        if len(chunk) <= 4:
            tokens.add(chunk)
        else:
            for size in (2, 3):
                for index in range(0, len(chunk) - size + 1):
                    tokens.add(chunk[index : index + size])
    return {token for token in tokens if token not in _QUERY_STOPWORDS}


def read_relevant_memories(
    db: Session,
    user_id: str,
    query: str,
    *,
    limit: int = 4,
) -> list[str]:
    """Keyword retrieval over durable memories; no vector store required."""
    rows = (
        db.execute(
            select(AIMemory)
            .where(
                AIMemory.user_id == user_id,
                AIMemory.active.is_(True),
                AIMemory.kind != "goal",
            )
            .order_by(AIMemory.updated_at.desc())
            .limit(120)
        )
        .scalars()
        .all()
    )
    rows = [
        item
        for item in rows
        if not is_pending_action_fact(item.kind, item.content)
    ]
    if not rows:
        return []
    tokens = _query_tokens(query)
    now = datetime.now(timezone.utc)
    scored: list[tuple[float, str]] = []
    for item in rows:
        content = str(item.content or "").strip()
        if not content:
            continue
        score = 0.0
        if tokens:
            score += sum(2.0 for token in tokens if token in content)
        if item.kind in {"preference", "constraint", "injury", "goal"}:
            score += 1.0
        updated = _as_utc(item.updated_at)
        if updated is not None:
            age_days = max(
                0.0,
                (now - updated).total_seconds() / 86400,
            )
            score += max(0.0, 3.0 - age_days / 30.0)
        if score <= 0:
            continue
        scored.append((score, content))
    scored.sort(key=lambda item: item[0], reverse=True)
    result: list[str] = []
    seen: set[str] = set()
    for _, content in scored:
        if content in seen:
            continue
        seen.add(content)
        result.append(content)
        if len(result) >= max(1, min(8, limit)):
            break
    return result
