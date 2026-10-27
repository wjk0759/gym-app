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
from uuid import uuid4

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
ALLOWED_TOOLS = {
    "get_context",
    "get_recent_training",
    "propose_plan",
    "propose_app_actions",
    "remember",
}
APP_ACTION_TYPES = {
    "reschedule_training",
    "skip_training",
    "start_training",
    "open_screen",
    "update_goal",
}
APP_SCREENS = {
    "today",
    "plan",
    "coach",
    "equipment",
    "profile",
    "training_schedule",
    "nutrition",
    "body_checkin",
    "profile_edit",
    "workout_history",
    "agent_memory",
    "period_schedule",
}

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
你可以读取用户状态、读取训练记录、生成计划草案、记录长期偏好，并为用户准备 App 内的可执行操作。

你每一步只能输出一个 JSON 对象，不要输出 Markdown：
{"action":"tool","tool":"get_context","arguments":{}}
{"action":"tool","tool":"get_recent_training","arguments":{"days":30}}
{"action":"tool","tool":"propose_plan","arguments":{"weekly_days":3,"weekdays":[2,4,6],"session_minutes":45,"split":"3分化","weeks":4}}
{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[{"type":"reschedule_training","title":"把明天的训练改到周四","summary":"保留原训练内容，只调整日期","requires_confirmation":true,"payload":{"day_id":"本地训练日ID","target_date":"2026-10-29"}}]}}
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
7. 不要输出 JSON 以外的内容。
8. 给出训练建议前，至少参考 get_context 或 get_recent_training 中的一项真实信息；优先引用用户的当前计划、训练日、器械、伤病或最近完成情况。
9. 不要用泛泛的“多喝水、坚持训练、循序渐进”凑字数。先给结论，再给 2–3 个具体动作/组数/重量/时间建议，并说明依据。
10. 如果用户的安排已经发生变化，直接指出哪一天、哪个动作或哪个参数需要改，不要重复整份计划。

App Context 和可执行操作：
- state.app_context 是 iOS 本地计划日期和当前页面，包含 plan.days（day_id/title/date/completed/skipped）以及 today。
- 用户要求改期、跳过、开始训练、打开页面或修改目标时，必须调用 propose_app_actions，不要只在 final 里描述。
- 只能使用这些 action type：reschedule_training、skip_training、start_training、open_screen、update_goal。
- reschedule_training / skip_training 优先使用 app_context 里存在的 day_id；也可以传 date（YYYY-MM-DD）。改期目标用 target_date；如果用户说“最近空档”，target_date 传 "next_free"。
- open_screen 的 payload.screen 只能是：today、plan、coach、equipment、profile、training_schedule、nutrition、body_checkin、profile_edit、workout_history、agent_memory、period_schedule。
- update_goal 的 payload 字段可包含 goal_type（lose_fat/build_muscle/recomp/endurance）、target_weight_kg、target_date、weekly_days、session_minutes。
- 不要声称操作已执行。final 中应说明“已准备好操作，请确认”，不要声称页面已经打开、训练已经开始或训练已经改期；由 iOS 确认后执行。
- 所有操作（包括 open_screen）都必须让用户点击操作卡后再执行。
"""


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
    if memories:
        used_at = utcnow()
        for item in memories:
            item.last_used_at = used_at
        db.flush()
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


def _normalize_app_actions(
    raw_actions: Any, app_context: dict | None = None
) -> list[dict]:
    if not isinstance(raw_actions, list) or not raw_actions:
        raise ValueError("actions must be a non-empty list")
    if len(raw_actions) > 3:
        raise ValueError("at most 3 actions are allowed")

    plan_days = []
    if isinstance(app_context, dict):
        plan = app_context.get("plan")
        if isinstance(plan, dict):
            plan_days = plan.get("days") if isinstance(plan.get("days"), list) else []
    allowed_day_ids = {
        str(item.get("id"))
        for item in plan_days
        if isinstance(item, dict) and item.get("id")
    }

    result: list[dict] = []
    for raw in raw_actions:
        if not isinstance(raw, dict):
            continue
        action_type = str(raw.get("type", "")).strip()
        if action_type not in APP_ACTION_TYPES:
            raise ValueError(f"unsupported action type: {action_type}")

        payload = raw.get("payload")
        payload = payload if isinstance(payload, dict) else {}
        day_id = str(payload.get("day_id", "")).strip()
        if day_id and allowed_day_ids and day_id not in allowed_day_ids:
            raise ValueError("day_id is not present in app_context")
        date_value = str(payload.get("date", "")).strip()
        target_date = str(payload.get("target_date", "")).strip()

        def valid_date(value: str) -> bool:
            if not value:
                return False
            try:
                datetime.strptime(value, "%Y-%m-%d")
                return True
            except ValueError:
                return False

        if action_type in {"reschedule_training", "skip_training"}:
            if not day_id and not valid_date(date_value):
                raise ValueError(f"{action_type} requires day_id or date")
        if action_type == "reschedule_training":
            if target_date != "next_free" and not valid_date(target_date):
                raise ValueError("target_date must be YYYY-MM-DD or next_free")
            payload["target_date"] = target_date
        if action_type == "open_screen":
            screen = str(payload.get("screen", "")).strip()
            if screen not in APP_SCREENS:
                raise ValueError("unsupported screen")
            payload["screen"] = screen
        if action_type == "update_goal":
            goal_type = str(payload.get("goal_type", "")).strip()
            if goal_type and goal_type not in {
                "lose_fat",
                "build_muscle",
                "recomp",
                "endurance",
            }:
                raise ValueError("unsupported goal_type")
            if not any(
                key in payload
                for key in (
                    "goal_type",
                    "target_weight_kg",
                    "target_date",
                    "weekly_days",
                    "session_minutes",
                )
            ):
                raise ValueError("update_goal requires at least one field")

        title = str(raw.get("title") or action_type).strip()[:120]
        summary = str(raw.get("summary") or "").strip()[:500]
        result.append(
            {
                "id": str(uuid4()),
                "type": action_type,
                "title": title,
                "summary": summary,
                "requires_confirmation": True,
                "payload": _safe_json(payload),
            }
        )
    if not result:
        raise ValueError("no valid actions")
    return result


def _tool_result(
    db: Session,
    run: AgentRun,
    user_id: str,
    tool: str,
    arguments: dict,
    app_context: dict | None = None,
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
    if tool == "propose_app_actions":
        try:
            actions = _normalize_app_actions(arguments.get("actions"), app_context)
        except ValueError as exc:
            return {"ok": False, "error": str(exc)}
        return {"ok": True, "actions": actions}
    return {"ok": False, "error": f"unknown tool: {tool}"}


REVIEW_TZ = timezone(timedelta(hours=8))


def _week_start(now: datetime) -> datetime:
    local = now.astimezone(REVIEW_TZ)
    start = (local - timedelta(days=local.weekday())).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    return start.astimezone(timezone.utc)


def _review_snapshot(
    db: Session, user_id: str, start: datetime, end: datetime
) -> dict:
    sessions = (
        db.execute(
            select(WorkoutSession)
            .options(selectinload(WorkoutSession.sets))
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.started_at >= start,
                WorkoutSession.started_at < end,
            )
            .order_by(WorkoutSession.started_at.desc())
        )
        .scalars()
        .all()
    )
    completed_sets = 0
    volume = 0.0
    rpe_total = 0.0
    for session in sessions:
        for item in session.sets:
            if not item.completed:
                continue
            completed_sets += 1
            volume += (item.weight_kg or 0) * (item.reps or 0)
            rpe_total += item.rpe or 0
    durations = [item.duration_min for item in sessions if item.duration_min]
    return {
        "sessions": len(sessions),
        "completed_sets": completed_sets,
        "volume_kg": round(volume, 1),
        "average_rpe": round(rpe_total / completed_sets, 1)
        if completed_sets
        else None,
        "average_duration_min": round(sum(durations) / len(durations))
        if durations
        else 0,
        "last_session_at": sessions[0].started_at.isoformat()
        if sessions
        else None,
    }


def generate_weekly_review(db: Session, user_id: str) -> dict:
    """Create an auditable, rule-based weekly review without an LLM call.

    The review is intentionally deterministic: users can request it after every
    workout without spending model tokens, while the run and its tool outputs
    remain visible in the admin Agent audit page.
    """
    profile = db.get(Profile, user_id)
    if profile is None:
        raise ValueError("请先完成个人档案，再生成周复盘")

    now = utcnow()
    week_start = _week_start(now)
    previous_start = week_start - timedelta(days=7)
    current = _review_snapshot(db, user_id, week_start, week_start + timedelta(days=7))
    previous = _review_snapshot(db, user_id, previous_start, week_start)
    context = _context(db, user_id)
    nutrition = context.get("nutrition_7d") or {}
    target = max(1, int(profile.weekly_days or 3))
    completion = min(1.5, current["sessions"] / target)
    minutes = profile.session_minutes or 45

    wins: list[str] = []
    watchouts: list[str] = []
    actions: list[str] = []

    if current["sessions"] == 0:
        summary = (
            f"本周还没有训练记录。先按计划完成一次 {minutes} 分钟的训练，"
            "不要一上来追求强度，先把节奏找回来。"
        )
        watchouts.append("本周训练频率不足")
        actions.append(f"从今天或明天安排一次 {minutes} 分钟的全身训练")
    elif current["sessions"] >= target:
        summary = (
            f"本周完成 {current['sessions']}/{target} 次训练，达到计划目标，"
            f"总容量 {current['volume_kg']:.0f} kg。"
        )
        wins.append("训练频率达标")
        actions.append("下周保持频率，主力动作在动作稳定时加 2.5% 重量或 +1 次")
    else:
        summary = (
            f"本周完成 {current['sessions']}/{target} 次训练，完成率 "
            f"{completion:.0%}，还差 {max(0, target - current['sessions'])} 次。"
        )
        wins.append("已经完成部分训练")
        actions.append(f"剩余时间优先补 1 次 {minutes} 分钟训练，不必追求练到力竭")

    if current["average_rpe"] is not None:
        if current["average_rpe"] >= 8.5:
            watchouts.append("平均 RPE 偏高，恢复压力较大")
            actions.append("下一次同动作降 1 组或降 5% 重量，把 RPE 控制在 7–8")
        elif current["average_rpe"] <= 5.5:
            actions.append("下一次在动作稳定时加 2.5% 重量或 +1 次，逐步增加刺激")

    if previous["volume_kg"] > 0 and current["volume_kg"] > previous["volume_kg"] * 1.1:
        wins.append("训练容量较上周提升")
    elif previous["volume_kg"] > 0 and current["volume_kg"] < previous["volume_kg"] * 0.8:
        watchouts.append("训练容量较上周下降")

    logged_days = int(nutrition.get("logged_days") or 0)
    if logged_days < 3:
        actions.append(
            f"本周只有 {logged_days} 天有饮食记录，先做到每天至少记录一餐，便于判断热量"
        )
    if not wins:
        wins.append("建立了本周训练基线")
    if not actions:
        actions.append("下一次训练后记录 RPE 和训练感受，帮助教练继续调整")

    review = {
        "period": "week",
        "week_start": week_start.astimezone(REVIEW_TZ).date().isoformat(),
        "stats": {
            "sessions": current["sessions"],
            "planned": target,
            "completion_rate": round(completion, 2),
            "volume_kg": current["volume_kg"],
            "average_rpe": current["average_rpe"],
            "average_duration_min": current["average_duration_min"],
            "previous_volume_kg": previous["volume_kg"],
            "nutrition_logged_days": logged_days,
            "plan_title": (context.get("current_plan") or {}).get("title"),
        },
        "summary": summary,
        "wins": wins[:3],
        "watchouts": watchouts[:3],
        "actions": actions[:3],
        "generated_at": now.isoformat(),
    }

    run = AgentRun(
        user_id=user_id,
        intent="review_week",
        status="running",
        model="review-rules-v1",
        input_text="auto:weekly_review",
    )
    db.add(run)
    db.flush()
    _record_step(
        db,
        run,
        "tool",
        tool_name="get_context",
        input_data={"scope": "weekly_review"},
        output_data={
            "profile": context.get("profile"),
            "current_plan": context.get("current_plan"),
            "nutrition_7d": nutrition,
            "memories": context.get("memories"),
        },
    )
    _record_step(
        db,
        run,
        "tool",
        tool_name="get_recent_training",
        input_data={"days": 7},
        output_data={"current": current, "previous": previous},
    )
    _record_step(
        db,
        run,
        "decision",
        input_data={"policy": "weekly_review_rules_v1"},
        output_data=review,
    )
    run.status = "completed"
    run.output_text = summary[:4000]
    run.completed_at = utcnow()
    db.commit()
    review["run_id"] = run.id
    return review


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
    app_context: dict | None = None,
) -> dict:
    action_words = ("改到", "顺延", "跳过", "打开", "开始训练", "取消训练", "改目标")
    intent = (
        "app_action"
        if any(word in message for word in action_words)
        else "plan_change"
        if any(word in message for word in ("计划", "安排", "每周", "训练日", "频率"))
        else "coach_chat"
    )
    run = AgentRun(
        user_id=user_id,
        session_id=session_id,
        intent=intent,
        status="running",
        model=settings.llm_model,
        input_text=message[:4000],
    )
    db.add(run)
    db.flush()

    observations: list[dict] = []
    final_message: str | None = None
    proposal: AgentPlanProposal | None = None
    actions: list[dict] = []
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
            "actions": [],
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
                "app_context": _safe_json(app_context or {}),
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
                        result = _tool_result(
                            db, run, user_id, tool, arguments, app_context
                        )
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
                    if isinstance(result.get("actions"), list):
                        actions = result["actions"]
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
        if proposal is not None or any(
            item.get("requires_confirmation") for item in actions
        ):
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
        "actions": actions,
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
