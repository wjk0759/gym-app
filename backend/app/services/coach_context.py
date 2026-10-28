"""Deterministic context for the AI coach.

The model should not reconstruct the user's training state from raw rows on
every turn. This module builds one versioned, JSON-ready snapshot that can be
used by the agent, the legacy coach endpoint, and future context transparency
UI. All values here are computed from database state, not from the model.
"""

from __future__ import annotations

from datetime import datetime, timedelta

from sqlalchemy import and_, func, select
from sqlalchemy.orm import Session

from ..models import (
    BodyMetric,
    EquipmentLibraryItem,
    FoodLog,
    PlanDayState,
    Profile,
    Program,
    SetLog,
    WorkoutSession,
    utcnow,
)
from .memory import list_memories
from .queries import active_goal, active_program
from .serializers import goal_to_dict, profile_to_dict

CONTEXT_VERSION = "coach-context-v1"
MAX_RECENT_SESSIONS = 10
MAX_DAY_STATES = 30


def _now(value: datetime | None = None) -> datetime:
    return value or utcnow()


def _weekday_label(value: int) -> str:
    return ["一", "二", "三", "四", "五", "六", "日"][
        max(0, min(6, int(value) - 1))
    ]


def _current_week_index(program: Program, today: date) -> int:
    if not program.start_date:
        return 1
    week = (today - program.start_date).days // 7 + 1
    return max(1, min(int(program.weeks or 1), week))


def _memory_items(db: Session, user_id: str, limit: int = 20) -> list[dict]:
    memories = list_memories(db, user_id, limit)
    if memories:
        used_at = utcnow()
        for item in memories:
            item.last_used_at = used_at
        db.flush()
    return [
        {
            "kind": item.kind,
            "key": item.memory_key,
            "content": item.content,
            "confidence": item.confidence,
        }
        for item in memories
    ]


def body_context(db: Session, user_id: str) -> list[dict]:
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


def nutrition_context(db: Session, user_id: str, days: int = 7) -> dict:
    days = max(1, min(30, int(days)))
    since = utcnow() - timedelta(days=days)
    row = db.execute(
        select(
            func.count(func.distinct(func.date(FoodLog.logged_at))),
            func.coalesce(func.sum(FoodLog.kcal), 0.0),
            func.coalesce(func.sum(FoodLog.protein), 0.0),
            func.coalesce(func.sum(FoodLog.carbs), 0.0),
            func.coalesce(func.sum(FoodLog.fat), 0.0),
            func.coalesce(func.sum(FoodLog.fiber), 0.0),
        ).where(
            FoodLog.user_id == user_id,
            FoodLog.logged_at >= since,
        )
    ).one()
    return {
        "days": days,
        "logged_days": int(row[0] or 0),
        "kcal": round(float(row[1] or 0), 1),
        "protein_g": round(float(row[2] or 0), 1),
        "carbs_g": round(float(row[3] or 0), 1),
        "fat_g": round(float(row[4] or 0), 1),
        "fiber_g": round(float(row[5] or 0), 1),
    }


def equipment_context(db: Session, user_id: str) -> list[dict]:
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


def recent_training(db: Session, user_id: str, days: int = 30) -> dict:
    days = max(1, min(90, int(days)))
    since = utcnow() - timedelta(days=days)
    where = (
        WorkoutSession.user_id == user_id,
        WorkoutSession.started_at >= since,
    )
    aggregate = db.execute(
        select(
            func.count(func.distinct(WorkoutSession.id)),
            func.count(SetLog.id),
            func.coalesce(func.sum(SetLog.weight_kg * SetLog.reps), 0.0),
            func.coalesce(func.sum(SetLog.rpe), 0.0),
        )
        .select_from(WorkoutSession)
        .outerjoin(
            SetLog,
            and_(
                SetLog.session_id == WorkoutSession.id,
                SetLog.completed.is_(True),
            ),
        )
        .where(*where)
    ).one()

    sessions = (
        db.execute(
            select(WorkoutSession)
            .where(*where)
            .order_by(WorkoutSession.started_at.desc())
            .limit(MAX_RECENT_SESSIONS)
        )
        .scalars()
        .all()
    )
    ids = [item.id for item in sessions]
    set_counts = (
        dict(
            db.execute(
                select(SetLog.session_id, func.count(SetLog.id))
                .where(SetLog.session_id.in_(ids))
                .group_by(SetLog.session_id)
            ).all()
        )
        if ids
        else {}
    )
    completed_sets = int(aggregate[1] or 0)
    total_rpe = float(aggregate[3] or 0)
    return {
        "days": days,
        "session_count": int(aggregate[0] or 0),
        "completed_sets": completed_sets,
        "total_volume_kg": round(float(aggregate[2] or 0), 1),
        "average_rpe": (
            round(total_rpe / completed_sets, 2) if completed_sets else None
        ),
        "recent_sessions": [
            {
                "id": item.id,
                "date": item.started_at.date().isoformat(),
                "program_day_id": item.program_day_id,
                "duration_min": item.duration_min,
                "feeling": item.feeling,
                "set_count": int(set_counts.get(item.id, 0)),
            }
            for item in sessions
        ],
    }


def _plan_exercise_context(item) -> dict:
    exercise = item.exercise
    return {
        "id": item.id,
        "slug": item.exercise_slug,
        "name_zh": exercise.name_zh if exercise else item.exercise_slug,
        "muscle_group": exercise.muscle_group if exercise else None,
        "equipment": exercise.equipment if exercise else None,
        "sets": item.sets,
        "reps": item.reps,
        "weight_kg": item.weight_kg,
        "rest_sec": item.rest_sec,
        "rpe": item.rpe,
        "notes": item.notes,
    }


def current_plan_context(
    db: Session,
    program: Program | None,
    user_id: str,
    now: datetime,
) -> dict | None:
    if program is None:
        return None

    first_week = [day for day in program.days if day.week_index == 1]
    week_index = _current_week_index(program, now.date())
    week_days = [day for day in program.days if day.week_index == week_index]

    states = (
        db.execute(
            select(PlanDayState)
            .where(
                PlanDayState.user_id == user_id,
                PlanDayState.plan_id == program.id,
            )
            .order_by(PlanDayState.assigned_date.asc())
            .limit(MAX_DAY_STATES)
        )
        .scalars()
        .all()
    )

    return {
        "id": program.id,
        "title": program.title,
        "goal_type": program.goal_type,
        "version": program.version,
        "weeks": program.weeks,
        "start_date": program.start_date.isoformat() if program.start_date else None,
        "current_week": week_index,
        "weekly_days": len(first_week),
        "weekdays": sorted(day.weekday for day in first_week),
        "day_titles": [day.title for day in first_week],
        "days": [
            {
                "id": day.id,
                "week_index": day.week_index,
                "weekday": day.weekday,
                "weekday_label": _weekday_label(day.weekday),
                "title": day.title,
                "focus": day.focus or [],
                "exercises": [
                    _plan_exercise_context(item) for item in day.exercises
                ],
            }
            for day in week_days
        ],
        "day_states": [
            {
                "day_id": item.day_id,
                "plan_version": item.plan_version,
                "assigned_date": (
                    item.assigned_date.isoformat() if item.assigned_date else None
                ),
                "skipped": item.skipped_at is not None,
            }
            for item in states
        ],
    }


def build_coach_context(
    db: Session,
    user_id: str,
    *,
    app_context: dict | None = None,
    recent_days: int = 30,
    now: datetime | None = None,
) -> dict:
    """Build the canonical, versioned context for one coach turn."""
    moment = _now(now)
    safe_app_context = app_context if isinstance(app_context, dict) else {}
    memories = _memory_items(db, user_id)
    profile = db.get(Profile, user_id)

    if profile is None:
        return {
            "version": CONTEXT_VERSION,
            "generated_at": moment.isoformat(),
            "needs_profile": True,
            "memories": memories,
            "app_context": safe_app_context,
        }

    program = active_program(db, user_id)
    return {
        "version": CONTEXT_VERSION,
        "generated_at": moment.isoformat(),
        "needs_profile": False,
        "today": {
            "date": moment.date().isoformat(),
            "weekday": moment.isoweekday(),
            "weekday_label": _weekday_label(moment.isoweekday()),
        },
        "profile": profile_to_dict(profile),
        "goal": goal_to_dict(active_goal(db, user_id)),
        "current_plan": current_plan_context(db, program, user_id, moment),
        "recent_training": recent_training(db, user_id, recent_days),
        "body_metrics": body_context(db, user_id),
        "nutrition_7d": nutrition_context(db, user_id, 7),
        "equipment_library": equipment_context(db, user_id),
        "memories": memories,
        "app_context": safe_app_context,
    }


def context_as_text(context: dict) -> str:
    """Compact text rendering for prompts that do not use the agent JSON state."""
    if context.get("needs_profile"):
        return "用户还没有完成个人档案；先询问目标、训练频率和器械。"

    profile = context.get("profile") or {}
    plan = context.get("current_plan") or {}
    training = context.get("recent_training") or {}
    nutrition = context.get("nutrition_7d") or {}
    lines = [
        f"用户：{profile.get('nickname') or '用户'}，"
        f"{profile.get('sex') or '?'}，{profile.get('age') or '?'} 岁，"
        f"{profile.get('height_cm') or '?'}cm，{profile.get('weight_kg') or '?'}kg。",
        f"目标：{(context.get('goal') or {}).get('type') or '未设置'}；"
        f"训练频率：每周 {profile.get('weekly_days') or '?'} 次；"
        f"单次 {profile.get('session_minutes') or '?'} 分钟。",
        f"最近 {training.get('days', 30)} 天：{training.get('session_count', 0)} 次，"
        f"{training.get('completed_sets', 0)} 组，"
        f"总容量 {training.get('total_volume_kg', 0)}kg。",
        f"饮食近 7 天：记录 {nutrition.get('logged_days', 0)} 天，"
        f"{nutrition.get('kcal', 0)}kcal，蛋白质 {nutrition.get('protein_g', 0)}g。",
    ]
    if plan:
        lines.append(
            f"当前计划：{plan.get('title')}，第 {plan.get('current_week')} 周，"
            f"每周 {plan.get('weekly_days')} 天。"
        )
        for day in plan.get("days") or []:
            names = "、".join(
                item.get("name_zh") or item.get("slug", "")
                for item in day.get("exercises") or []
            )
            lines.append(f"周{day.get('weekday_label')} {day.get('title')}：{names}")
    memories = context.get("memories") or []
    if memories:
        lines.append("长期记忆：" + "；".join(item["content"] for item in memories[:8]))
    return "\n".join(lines)
