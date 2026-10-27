"""Bounded coach agent: model chooses tools, Python owns all writes.

The model is deliberately not allowed to write a plan directly. It can read
context, ask for a proposal, and remember a preference. Applying a proposal is
a separate, user-authenticated endpoint.
"""

from __future__ import annotations

import json
import re
import time
from datetime import datetime, timedelta, timezone
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from ..config import settings
from ..models import (
    AgentPlanProposal,
    AgentRun,
    AgentStep,
    BodyMetric,
    ChatMessage,
    EquipmentLibraryItem,
    FoodLog,
    Goal,
    Profile,
    Program,
    WorkoutSession,
    utcnow,
)
from . import llm
from .coach import detect_safety
from .memory import extract_and_store, list_memories, remember_facts
from .plan_generator import build_template_plan
from .serializers import (
    goal_to_dict,
    program_load_options,
    profile_to_dict,
    save_plan,
)

MAX_STEPS = 7
PROPOSAL_TTL_MINUTES = 30
ALLOWED_TOOLS = {"get_context", "get_recent_training", "propose_plan", "remember"}

SPLIT_ALIASES = {
    "1分化": "1分化",
    "全身": "1分化",
    "全身训练": "1分化",
    "fullbody": "1分化",
    "full body": "1分化",
    "3分化": "3分化",
    "推拉腿": "3分化",
    "推/拉/腿": "3分化",
    "推、拉、腿": "3分化",
    "pushpulllegs": "3分化",
    "push pull legs": "3分化",
    "5分化": "5分化",
    "胸背腿肩手臂": "5分化",
    "胸/背/腿/肩/手臂": "5分化",
}


def _normalize_split(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip().lower().replace(" ", "")
    text = text.replace("，", "/").replace("、", "/").replace("\\", "/")
    text = re.sub(r"/+", "/", text)
    return SPLIT_ALIASES.get(text) or SPLIT_ALIASES.get(
        str(value).strip()
    )

SYSTEM_PROMPT = """你是 FitAI 教练 Agent，不是普通的单轮聊天机器人。
你可以读取用户状态、读取训练记录、生成计划草案和记录长期偏好，但你不能直接修改最终计划。

你每一步只能输出一个 JSON 对象，不要输出 Markdown：
{"action":"tool","tool":"get_context","arguments":{}}
{"action":"tool","tool":"get_recent_training","arguments":{"days":30}}
{"action":"tool","tool":"propose_plan","arguments":{"weekly_days":3,"weekdays":[2,4,6],"session_minutes":45,"split":"3分化","weeks":4}}
{"action":"tool","tool":"remember","arguments":{"kind":"preference","content":"用户出差期间只有哑铃"}}
{"action":"final","message":"给用户的最终回复"}
{"action":"ask_user","message":"需要补充的信息"}

规则：
1. 用户要调整训练计划、频率、训练日、时长、分化或器械时，先调用 get_context；如果需要评估近期执行情况，再调用 get_recent_training。
2. 只有用户明确描述训练安排或要求改计划时才调用 propose_plan。计划参数默认沿用用户档案，只修改用户明确提出的部分。
3. propose_plan 成功后会返回 proposal_id 和 changes。你要在 final 中告诉用户这是待确认草案，不能声称已经应用。
4. 用户只是问知识、动作、疼痛或恢复建议时，直接 final，不要为了使用工具而使用工具。
5. 疼痛、胸闷、晕厥、呼吸困难、孕期/术后等情况必须建议就医或停止相关训练，不做医疗诊断。
6. 不要编造工具、动作 slug、训练记录或用户信息。信息不足时用 ask_user。
7. 不要输出 JSON 以外的内容。"""


def _safe_json(value: Any) -> Any:
    """Make tool observations safe for JSON columns and the prompt."""
    try:
        return json.loads(json.dumps(value, ensure_ascii=False, default=str))
    except (TypeError, ValueError):
        return {"value": str(value)[:2000]}


def _program_summary(program: Program | None) -> dict | None:
    if program is None:
        return None
    first_week = [day for day in program.days if day.week_index == 1]
    return {
        "id": program.id,
        "title": program.title,
        "version": program.version,
        "weeks": program.weeks,
        "weekly_days": len(first_week),
        "weekdays": sorted(day.weekday for day in first_week),
        "day_titles": [day.title for day in first_week],
        "generated_by": program.generated_by,
    }


def _active_program(db: Session, user_id: str) -> Program | None:
    return (
        db.execute(
            select(Program)
            .options(program_load_options())
            .where(Program.user_id == user_id, Program.status == "active")
            .order_by(Program.version.desc())
        )
        .scalars()
        .first()
    )


def _active_goal(db: Session, user_id: str) -> Goal | None:
    return (
        db.execute(
            select(Goal).where(Goal.user_id == user_id, Goal.status == "active")
        )
        .scalars()
        .first()
    )


def _body_context(db: Session, user_id: str) -> list[dict]:
    rows = (
        db.execute(
            select(BodyMetric)
            .where(BodyMetric.user_id == user_id)
            .order_by(BodyMetric.measured_at.desc())
            .limit(5)
        )
        .scalars()
        .all()
    )
    return [
        {
            "date": item.measured_at.date().isoformat(),
            "weight_kg": item.weight_kg,
            "body_fat_pct": item.body_fat_pct,
            "waist_cm": item.waist_cm,
        }
        for item in rows
    ]


def _nutrition_context(db: Session, user_id: str, days: int = 7) -> dict:
    since = utcnow() - timedelta(days=max(1, min(30, days)))
    rows = (
        db.execute(
            select(FoodLog).where(
                FoodLog.user_id == user_id,
                FoodLog.logged_at >= since,
            )
        )
        .scalars()
        .all()
    )
    dates = {item.logged_at.date().isoformat() for item in rows}
    return {
        "days": days,
        "logged_days": len(dates),
        "kcal": round(sum(item.kcal for item in rows), 1),
        "protein_g": round(sum(item.protein for item in rows), 1),
        "carbs_g": round(sum(item.carbs for item in rows), 1),
        "fat_g": round(sum(item.fat for item in rows), 1),
        "fiber_g": round(sum(item.fiber for item in rows), 1),
    }


def _equipment_context(db: Session, user_id: str) -> list[dict]:
    rows = (
        db.execute(
            select(EquipmentLibraryItem)
            .where(EquipmentLibraryItem.user_id == user_id)
            .order_by(EquipmentLibraryItem.created_at.desc())
            .limit(20)
        )
        .scalars()
        .all()
    )
    return [
        {
            "name": item.name,
            "slug": item.slug,
            "muscle": item.muscle,
            "equipment": item.equipment,
            "notes": item.notes,
        }
        for item in rows
    ]


def _context(db: Session, user_id: str) -> dict:
    profile = db.get(Profile, user_id)
    program = _active_program(db, user_id) if profile is not None else None
    memories = list_memories(db, user_id, 20)
    memory_payload = [
        {"kind": item.kind, "key": item.memory_key, "content": item.content}
        for item in memories
    ]
    if profile is None:
        return {"needs_profile": True, "memories": memory_payload}
    return {
        "profile": profile_to_dict(profile),
        "goal": goal_to_dict(_active_goal(db, user_id)),
        "current_plan": _program_summary(program),
        "body_metrics": _body_context(db, user_id),
        "nutrition_7d": _nutrition_context(db, user_id, 7),
        "equipment_library": _equipment_context(db, user_id),
        "memories": memory_payload,
    }


def _recent_training(db: Session, user_id: str, days: int = 30) -> dict:
    days = max(1, min(90, int(days)))
    since = utcnow() - timedelta(days=days)
    sessions = (
        db.execute(
            select(WorkoutSession)
            .options(selectinload(WorkoutSession.sets))
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.started_at >= since,
            )
            .order_by(WorkoutSession.started_at.desc())
            .limit(30)
        )
        .scalars()
        .all()
    )
    total_volume = 0.0
    total_rpe = 0.0
    completed_sets = 0
    for session in sessions:
        for item in session.sets:
            if item.completed:
                completed_sets += 1
                total_volume += (item.weight_kg or 0) * (item.reps or 0)
                total_rpe += item.rpe or 0
    return {
        "days": days,
        "session_count": len(sessions),
        "completed_sets": completed_sets,
        "total_volume_kg": round(total_volume, 1),
        "average_rpe": round(total_rpe / completed_sets, 2) if completed_sets else None,
        "recent_sessions": [
            {
                "date": item.started_at.date().isoformat(),
                "duration_min": item.duration_min,
                "feeling": item.feeling,
                "set_count": len(item.sets),
            }
            for item in sessions[:10]
        ],
    }


def _weekday_label(value: int) -> str:
    return ["一", "二", "三", "四", "五", "六", "日"][max(0, min(6, value - 1))]


def _normalize_weekdays(raw: Any) -> list[int]:
    if not isinstance(raw, (list, tuple)):
        return []
    result = sorted({int(item) for item in raw if str(item).isdigit() and 1 <= int(item) <= 7})
    return result


def _make_changes(
    old_program: Program | None,
    old_profile: Profile,
    plan: dict,
    weekly_days: int,
    weekdays: list[int],
    session_minutes: int | None,
    split: str | None,
) -> list[str]:
    changes: list[str] = []
    old_weekly = 0
    if old_program:
        old_weekly = len(
            [day for day in old_program.days if day.week_index == 1]
        )
    if old_weekly and old_weekly != weekly_days:
        changes.append(f"每周训练 {old_weekly} → {weekly_days} 天")
    elif not old_weekly:
        changes.append(f"建立每周 {weekly_days} 天的训练节奏")
    if weekdays:
        changes.append("训练日：" + "、".join(f"周{_weekday_label(item)}" for item in weekdays))
    if session_minutes and session_minutes != old_profile.session_minutes:
        changes.append(f"单次训练 {old_profile.session_minutes or 45} → {session_minutes} 分钟")
    if split:
        changes.append(f"训练分化为 {split}")
    old_days = len(old_program.days) if old_program else 0
    new_days = len(plan.get("days", []))
    if old_days != new_days:
        changes.append(f"训练日数量 {old_days} → {new_days}")
    if old_program and old_program.title != plan.get("title"):
        changes.append(f"计划标题：{plan.get('title')}")
    return changes


def _serialize_proposal(proposal: AgentPlanProposal) -> dict:
    return {
        "id": proposal.id,
        "title": proposal.title,
        "status": proposal.status,
        "changes": (proposal.diff_data or {}).get("changes", []),
        "diff": proposal.diff_data or {},
        "validation": proposal.validation_data or {},
        "expires_at": proposal.expires_at.isoformat() if proposal.expires_at else None,
    }


def _record_step(
    db: Session,
    run: AgentRun,
    step_type: str,
    *,
    tool_name: str | None = None,
    input_data: dict | None = None,
    output_data: dict | None = None,
    status: str = "ok",
    error: str | None = None,
    latency_ms: int | None = None,
) -> None:
    run.step_count += 1
    db.add(
        AgentStep(
            run_id=run.id,
            step_index=run.step_count,
            step_type=step_type,
            tool_name=tool_name,
            input_json=_safe_json(input_data or {}),
            output_json=_safe_json(output_data or {}),
            status=status,
            error=error,
            latency_ms=latency_ms,
        )
    )


def _tool_result(
    db: Session,
    run: AgentRun,
    user_id: str,
    tool: str,
    arguments: dict,
) -> dict:
    if tool == "get_context":
        return {"ok": True, "context": _context(db, user_id)}
    if tool == "get_recent_training":
        return {"ok": True, **_recent_training(db, user_id, int(arguments.get("days", 30)))}
    if tool == "remember":
        kind = str(arguments.get("kind", "preference"))[:30]
        content = str(arguments.get("content", "")).strip()[:1000]
        if not content:
            return {"ok": False, "error": "memory content is empty"}
        saved = remember_facts(
            db,
            user_id,
            [{"kind": kind, "content": content, "confidence": 1.0}],
            source="agent",
        )
        return {
            "ok": True,
            "remembered": [
                {"kind": item.kind, "key": item.memory_key, "content": item.content}
                for item in saved
            ],
        }
    if tool == "propose_plan":
        profile = db.get(Profile, user_id)
        if profile is None:
            return {"ok": False, "error": "用户还没有完成个人档案"}
        weekdays = _normalize_weekdays(arguments.get("weekdays"))
        weekly_days = len(weekdays) if weekdays else max(
            1, min(7, int(arguments.get("weekly_days") or profile.weekly_days or 3))
        )
        session_minutes = arguments.get("session_minutes")
        if session_minutes is not None:
            session_minutes = max(15, min(180, int(session_minutes)))
        split = _normalize_split(arguments.get("split"))
        weeks = max(1, min(8, int(arguments.get("weeks") or 4)))
        try:
            built = build_template_plan(
                db,
                profile,
                _active_goal(db, user_id).type if _active_goal(db, user_id) else "recomp",
                weeks=weeks,
                split=split,
                weekly_days=weekly_days,
                session_minutes=session_minutes,
                weekdays=weekdays,
            )
        except Exception as exc:  # noqa: BLE001 - tool error is returned to the model
            return {"ok": False, "error": str(exc)[:500]}

        plan = built["plan"]
        old_program = _active_program(db, user_id)
        changes = _make_changes(
            old_program,
            profile,
            plan,
            weekly_days,
            weekdays,
            session_minutes,
            split,
        )
        diff = {
            "changes": changes,
            "base": _program_summary(old_program),
            "proposed": {
                "title": plan.get("title"),
                "weekly_days": weekly_days,
                "weekdays": weekdays,
                "session_minutes": session_minutes or profile.session_minutes or 45,
                "weeks": weeks,
                "day_count": len(plan.get("days", [])),
            },
        }
        for old in db.execute(
            select(AgentPlanProposal).where(
                AgentPlanProposal.user_id == user_id,
                AgentPlanProposal.status == "draft",
            )
        ).scalars():
            old.status = "superseded"
        proposal = AgentPlanProposal(
            user_id=user_id,
            run_id=run.id,
            base_program_id=old_program.id if old_program else None,
            base_version=old_program.version if old_program else None,
            status="draft",
            title=plan.get("title", "训练计划")[:120],
            plan_data=plan,
            diff_data=diff,
            validation_data={"warnings": built["warnings"], "valid": True},
            expires_at=utcnow() + timedelta(minutes=PROPOSAL_TTL_MINUTES),
        )
        db.add(proposal)
        db.commit()
        return {"ok": True, "proposal": _serialize_proposal(proposal)}
    return {"ok": False, "error": f"unknown tool: {tool}"}


def _mock_agent_response(db: Session, user_id: str) -> str:
    # The normal app uses its local coach when no LLM key is configured.
    if db.get(Profile, user_id) is None:
        return "请先完成个人档案，我才能读取你的训练条件并安排计划。"
    return "AI 服务暂时不可用。我可以先读取你的本地训练记录，但这次没有生成新的计划草案。"


async def run_agent(
    db: Session,
    user_id: str,
    message: str,
    *,
    session_id: str | None = None,
    history: list[ChatMessage] | None = None,
) -> dict:
    run = AgentRun(
        user_id=user_id,
        session_id=session_id,
        intent="plan_change" if any(word in message for word in ("计划", "安排", "每周", "训练日", "频率")) else "coach_chat",
        status="running",
        model=settings.llm_model,
        input_text=message[:4000],
    )
    db.add(run)
    db.flush()

    observations: list[dict] = []
    final_message: str | None = None
    proposal: AgentPlanProposal | None = None
    error: str | None = None
    started = time.perf_counter()

    safety_flag, safety_reply = detect_safety(message)
    if safety_reply:
        final_message = safety_reply
        run.status = "completed"
        run.output_text = final_message
        run.completed_at = utcnow()
        db.commit()
        return {
            "run_id": run.id,
            "status": run.status,
            "reply": final_message,
            "proposal": None,
            "elapsed_ms": int((time.perf_counter() - started) * 1000),
        }

    try:
        if settings.use_mock_llm:
            final_message = _mock_agent_response(db, user_id)
            run.status = "failed"
            error = "LLM is not configured"
        else:
            state = {
                "user_message": message,
                "current_date": datetime.now(timezone.utc).date().isoformat(),
                "history": [
                    {"role": item.role, "content": item.content[:1000]}
                    for item in (history or [])[-10:]
                    if item.role in {"user", "assistant"}
                ],
                "observations": observations,
                "allowed_tools": sorted(ALLOWED_TOOLS),
                "max_steps": MAX_STEPS,
            }
            for _ in range(MAX_STEPS):
                step_started = time.perf_counter()
                raw = await llm.complete_json(
                    SYSTEM_PROMPT,
                    json.dumps(state, ensure_ascii=False),
                )
                _record_step(
                    db,
                    run,
                    "decision",
                    input_data={"state_step": run.step_count + 1},
                    output_data={"action": raw},
                    latency_ms=int((time.perf_counter() - step_started) * 1000),
                )
                action = str(raw.get("action", "final"))
                if action == "tool":
                    tool = str(raw.get("tool", ""))
                    arguments = raw.get("arguments") if isinstance(raw.get("arguments"), dict) else {}
                    tool_started = time.perf_counter()
                    try:
                        result = _tool_result(db, run, user_id, tool, arguments)
                        status = "ok" if result.get("ok", True) else "error"
                        tool_error = None if status == "ok" else str(result.get("error", ""))[:500]
                    except Exception as exc:  # noqa: BLE001 - tool failures return to model
                        result = {"ok": False, "error": str(exc)[:500]}
                        status = "error"
                        tool_error = str(exc)[:500]
                    _record_step(
                        db,
                        run,
                        "tool",
                        tool_name=tool,
                        input_data=arguments,
                        output_data=result,
                        status=status,
                        error=tool_error,
                        latency_ms=int((time.perf_counter() - tool_started) * 1000),
                    )
                    observations.append({"tool": tool, "result": result})
                    state["observations"] = observations
                    if isinstance(result.get("proposal"), dict):
                        proposal = db.get(
                            AgentPlanProposal,
                            result["proposal"].get("id"),
                        )
                    continue
                if action in {"final", "ask_user"}:
                    final_message = str(raw.get("message", "")).strip()
                    break
                observations.append(
                    {
                        "error": "invalid action",
                        "allowed_actions": ["tool", "final", "ask_user"],
                    }
                )
                state["observations"] = observations

        if not final_message:
            final_message = "我需要再确认一下你的目标。你希望调整训练日、频率，还是训练时长？"
        if proposal is None:
            proposal = (
                db.execute(
                    select(AgentPlanProposal)
                    .where(AgentPlanProposal.run_id == run.id)
                    .order_by(AgentPlanProposal.created_at.desc())
                )
                .scalars()
                .first()
            )
        if proposal is not None and run.status == "running":
            run.status = "needs_confirmation"
        elif run.status == "running":
            run.status = "completed"
        run.output_text = final_message[:4000]
        run.completed_at = utcnow()
        db.commit()
        if not settings.use_mock_llm and run.status != "failed" and db.get(Profile, user_id):
            await extract_and_store(
                db,
                user_id,
                message,
                final_message,
                source="agent",
            )
    except Exception as exc:  # noqa: BLE001 - agent failures must be visible in the run
        db.rollback()
        run = db.get(AgentRun, run.id)
        if run is None:
            raise
        run.status = "failed"
        run.error = str(exc)[:1000]
        run.output_text = "教练 Agent 暂时不可用，请稍后再试。"
        run.completed_at = utcnow()
        db.commit()
        final_message = run.output_text

    return {
        "run_id": run.id,
        "status": run.status,
        "reply": final_message or "",
        "proposal": _serialize_proposal(proposal) if proposal else None,
        "elapsed_ms": int((time.perf_counter() - started) * 1000),
    }


def apply_proposal(db: Session, user_id: str, proposal_id: str) -> tuple[Program, AgentPlanProposal]:
    proposal = db.get(AgentPlanProposal, proposal_id)
    if proposal is None or proposal.user_id != user_id:
        raise LookupError("计划草案不存在")
    if proposal.status != "draft":
        raise ValueError("计划草案已经处理过")
    expires = proposal.expires_at
    if expires is not None and expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if expires is not None and expires < utcnow():
        proposal.status = "expired"
        db.commit()
        raise ValueError("计划草案已过期，请重新生成")
    current = _active_program(db, user_id)
    if proposal.base_program_id and (
        current is None
        or current.id != proposal.base_program_id
        or current.version != proposal.base_version
    ):
        raise RuntimeError("当前计划已经变化，请重新生成草案")

    program = save_plan(
        db,
        user_id,
        proposal.plan_data,
        goal_type=(
            _active_goal(db, user_id).type if _active_goal(db, user_id) else "recomp"
        ),
        generated_by="agent",
        model_name=settings.llm_model if not settings.use_mock_llm else "template",
    )
    profile = db.get(Profile, user_id)
    proposed = (proposal.diff_data or {}).get("proposed") or {}
    if profile is not None:
        if proposed.get("weekly_days"):
            profile.weekly_days = max(1, min(7, int(proposed["weekly_days"])))
        if proposed.get("session_minutes"):
            profile.session_minutes = max(15, min(180, int(proposed["session_minutes"])))
    proposal.status = "applied"
    proposal.applied_at = utcnow()
    if proposal.run_id:
        run = db.get(AgentRun, proposal.run_id)
        if run is not None:
            run.status = "completed"
            run.completed_at = utcnow()
    db.commit()
    return program, proposal
