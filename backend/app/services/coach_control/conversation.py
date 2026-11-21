"""Shared conversation context for every coach capability.

The control plane used to build history ad hoc for free-form answers while
deterministic capabilities (food, weight, plan edits) only saw the current
message. That split is what made the coach look like it had no memory: the
same user turn could reference a photo estimate in chat and then be treated as
a brand-new sentence by the food parser.

This module builds one bounded snapshot per turn:

* recent turns (default 50) for conversation continuity
* the active pending/draft state
* the last executed action and its age
* a compact long-term memory book

Capabilities may use the whole snapshot or only the slice they need. The 50
turns are also rendered as a bounded prompt string, never as raw JSON.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import (
    AIMemory,
    CoachActionRecord,
    CoachPending,
    CoachSession,
    CoachTurn,
    Profile,
)
from ..equipment_inventory import effective_equipment_types
from ..memory import (
    is_pending_action_fact,
    latest_session_summary,
    read_relevant_memories,
)
from ..queries import active_goal, active_program
from .state import get_active_pending

DIET_TZ = ZoneInfo("Asia/Shanghai")
DEFAULT_MAX_TURNS = 50
DEFAULT_MAX_PROMPT_TURNS = 20
DEFAULT_MAX_PROMPT_CHARS = 12000
DEFAULT_RECENT_ACTION_MINUTES = 15


@dataclass(frozen=True)
class HistoryItem:
    role: str
    content: str


@dataclass(frozen=True)
class ConversationTurn:
    id: str
    input_text: str
    reply: str | None
    intent: str | None
    created_at: datetime | None


@dataclass
class ConversationContext:
    turns: list[ConversationTurn]
    pending: CoachPending | None
    last_action: CoachActionRecord | None
    memory_book: str
    summary: str | None = None
    retrieved_memories: list[str] = field(default_factory=list)

    def memory_context_text(self) -> str:
        parts: list[str] = []
        if self.memory_book:
            parts.append(self.memory_book)
        if self.summary:
            parts.append("[更早会话摘要]\n" + self.summary)
        seen = {part.strip() for part in parts if part.strip()}
        for content in self.retrieved_memories:
            text = content.strip()
            if not text or text in seen:
                continue
            if self.summary and text in self.summary:
                continue
            if text in self.memory_book:
                continue
            seen.add(text)
            parts.append("- " + text)
        return "\n\n".join(parts)[:9000]

    def history_items(self, *, max_turns: int | None = None) -> list[HistoryItem]:
        rows = self.turns[-max_turns:] if max_turns else self.turns
        items: list[HistoryItem] = []
        for turn in rows:
            if turn.input_text.strip():
                items.append(HistoryItem(role="user", content=turn.input_text))
            if turn.reply and turn.reply.strip():
                items.append(HistoryItem(role="assistant", content=turn.reply))
        return items

    def prompt_text(
        self,
        *,
        max_turns: int = DEFAULT_MAX_PROMPT_TURNS,
        max_chars: int = DEFAULT_MAX_PROMPT_CHARS,
    ) -> str:
        """Render recent turns as compact, human-readable text.

        JSON is intentionally not used here: keys and escaping waste tokens and
        make it harder for the model to scan a long transcript.
        """
        rows = self.turns[-max_turns:]
        lines: list[str] = []
        used = 0
        for turn in reversed(rows):
            stamp = _local_stamp(turn.created_at)
            block: list[str] = []
            if turn.input_text.strip():
                block.append(f"{stamp} 用户：{turn.input_text.strip()[:800]}")
            if turn.reply and turn.reply.strip():
                block.append(f"{stamp} 教练：{turn.reply.strip()[:800]}")
            if not block:
                continue
            addition = "\n".join(block)
            if lines and used + len(addition) > max_chars:
                break
            lines.insert(0, addition)
            used += len(addition)
        return "\n".join(lines)

    def task_state_text(self) -> str:
        parts: list[str] = []
        if self.pending is not None:
            payload = self.pending.payload or {}
            summary = str(payload.get("summary") or payload.get("text") or "")[:300]
            parts.append(
                f"待处理：{self.pending.capability_id} / {self.pending.kind}"
                + (f"；{summary}" if summary else "")
            )
        if self.last_action is not None:
            age = _age_minutes(self.last_action.created_at)
            parts.append(
                f"上一动作：{self.last_action.capability_id}"
                + (f"（{age} 分钟前）" if age is not None else "")
            )
        return "\n".join(parts)

    def reference_context(self) -> str:
        """A short slice used by deterministic resolvers for anaphora."""
        return self.prompt_text(max_turns=8, max_chars=5000)


def _as_utc(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _local_stamp(value: datetime | None) -> str:
    moment = _as_utc(value)
    if moment is None:
        return ""
    return moment.astimezone(DIET_TZ).strftime("%m-%d %H:%M")


def _age_minutes(value: datetime | None) -> int | None:
    moment = _as_utc(value)
    if moment is None:
        return None
    return max(0, int((datetime.now(timezone.utc) - moment).total_seconds() // 60))


def build_memory_book(db: Session, user_id: str) -> str:
    """Compact facts a coach should never forget, independent of raw chat."""
    lines: list[str] = []
    profile = db.get(Profile, user_id)
    goal = active_goal(db, user_id)
    program = active_program(db, user_id)
    if profile is not None:
        equipment = effective_equipment_types(db, user_id)
        facts = [
            f"目标 {goal.type}" if goal is not None else "",
            f"每周 {profile.weekly_days} 练" if profile.weekly_days else "",
            f"每次 {profile.session_minutes} 分钟" if profile.session_minutes else "",
            f"伤病 {', '.join(profile.injuries or [])}" if profile.injuries else "",
            f"器械 {', '.join(equipment)}" if equipment else "",
        ]
        facts = [item for item in facts if item]
        if facts:
            lines.append("基础：" + "；".join(facts))
    if program is not None:
        lines.append(f"当前计划：{program.title}（{program.weeks} 周）")
    memories = (
        db.execute(
            select(AIMemory)
            .where(
                AIMemory.user_id == user_id,
                AIMemory.active.is_(True),
                AIMemory.kind != "session_summary",
            )
            .order_by(AIMemory.updated_at.desc())
            .limit(24)
        )
        .scalars()
        .all()
    )
    for item in memories:
        content = str(item.content or "").strip()
        if not content:
            continue
        # A pending/executed action fact is not a durable user preference. Old
        # injury memories must not contradict an empty profile.injuries list.
        if is_pending_action_fact(item.kind, content):
            continue
        if item.kind == "goal":
            continue
        if (
            item.kind == "injury"
            and profile is not None
            and not (profile.injuries or [])
        ):
            continue
        lines.append(f"- {content[:200]}")
    return "\n".join(lines)[:6000]


def build_conversation_context(
    db: Session,
    user_id: str,
    session_id: str,
    *,
    exclude_turn_id: str | None = None,
    max_turns: int = DEFAULT_MAX_TURNS,
    query: str | None = None,
) -> ConversationContext:
    statement = select(CoachTurn).where(
        CoachTurn.user_id == user_id,
        CoachTurn.session_id == session_id,
    )
    if exclude_turn_id:
        statement = statement.where(CoachTurn.id != exclude_turn_id)
    rows = (
        db.execute(
            statement.order_by(
                CoachTurn.created_at.desc(),
                CoachTurn.id.desc(),
            ).limit(max(1, min(200, max_turns)))
        )
        .scalars()
        .all()
    )
    rows.reverse()
    turns = [
        ConversationTurn(
            id=item.id,
            input_text=item.input_text or "",
            reply=item.reply,
            intent=item.intent,
            created_at=item.created_at,
        )
        for item in rows
    ]
    session = db.get(CoachSession, session_id)
    pending = (
        get_active_pending(db, user_id, session_id) if session is not None else None
    )
    last_action = (
        db.execute(
            select(CoachActionRecord)
            .where(
                CoachActionRecord.user_id == user_id,
                CoachActionRecord.session_id == session_id,
            )
            .order_by(CoachActionRecord.created_at.desc())
            .limit(1)
        )
        .scalars()
        .first()
    )
    return ConversationContext(
        turns=turns,
        pending=pending,
        last_action=last_action,
        memory_book=build_memory_book(db, user_id),
        summary=latest_session_summary(db, user_id, session_id),
        retrieved_memories=(
            read_relevant_memories(db, user_id, query, limit=4)
            if query and len(turns) >= 6
            else []
        ),
    )
