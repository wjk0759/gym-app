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
from ...reply_guard import strip_unsupported_injury_claims
from ..insights import build_readonly_context
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
    memory_book: str | None = None,
) -> dict:
    context_parts: list[str] = []
    # The answer prompt owns wording, not arithmetic. Append the relevant
    # server-side facts so "how many / did I improve / why this plan" answers
    # use real rows instead of the model guessing from the profile snapshot.
    insight = build_readonly_context(
        db,
        profile.user_id,
        message,
        program,
    )
    if insight:
        context_parts.append(insight)
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
        active = app_context.get("active_workout")
        if isinstance(active, dict) and active.get("current_name"):
            lines = [
                f"进行中的训练：{active.get('title') or '训练'}",
                f"当前动作：{active.get('current_name')}",
            ]
            planned = active.get("planned_sets")
            completed = active.get("completed_sets")
            if planned:
                lines.append(
                    f"当前动作计划 {planned} 组，已完成 {completed or 0} 组"
                )
            last_set = active.get("last_set")
            if isinstance(last_set, dict):
                weight = float(last_set.get("weight_kg") or 0)
                reps = int(last_set.get("reps") or 0)
                rpe = last_set.get("rpe")
                load = "自重" if weight <= 0 else f"{weight:g} kg"
                rpe_text = f"RPE {rpe}" if rpe is not None else "未记 RPE"
                lines.append(f"上一组：{load} × {reps} 次，{rpe_text}")
                if rpe is not None and float(rpe) >= 9:
                    lines.append(
                        "上一组 RPE 偏高：不要建议加重量，优先保持或降 5%，"
                        "并确认动作没有变形。"
                    )
            feeling = active.get("feeling")
            if isinstance(feeling, int) and feeling <= 2:
                lines.append("主观感受偏低：先降 1 组或降 5%，不要硬顶。")
            context_parts.append(
                "当前训练（客户端实时状态，只能据此回答，不要编造未给出的组数）：\n"
                + "\n".join(lines)
            )
    result = await coach_reply(
        db,
        profile,
        program,
        list(history),
        message,
        context="\n\n".join(context_parts) or None,
        memory_book=memory_book,
    )
    # Free-chat is the only capability that returns a long natural-language
    # answer, so it is also the place most likely to invent an old injury while
    # explaining plan choices. Deterministic cleanup runs after the model and
    # before the text is persisted by the control plane.
    if not result.get("safety_flag"):
        result = {
            **result,
            "reply": strip_unsupported_injury_claims(
                str(result.get("reply") or ""),
                has_injury_record=bool(
                    [item for item in (profile.injuries or []) if str(item).strip()]
                ),
            ),
        }
    return result
