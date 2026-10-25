from __future__ import annotations

import secrets
from datetime import datetime, timedelta, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import func, or_, select

from ..config import settings
from ..deps import DBSession
from ..models import (
    AdminAuditLog,
    AIJob,
    ChatMessage,
    ChatSession,
    EquipmentScan,
    Exercise,
    Goal,
    MealPlan,
    Profile,
    Program,
    User,
    WorkoutSession,
    utcnow,
)
from ..services.serializers import goal_to_dict, profile_to_dict, serialize_program

router = APIRouter(prefix="/admin", tags=["admin"])

GOAL_LABELS = {
    "lose_fat": "减脂",
    "build_muscle": "增肌",
    "recomp": "重塑",
    "endurance": "体能",
}


def require_admin(
    x_admin_token: Annotated[str | None, Header(alias="X-Admin-Token")] = None,
) -> str:
    expected = settings.admin_token or (
        "dev-admin-token" if settings.app_env == "dev" else ""
    )
    if not expected:
        raise HTTPException(status_code=503, detail="后台尚未配置 ADMIN_TOKEN")
    if not x_admin_token or not secrets.compare_digest(x_admin_token, expected):
        raise HTTPException(status_code=401, detail="管理员口令不正确")
    return "admin"


AdminAuth = Annotated[str, Depends(require_admin)]


class ExerciseAdminPatch(BaseModel):
    name_zh: str | None = Field(default=None, max_length=80)
    name_en: str | None = Field(default=None, max_length=120)
    muscle_group: str | None = Field(default=None, max_length=20)
    equipment: str | None = Field(default=None, max_length=20)
    is_compound: bool | None = None
    difficulty: int | None = Field(default=None, ge=1, le=5)
    instructions: str | None = None
    video_url: str | None = None
    thumbnail_url: str | None = None
    contraindications: list[str] | None = None


def _iso(value: datetime | None) -> str | None:
    return value.isoformat() if value else None


def _audit(
    db: DBSession,
    actor: str,
    action: str,
    target_type: str,
    target_id: str | None = None,
    detail: dict | None = None,
) -> None:
    db.add(
        AdminAuditLog(
            actor=actor,
            action=action,
            target_type=target_type,
            target_id=target_id,
            detail=detail or {},
        )
    )
    db.commit()


def _program_summary(program: Program) -> dict:
    return {
        "id": program.id,
        "user_id": program.user_id,
        "title": program.title,
        "goal_type": program.goal_type,
        "goal_label": GOAL_LABELS.get(program.goal_type, program.goal_type),
        "version": program.version,
        "status": program.status,
        "start_date": program.start_date.isoformat(),
        "weeks": program.weeks,
        "generated_by": program.generated_by,
        "model_name": program.model_name,
        "created_at": _iso(program.created_at),
        "day_count": len(program.days),
        "exercise_count": sum(len(day.exercises) for day in program.days),
    }


def _workout_summary(session: WorkoutSession) -> dict:
    volume = sum(
        (item.weight_kg or 0) * (item.reps or 0)
        for item in session.sets
        if item.completed
    )
    return {
        "id": session.id,
        "user_id": session.user_id,
        "started_at": _iso(session.started_at),
        "finished_at": _iso(session.finished_at),
        "duration_min": session.duration_min,
        "feeling": session.feeling,
        "notes": session.notes,
        "set_count": len(session.sets),
        "volume_kg": round(volume, 1),
        "created_at": _iso(session.created_at),
    }


def _workout_detail(session: WorkoutSession) -> dict:
    data = _workout_summary(session)
    data["sets"] = [
        {
            "id": item.id,
            "slug": item.exercise_slug,
            "set_index": item.set_index,
            "weight_kg": item.weight_kg,
            "reps": item.reps,
            "rpe": item.rpe,
            "completed": item.completed,
            "created_at": _iso(item.created_at),
        }
        for item in session.sets
    ]
    return data


def _chat_summary(session: ChatSession) -> dict:
    safety_count = sum(1 for message in session.messages if message.safety_flag)
    last = session.messages[-1] if session.messages else None
    return {
        "id": session.id,
        "user_id": session.user_id,
        "title": session.title,
        "message_count": len(session.messages),
        "safety_count": safety_count,
        "last_message": (last.content[:120] if last else None),
        "last_role": last.role if last else None,
        "created_at": _iso(session.created_at),
    }


def _chat_detail(session: ChatSession) -> dict:
    data = _chat_summary(session)
    data["messages"] = [
        {
            "id": message.id,
            "role": message.role,
            "content": message.content,
            "safety_flag": message.safety_flag,
            "citations": message.citations or [],
            "tokens": message.tokens,
            "created_at": _iso(message.created_at),
        }
        for message in session.messages
    ]
    return data


@router.get("/auth/check")
def auth_check(actor: AdminAuth):
    return {"ok": True, "actor": actor, "env": settings.app_env}


@router.get("/stats")
def stats(actor: AdminAuth, db: DBSession):
    now = datetime.now(timezone.utc)
    since_7d = now - timedelta(days=7)
    since_30d = now - timedelta(days=30)
    since_14d = now - timedelta(days=14)

    users_total = db.scalar(select(func.count(User.id)).where(User.deleted_at.is_(None))) or 0
    users_new_7d = (
        db.scalar(
            select(func.count(User.id)).where(
                User.deleted_at.is_(None), User.created_at >= since_7d
            )
        )
        or 0
    )
    onboarded = (
        db.scalar(
            select(func.count(Profile.user_id)).where(Profile.onboarded_at.is_not(None))
        )
        or 0
    )
    sessions_total = db.scalar(select(func.count(WorkoutSession.id))) or 0
    sessions_7d = (
        db.scalar(
            select(func.count(WorkoutSession.id)).where(
                WorkoutSession.started_at >= since_7d
            )
        )
        or 0
    )
    programs_active = (
        db.scalar(select(func.count(Program.id)).where(Program.status == "active")) or 0
    )
    programs_total = db.scalar(select(func.count(Program.id))) or 0
    chats_total = db.scalar(select(func.count(ChatSession.id))) or 0
    messages_total = db.scalar(select(func.count(ChatMessage.id))) or 0
    safety_total = (
        db.scalar(
            select(func.count(ChatMessage.id)).where(ChatMessage.safety_flag.is_not(None))
        )
        or 0
    )
    scans_total = db.scalar(select(func.count(EquipmentScan.id))) or 0
    exercises_total = db.scalar(select(func.count(Exercise.slug))) or 0
    meals_total = db.scalar(select(func.count(MealPlan.id))) or 0
    ai_errors = (
        db.scalar(select(func.count(AIJob.id)).where(AIJob.status != "ok")) or 0
    )

    workout_users_7d = set(
        db.execute(
            select(WorkoutSession.user_id).where(WorkoutSession.started_at >= since_7d)
        ).scalars()
    )
    chat_users_7d = set(
        db.execute(
            select(ChatSession.user_id).where(ChatSession.created_at >= since_7d)
        ).scalars()
    )
    active_7d = len(workout_users_7d | chat_users_7d)

    workout_users_30d = set(
        db.execute(
            select(WorkoutSession.user_id).where(WorkoutSession.started_at >= since_30d)
        ).scalars()
    )
    chat_users_30d = set(
        db.execute(
            select(ChatSession.user_id).where(ChatSession.created_at >= since_30d)
        ).scalars()
    )
    active_30d = len(workout_users_30d | chat_users_30d)

    goal_rows = db.execute(
        select(Goal.type, func.count(Goal.id))
        .where(Goal.status == "active")
        .group_by(Goal.type)
    ).all()
    goals = [
        {"type": key, "label": GOAL_LABELS.get(key, key), "count": count}
        for key, count in goal_rows
    ]

    equipment_counts: dict[str, int] = {}
    for profile in db.execute(select(Profile)).scalars():
        for item in profile.equipment or []:
            equipment_counts[item] = equipment_counts.get(item, 0) + 1

    user_days: dict[str, int] = {}
    for created_at in db.execute(
        select(User.created_at).where(
            User.deleted_at.is_(None), User.created_at >= since_14d
        )
    ).scalars():
        key = created_at.date().isoformat()
        user_days[key] = user_days.get(key, 0) + 1

    workout_days: dict[str, int] = {}
    for started_at in db.execute(
        select(WorkoutSession.started_at).where(WorkoutSession.started_at >= since_14d)
    ).scalars():
        key = started_at.date().isoformat()
        workout_days[key] = workout_days.get(key, 0) + 1

    daily = []
    for offset in range(13, -1, -1):
        day = (now.date() - timedelta(days=offset)).isoformat()
        daily.append(
            {
                "date": day,
                "users": user_days.get(day, 0),
                "workouts": workout_days.get(day, 0),
            }
        )

    recent_users = []
    for user in db.execute(
        select(User)
        .where(User.deleted_at.is_(None))
        .order_by(User.created_at.desc())
        .limit(5)
    ).scalars():
        profile = db.get(Profile, user.id)
        recent_users.append(
            {
                "id": user.id,
                "nickname": profile.nickname if profile else "未建档",
                "created_at": _iso(user.created_at),
            }
        )

    recent_workouts = []
    for session in db.execute(
        select(WorkoutSession)
        .order_by(WorkoutSession.started_at.desc())
        .limit(5)
    ).scalars():
        profile = db.get(Profile, session.user_id)
        item = _workout_summary(session)
        item["nickname"] = profile.nickname if profile else session.user_id[:8]
        recent_workouts.append(item)

    recent_safety = []
    for message in db.execute(
        select(ChatMessage)
        .where(ChatMessage.safety_flag.is_not(None))
        .order_by(ChatMessage.created_at.desc())
        .limit(5)
    ).scalars():
        session = db.get(ChatSession, message.session_id)
        profile = db.get(Profile, session.user_id) if session else None
        recent_safety.append(
            {
                "id": message.id,
                "user_id": session.user_id if session else None,
                "nickname": profile.nickname if profile else "未知用户",
                "safety_flag": message.safety_flag,
                "content": message.content[:160],
                "created_at": _iso(message.created_at),
            }
        )

    return {
        "users_total": users_total,
        "users_new_7d": users_new_7d,
        "onboarded": onboarded,
        "active_7d": active_7d,
        "active_30d": active_30d,
        "sessions_total": sessions_total,
        "sessions_7d": sessions_7d,
        "programs_active": programs_active,
        "programs_total": programs_total,
        "chats_total": chats_total,
        "messages_total": messages_total,
        "safety_total": safety_total,
        "scans_total": scans_total,
        "exercises_total": exercises_total,
        "meals_total": meals_total,
        "ai_errors": ai_errors,
        "goals": goals,
        "equipment": [
            {"type": key, "count": count}
            for key, count in sorted(equipment_counts.items(), key=lambda x: -x[1])
        ],
        "daily": daily,
        "recent_users": recent_users,
        "recent_workouts": recent_workouts,
        "recent_safety": recent_safety,
    }


@router.get("/users")
def list_users(
    actor: AdminAuth,
    db: DBSession,
    q: str = Query(default="", max_length=80),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    include_deleted: bool = Query(default=False),
):
    statement = select(User).outerjoin(Profile, Profile.user_id == User.id)
    if not include_deleted:
        statement = statement.where(User.deleted_at.is_(None))
    text = q.strip()
    if text:
        statement = statement.where(
            or_(
                User.id.contains(text),
                User.phone.contains(text),
                Profile.nickname.contains(text),
            )
        )

    total = db.scalar(select(func.count()).select_from(statement.subquery())) or 0
    users = (
        db.execute(
            statement.order_by(User.created_at.desc()).limit(limit).offset(offset)
        )
        .scalars()
        .unique()
        .all()
    )
    ids = [user.id for user in users]

    profiles = {
        profile.user_id: profile
        for profile in db.execute(
            select(Profile).where(Profile.user_id.in_(ids))
        ).scalars()
    } if ids else {}
    workout_counts = dict(
        db.execute(
            select(WorkoutSession.user_id, func.count(WorkoutSession.id))
            .where(WorkoutSession.user_id.in_(ids))
            .group_by(WorkoutSession.user_id)
        ).all()
    ) if ids else {}
    last_workouts = dict(
        db.execute(
            select(WorkoutSession.user_id, func.max(WorkoutSession.started_at))
            .where(WorkoutSession.user_id.in_(ids))
            .group_by(WorkoutSession.user_id)
        ).all()
    ) if ids else {}
    plan_counts = dict(
        db.execute(
            select(Program.user_id, func.count(Program.id))
            .where(Program.user_id.in_(ids))
            .group_by(Program.user_id)
        ).all()
    ) if ids else {}
    active_goals = {
        goal.user_id: goal
        for goal in db.execute(
            select(Goal).where(Goal.user_id.in_(ids), Goal.status == "active")
        ).scalars()
    } if ids else {}

    items = []
    for user in users:
        profile = profiles.get(user.id)
        goal = active_goals.get(user.id)
        items.append(
            {
                "id": user.id,
                "nickname": profile.nickname if profile else "未建档",
                "sex": profile.sex if profile else None,
                "age": profile.age if profile else None,
                "height_cm": profile.height_cm if profile else None,
                "weight_kg": profile.weight_kg if profile else None,
                "bmi": profile.bmi if profile else None,
                "goal_type": goal.type if goal else None,
                "goal_label": GOAL_LABELS.get(goal.type, goal.type) if goal else None,
                "onboarded": bool(profile and profile.onboarded_at),
                "workout_count": workout_counts.get(user.id, 0),
                "last_workout_at": _iso(last_workouts.get(user.id)),
                "plan_count": plan_counts.get(user.id, 0),
                "created_at": _iso(user.created_at),
                "deleted_at": _iso(user.deleted_at),
            }
        )

    return {"items": items, "total": total, "limit": limit, "offset": offset}


@router.get("/users/{user_id}")
def user_detail(user_id: str, actor: AdminAuth, db: DBSession):
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="用户不存在")
    profile = db.get(Profile, user_id)
    goals = db.execute(
        select(Goal).where(Goal.user_id == user_id).order_by(Goal.created_at.desc())
    ).scalars().all()
    programs = db.execute(
        select(Program)
        .where(Program.user_id == user_id)
        .order_by(Program.created_at.desc())
    ).scalars().all()
    workouts = db.execute(
        select(WorkoutSession)
        .where(WorkoutSession.user_id == user_id)
        .order_by(WorkoutSession.started_at.desc())
        .limit(50)
    ).scalars().all()
    chats = db.execute(
        select(ChatSession)
        .where(ChatSession.user_id == user_id)
        .order_by(ChatSession.created_at.desc())
        .limit(30)
    ).scalars().all()
    scans = db.execute(
        select(EquipmentScan)
        .where(EquipmentScan.user_id == user_id)
        .order_by(EquipmentScan.created_at.desc())
        .limit(30)
    ).scalars().all()
    meals = db.execute(
        select(MealPlan)
        .where(MealPlan.user_id == user_id)
        .order_by(MealPlan.plan_date.desc())
        .limit(30)
    ).scalars().all()
    jobs = db.execute(
        select(AIJob)
        .where(AIJob.user_id == user_id)
        .order_by(AIJob.created_at.desc())
        .limit(20)
    ).scalars().all()

    total_volume = sum(
        sum(
            (item.weight_kg or 0) * (item.reps or 0)
            for item in session.sets
            if item.completed
        )
        for session in workouts
    )

    return {
        "user": {
            "id": user.id,
            "created_at": _iso(user.created_at),
            "updated_at": _iso(user.updated_at),
            "deleted_at": _iso(user.deleted_at),
            "phone": user.phone,
            "username": user.username,
            "last_login_at": _iso(user.last_login_at),
            "status": user.status,
            "auth_methods": {
                "phone": bool(user.phone),
                "password": bool(user.password_hash),
                "wechat": bool(user.wechat_openid),
                "qq": bool(user.qq_openid),
            },
        },
        "profile": profile_to_dict(profile) if profile else None,
        "metrics": {
            "workouts": len(workouts),
            "volume_kg": round(total_volume, 1),
            "programs": len(programs),
            "chats": len(chats),
            "scans": len(scans),
        },
        "goals": [goal_to_dict(goal) for goal in goals],
        "programs": [_program_summary(program) for program in programs],
        "workouts": [_workout_summary(session) for session in workouts],
        "chats": [_chat_summary(chat) for chat in chats],
        "scans": [
            {
                "id": scan.id,
                "status": scan.status,
                "model": scan.model,
                "result": scan.result or [],
                "created_at": _iso(scan.created_at),
            }
            for scan in scans
        ],
        "meals": [
            {
                "id": meal.id,
                "plan_date": meal.plan_date.isoformat(),
                "target_kcal": meal.target_kcal,
                "created_at": _iso(meal.created_at),
            }
            for meal in meals
        ],
        "ai_jobs": [
            {
                "id": job.id,
                "kind": job.kind,
                "model": job.model,
                "status": job.status,
                "latency_ms": job.latency_ms,
                "error": job.error,
                "created_at": _iso(job.created_at),
            }
            for job in jobs
        ],
    }


@router.get("/users/{user_id}/export")
def export_user(user_id: str, actor: AdminAuth, db: DBSession):
    data = user_detail(user_id, actor, db)
    data["exported_at"] = datetime.now(timezone.utc).isoformat()
    data["source"] = "fitai-backend"
    _audit(db, actor, "user.export", "user", user_id, {"format": "json"})
    return data


@router.delete("/users/{user_id}")
def delete_user(
    user_id: str,
    actor: AdminAuth,
    db: DBSession,
    purge: bool = Query(default=False),
):
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="用户不存在")
    if purge:
        db.delete(user)
        db.commit()
        _audit(db, actor, "user.purge", "user", user_id, {"hard_delete": True})
        return {"ok": True, "purged": True}
    user.deleted_at = utcnow()
    db.commit()
    _audit(db, actor, "user.soft_delete", "user", user_id)
    return {"ok": True, "purged": False}


@router.post("/users/{user_id}/restore")
def restore_user(user_id: str, actor: AdminAuth, db: DBSession):
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="用户不存在")
    user.deleted_at = None
    db.commit()
    _audit(db, actor, "user.restore", "user", user_id)
    return {"ok": True}


@router.get("/programs")
def list_programs(
    actor: AdminAuth,
    db: DBSession,
    q: str = Query(default="", max_length=80),
    status: str = Query(default="", max_length=20),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
):
    statement = select(Program).join(User, User.id == Program.user_id)
    if q.strip():
        text = q.strip()
        statement = statement.outerjoin(Profile, Profile.user_id == Program.user_id).where(
            or_(
                Program.title.contains(text),
                Program.user_id.contains(text),
                Profile.nickname.contains(text),
            )
        )
    if status:
        statement = statement.where(Program.status == status)
    total = db.scalar(select(func.count()).select_from(statement.subquery())) or 0
    programs = (
        db.execute(
            statement.order_by(Program.created_at.desc()).limit(limit).offset(offset)
        )
        .scalars()
        .unique()
        .all()
    )
    items = []
    for program in programs:
        profile = db.get(Profile, program.user_id)
        item = _program_summary(program)
        item["nickname"] = profile.nickname if profile else "未建档"
        items.append(item)
    return {"items": items, "total": total, "limit": limit, "offset": offset}


@router.get("/programs/{program_id}")
def program_detail(program_id: str, actor: AdminAuth, db: DBSession):
    program = db.get(Program, program_id)
    if program is None:
        raise HTTPException(status_code=404, detail="计划不存在")
    profile = db.get(Profile, program.user_id)
    data = serialize_program(program)
    data["nickname"] = profile.nickname if profile else "未建档"
    return data


@router.post("/programs/{program_id}/archive")
def archive_program(program_id: str, actor: AdminAuth, db: DBSession):
    program = db.get(Program, program_id)
    if program is None:
        raise HTTPException(status_code=404, detail="计划不存在")
    program.status = "archived"
    db.commit()
    _audit(db, actor, "program.archive", "program", program_id)
    return {"ok": True, "status": program.status}


@router.post("/programs/{program_id}/activate")
def activate_program(program_id: str, actor: AdminAuth, db: DBSession):
    program = db.get(Program, program_id)
    if program is None:
        raise HTTPException(status_code=404, detail="计划不存在")
    active = db.execute(
        select(Program).where(
            Program.user_id == program.user_id, Program.status == "active"
        )
    ).scalars()
    for item in active:
        item.status = "archived"
    program.status = "active"
    db.commit()
    _audit(db, actor, "program.activate", "program", program_id)
    return {"ok": True, "status": program.status}


@router.get("/workouts")
def list_workouts(
    actor: AdminAuth,
    db: DBSession,
    q: str = Query(default="", max_length=80),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
):
    statement = select(WorkoutSession).join(User, User.id == WorkoutSession.user_id)
    if q.strip():
        text = q.strip()
        statement = statement.outerjoin(
            Profile, Profile.user_id == WorkoutSession.user_id
        ).where(
            or_(
                WorkoutSession.user_id.contains(text),
                Profile.nickname.contains(text),
            )
        )
    total = db.scalar(select(func.count()).select_from(statement.subquery())) or 0
    sessions = (
        db.execute(
            statement.order_by(WorkoutSession.started_at.desc())
            .limit(limit)
            .offset(offset)
        )
        .scalars()
        .unique()
        .all()
    )
    items = []
    for session in sessions:
        profile = db.get(Profile, session.user_id)
        item = _workout_summary(session)
        item["nickname"] = profile.nickname if profile else "未建档"
        items.append(item)
    return {"items": items, "total": total, "limit": limit, "offset": offset}


@router.get("/workouts/{workout_id}")
def workout_detail(workout_id: str, actor: AdminAuth, db: DBSession):
    session = db.get(WorkoutSession, workout_id)
    if session is None:
        raise HTTPException(status_code=404, detail="训练记录不存在")
    profile = db.get(Profile, session.user_id)
    data = _workout_detail(session)
    data["nickname"] = profile.nickname if profile else "未建档"
    return data


@router.delete("/workouts/{workout_id}")
def delete_workout(workout_id: str, actor: AdminAuth, db: DBSession):
    session = db.get(WorkoutSession, workout_id)
    if session is None:
        raise HTTPException(status_code=404, detail="训练记录不存在")
    user_id = session.user_id
    db.delete(session)
    db.commit()
    _audit(db, actor, "workout.delete", "workout", workout_id, {"user_id": user_id})
    return {"ok": True}


@router.get("/chats")
def list_chats(
    actor: AdminAuth,
    db: DBSession,
    q: str = Query(default="", max_length=80),
    safety_only: bool = Query(default=False),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
):
    statement = select(ChatSession).join(User, User.id == ChatSession.user_id)
    if q.strip():
        text = q.strip()
        statement = statement.outerjoin(
            Profile, Profile.user_id == ChatSession.user_id
        ).where(
            or_(
                ChatSession.title.contains(text),
                ChatSession.user_id.contains(text),
                Profile.nickname.contains(text),
            )
        )
    if safety_only:
        statement = statement.join(
            ChatMessage, ChatMessage.session_id == ChatSession.id
        ).where(ChatMessage.safety_flag.is_not(None)).distinct()
    total = db.scalar(select(func.count()).select_from(statement.subquery())) or 0
    chats = (
        db.execute(
            statement.order_by(ChatSession.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        .scalars()
        .unique()
        .all()
    )
    items = []
    for chat in chats:
        profile = db.get(Profile, chat.user_id)
        item = _chat_summary(chat)
        item["nickname"] = profile.nickname if profile else "未建档"
        items.append(item)
    return {"items": items, "total": total, "limit": limit, "offset": offset}


@router.get("/chats/{chat_id}")
def chat_detail(chat_id: str, actor: AdminAuth, db: DBSession):
    chat = db.get(ChatSession, chat_id)
    if chat is None:
        raise HTTPException(status_code=404, detail="对话不存在")
    profile = db.get(Profile, chat.user_id)
    data = _chat_detail(chat)
    data["nickname"] = profile.nickname if profile else "未建档"
    return data


@router.delete("/chats/{chat_id}")
def delete_chat(chat_id: str, actor: AdminAuth, db: DBSession):
    chat = db.get(ChatSession, chat_id)
    if chat is None:
        raise HTTPException(status_code=404, detail="对话不存在")
    user_id = chat.user_id
    db.delete(chat)
    db.commit()
    _audit(db, actor, "chat.delete", "chat", chat_id, {"user_id": user_id})
    return {"ok": True}


@router.get("/scans")
def list_scans(
    actor: AdminAuth,
    db: DBSession,
    q: str = Query(default="", max_length=80),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
):
    statement = select(EquipmentScan).join(User, User.id == EquipmentScan.user_id)
    if q.strip():
        text = q.strip()
        statement = statement.outerjoin(
            Profile, Profile.user_id == EquipmentScan.user_id
        ).where(
            or_(
                EquipmentScan.user_id.contains(text),
                Profile.nickname.contains(text),
            )
        )
    total = db.scalar(select(func.count()).select_from(statement.subquery())) or 0
    scans = (
        db.execute(
            statement.order_by(EquipmentScan.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        .scalars()
        .unique()
        .all()
    )
    items = []
    for scan in scans:
        profile = db.get(Profile, scan.user_id)
        items.append(
            {
                "id": scan.id,
                "user_id": scan.user_id,
                "nickname": profile.nickname if profile else "未建档",
                "status": scan.status,
                "model": scan.model,
                "result_count": len(scan.result or []),
                "top_result": (scan.result or [{}])[0].get("name_zh") if scan.result else None,
                "created_at": _iso(scan.created_at),
            }
        )
    return {"items": items, "total": total, "limit": limit, "offset": offset}


@router.get("/scans/{scan_id}")
def scan_detail(scan_id: str, actor: AdminAuth, db: DBSession):
    scan = db.get(EquipmentScan, scan_id)
    if scan is None:
        raise HTTPException(status_code=404, detail="识别记录不存在")
    profile = db.get(Profile, scan.user_id)
    return {
        "id": scan.id,
        "user_id": scan.user_id,
        "nickname": profile.nickname if profile else "未建档",
        "status": scan.status,
        "model": scan.model,
        "result": scan.result or [],
        "created_at": _iso(scan.created_at),
    }


@router.delete("/scans/{scan_id}")
def delete_scan(scan_id: str, actor: AdminAuth, db: DBSession):
    scan = db.get(EquipmentScan, scan_id)
    if scan is None:
        raise HTTPException(status_code=404, detail="识别记录不存在")
    user_id = scan.user_id
    db.delete(scan)
    db.commit()
    _audit(db, actor, "scan.delete", "scan", scan_id, {"user_id": user_id})
    return {"ok": True}


@router.get("/exercises")
def list_exercises(
    actor: AdminAuth,
    db: DBSession,
    q: str = Query(default="", max_length=80),
    limit: int = Query(default=100, ge=1, le=300),
    offset: int = Query(default=0, ge=0),
):
    statement = select(Exercise)
    if q.strip():
        text = q.strip()
        statement = statement.where(
            or_(
                Exercise.slug.contains(text),
                Exercise.name_zh.contains(text),
                Exercise.name_en.contains(text),
                Exercise.muscle_group.contains(text),
                Exercise.equipment.contains(text),
            )
        )
    total = db.scalar(select(func.count()).select_from(statement.subquery())) or 0
    items = db.execute(
        statement.order_by(Exercise.muscle_group, Exercise.name_zh)
        .limit(limit)
        .offset(offset)
    ).scalars().all()
    return {
        "items": [
            {
                "slug": item.slug,
                "name_zh": item.name_zh,
                "name_en": item.name_en,
                "muscle_group": item.muscle_group,
                "equipment": item.equipment,
                "is_compound": item.is_compound,
                "difficulty": item.difficulty,
                "instructions": item.instructions,
                "video_url": item.video_url,
                "thumbnail_url": item.thumbnail_url,
                "contraindications": item.contraindications or [],
            }
            for item in items
        ],
        "total": total,
        "limit": limit,
        "offset": offset,
    }


@router.patch("/exercises/{slug}")
def update_exercise(
    slug: str,
    payload: ExerciseAdminPatch,
    actor: AdminAuth,
    db: DBSession,
):
    exercise = db.get(Exercise, slug)
    if exercise is None:
        raise HTTPException(status_code=404, detail="动作不存在")
    changes = payload.model_dump(exclude_unset=True)
    for field, value in changes.items():
        setattr(exercise, field, value)
    db.commit()
    _audit(
        db,
        actor,
        "exercise.update",
        "exercise",
        slug,
        {"fields": sorted(changes.keys())},
    )
    return {"ok": True, "slug": slug, "updated": sorted(changes.keys())}


@router.get("/audit")
def audit_log(
    actor: AdminAuth,
    db: DBSession,
    limit: int = Query(default=100, ge=1, le=300),
    offset: int = Query(default=0, ge=0),
):
    total = db.scalar(select(func.count(AdminAuditLog.id))) or 0
    rows = db.execute(
        select(AdminAuditLog)
        .order_by(AdminAuditLog.created_at.desc())
        .limit(limit)
        .offset(offset)
    ).scalars().all()
    return {
        "items": [
            {
                "id": item.id,
                "actor": item.actor,
                "action": item.action,
                "target_type": item.target_type,
                "target_id": item.target_id,
                "detail": item.detail or {},
                "created_at": _iso(item.created_at),
            }
            for item in rows
        ],
        "total": total,
        "limit": limit,
        "offset": offset,
    }
