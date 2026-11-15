"""Typed context passed to coach capabilities.

The iOS app still sends a plain ``app_context`` dictionary. The runtime wraps
that wire payload once per turn, resolves references, and passes this object to
capabilities. Keeping it a ``dict`` subclass means existing ``context.get(...)``
code keeps working while new code can use typed properties.
"""

from __future__ import annotations

from typing import Any

from .conversation import ConversationContext
from .references import ReferenceSet, resolve_references


class CapabilityContext(dict):
    def __init__(
        self,
        raw: dict[str, Any],
        conversation: ConversationContext,
        message: str,
    ):
        super().__init__(raw)
        self.conversation = conversation
        self.references: ReferenceSet = resolve_references(
            message,
            conversation.turns,
            pending=conversation.pending,
            plan=self.get("plan") if isinstance(self.get("plan"), dict) else None,
        )
        self["references"] = self.references.as_dict()
        self["recent_turns"] = tuple(conversation.turns[-6:])
        self["conversation_text"] = conversation.prompt_text(
            max_turns=12,
            max_chars=6000,
        )
        self["task_state"] = conversation.task_state_text()
        self["memory_book"] = conversation.memory_book
        self["memory_summary"] = conversation.summary
        self["retrieved_memories"] = tuple(conversation.retrieved_memories)

    @property
    def plan(self) -> dict | None:
        value = self.get("plan")
        return value if isinstance(value, dict) else None

    @property
    def today_day(self) -> dict | None:
        value = self.get("today_day")
        return value if isinstance(value, dict) else None

    @property
    def task_state(self) -> str:
        return str(self.get("task_state") or "")

    @property
    def recent_turns(self) -> tuple:
        return self["recent_turns"]

    @property
    def memory_summary(self) -> str | None:
        value = self.get("memory_summary")
        return str(value) if value else None

    @property
    def retrieved_memories(self) -> tuple[str, ...]:
        return self["retrieved_memories"]
