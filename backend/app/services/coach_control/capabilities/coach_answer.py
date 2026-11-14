"""Free-form coach answer used when no write capability matches.

This keeps the control-plane session as the single text-chat ledger: the same
safety checks, quota, memory extraction and history apply to advice questions
and action requests.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

from sqlalchemy.orm import Session

from ....models import Profile, Program
from ...coach import coach_reply
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="coach.answer",
        domain="coach",
        kind="read",
        title="教练回答",
        description="回答训练、饮食、恢复等自由问题，不写入数据",
        requires_confirmation=False,
        undo=False,
        events=("CoachAnswerGenerated",),
    )
)


@dataclass(frozen=True)
class HistoryMessage:
    role: str
    content: str


async def resolve(
    db: Session,
    profile: Profile,
    program: Program | None,
    history: Iterable[HistoryMessage],
    message: str,
    app_context: dict | None = None,
) -> dict:
    context_parts: list[str] = []
    if isinstance(app_context, dict):
        body_context = str(app_context.get("body_analysis_context") or "").strip()
        if body_context:
            context_parts.append("体型分析：\n" + body_context)
        equipment = app_context.get("equipment_context")
        if isinstance(equipment, dict) and equipment.get("name"):
            detail = str(equipment.get("description") or "").strip()
            context_parts.append(
                "器械识别："
                + str(equipment.get("name"))
                + (f"。{detail}" if detail else "")
            )
    return await coach_reply(
        db,
        profile,
        program,
        list(history),
        message,
        context="\n\n".join(context_parts) or None,
    )
