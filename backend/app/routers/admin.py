from __future__ import annotations

import secrets
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Annotated, Literal
from uuid import uuid4

import jwt
from fastapi import APIRouter, Depends, File, Form, Header, HTTPException, Query, Request, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy import and_, case, func, or_, select
from sqlalchemy.orm import selectinload

from ..config import settings
from ..deps import DBSession
from ..media import POSTER_DIR, VIDEO_DIR, media_url, remove_media_url
from ..models import (
    AdminAuditLog,
    AIJob,
    ChatMessage,
    ChatSession,
    EquipmentScan,
    Exercise,
    ExerciseVideo,
    Goal,
    MealPlan,
    Profile,
    Program,
    SetLog,
    User,
    WorkoutSession,
    utcnow,
)
from ..services.locking import lock_user
from ..services.serializers import (
    goal_to_dict,
    load_program,
    profile_to_dict,
    program_load_options,
    serialize_program,
)

router = APIRouter(prefix="/admin", tags=["admin"])

GOAL_LABELS = {
    "lose_fat": "减脂",
    "build_muscle": "增肌",
    "recomp": "重塑",
    "endurance": "体能",
}


def _admin_permission(method: str, path: str) -> str | None:
    prefix = "/api/v1/admin"
    relative = path[len(prefix):] if path.startswith(prefix) else path
    if relative.startswith("/auth/"):
        return None
    if relative.startswith("/stats"):
        return "dashboard:read"
    if relative.startswith("/ai"):
        return "ai:read"
    if relative.startswith("/audit"):
        return "audit:read"
    groups = {
        "/users": "user",
        "/programs": "plan",
        "/workouts": "workout",
        "/chats": "chat",
        "/scans": "scan",
        "/exercises": "exercise",
        "/videos": "video",
        "/settings": "settings",
    }
    for path_prefix, resource in groups.items():
        if relative.startswith(path_prefix):
            if resource == "settings":
                return "settings:manage"
            return f"{resource}:{'read' if method.upper() == 'GET' else 'write'}"
    return None


def _dev_admin_token_valid(token: str | None) -> bool:
    expected = settings.admin_token or (
        "dev-admin-token" if settings.app_env == "dev" else ""
    )
    if not expected or not token:
        return False
    return secrets.compare_digest(token, expected)


def require_admin(
    request: Request,
    x_admin_token: Annotated[str | None, Header(alias="X-Admin-Token")] = None,
    authorization: Annotated[str | None, Header()] = None,
) -> str:
    permission = _admin_permission(request.method, request.url.path)
    if settings.admin_jwt_secret and authorization:
        if not authorization.lower().startswith("bearer "):
            raise HTTPException(status_code=401, detail="管理员凭证格式不正确")
        token = authorization.split(" ", 1)[1].strip()
        try:
            claims = jwt.decode(
                token,
                settings.admin_jwt_secret,
                algorithms=["HS256"],
                issuer=settings.admin_jwt_issuer,
            )
        except jwt.PyJWTError as exc:
            raise HTTPException(status_code=401, detail="管理员登录已失效") from exc
        if claims.get("typ") != "access":
            raise HTTPException(status_code=401, detail="管理员凭证类型不正确")
        permissions = set(claims.get("perms") or [])
        if permission and "*" not in permissions and permission not in permissions:
            raise HTTPException(status_code=403, detail="没有该后台操作权限")
        return (
            str(claims.get("username") or claims.get("name") or claims.get("sub") or "admin")
        )

    # Development/smoke compatibility. In production with RBAC configured, a
    # shared static token is not accepted.
    if (not settings.admin_jwt_secret or settings.app_env == "dev") and _dev_admin_token_valid(x_admin_token):
        return "dev-admin"

    if settings.admin_jwt_secret:
        raise HTTPException(status_code=401, detail="请先登录管理后台")
    expected = settings.admin_token or (
        "dev-admin-token" if settings.app_env == "dev" else ""
    )
    if not expected:
        raise HTTPException(status_code=503, detail="后台尚未配置 ADMIN_TOKEN 或 ADMIN_JWT_SECRET")
    raise HTTPException(status_code=401, detail="管理员凭证不正确")


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


class ExerciseVideoCreate(BaseModel):
    exercise_slug: str = Field(min_length=1, max_length=60)
    title: str = Field(min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=2000)
    video_url: str = Field(min_length=1, max_length=2000)
    poster_url: str | None = Field(default=None, max_length=2000)
    duration_seconds: int | None = Field(default=None, ge=0, le=14400)
    source: str | None = Field(default=None, max_length=80)
    license_note: str | None = Field(default=None, max_length=200)
    license_expires_at: date | None = None
    status: Literal["draft", "published"] = "draft"


class ExerciseVideoUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=2000)
    video_url: str | None = Field(default=None, min_length=1, max_length=2000)
    poster_url: str | None = Field(default=None, max_length=2000)
    duration_seconds: int | None = Field(default=None, ge=0, le=14400)
    source: str | None = Field(default=None, max_length=80)
    license_note: str | None = Field(default=None, max_length=200)
    license_expires_at: date | None = None
    status: Literal["draft", "published", "archived"] | None = None


def _iso(value: datetime | None) -> str | None:
    return value.isoformat() if value else None


def _profiles_by_user(db: DBSession, user_ids: list[str]) -> dict[str, Profile]:
    if not user_ids:
        return {}
    rows = db.execute(
        select(Profile).where(Profile.user_id.in_(set(user_ids)))
    ).scalars()
    return {profile.user_id: profile for profile in rows}


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
        "client_id": session.client_id,
        "user_id": session.user_id,
        "program_day_id": session.program_day_id,
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


VIDEO_SUFFIXES = {".mp4", ".mov", ".m4v", ".webm"}
POSTER_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}
VIDEO_CONTENT_TYPES = {
    "video/mp4": ".mp4",
    "video/quicktime": ".mov",
    "video/webm": ".webm",
}
POSTER_CONTENT_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}
MAX_VIDEO_BYTES = 300 * 1024 * 1024
MAX_POSTER_BYTES = 10 * 1024 * 1024


async def _store_video_upload(file: UploadFile, kind: str) -> tuple[str, int]:
    if kind not in {"video", "poster"}:
        raise HTTPException(status_code=400, detail="上传类型不正确")

    suffix = Path(file.filename or "").suffix.lower()
    content_type = (file.content_type or "").lower()
    if kind == "video":
        allowed_suffixes = VIDEO_SUFFIXES
        allowed_types = VIDEO_CONTENT_TYPES
        max_bytes = MAX_VIDEO_BYTES
        target_dir = VIDEO_DIR
        limit_message = "视频不能超过 300MB"
    else:
        allowed_suffixes = POSTER_SUFFIXES
        allowed_types = POSTER_CONTENT_TYPES
        max_bytes = MAX_POSTER_BYTES
        target_dir = POSTER_DIR
        limit_message = "封面不能超过 10MB"

    if suffix not in allowed_suffixes:
        suffix = allowed_types.get(content_type, "")
    if suffix not in allowed_suffixes:
        raise HTTPException(status_code=415, detail="文件格式不支持")

    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / f"{uuid4().hex}{suffix}"
    size = 0
    try:
        with target.open("wb") as handle:
            while chunk := await file.read(1024 * 1024):
                size += len(chunk)
                if size > max_bytes:
                    raise HTTPException(status_code=413, detail=limit_message)
                handle.write(chunk)
        if size == 0:
            raise HTTPException(status_code=400, detail="文件为空")
    except Exception:
        target.unlink(missing_ok=True)
        raise

    return media_url(target), size


def _video_dict(video: ExerciseVideo, exercise: Exercise | None) -> dict:
    return {
        "id": video.id,
        "exercise_slug": video.exercise_slug,
        "exercise_name": exercise.name_zh if exercise else None,
        "title": video.title,
        "description": video.description,
        "video_url": video.video_url,
        "poster_url": video.poster_url,
        "duration_seconds": video.duration_seconds,
        "source": video.source,
        "license_note": video.license_note,
        "license_expires_at": (
            video.license_expires_at.isoformat() if video.license_expires_at else None
        ),
        "status": video.status,
        "version": video.version,
        "created_by": video.created_by,
        "created_at": _iso(video.created_at),
        "updated_at": _iso(video.updated_at),
    }


def _sync_exercise_video(db: DBSession, exercise_slug: str) -> None:
    exercise = db.get(Exercise, exercise_slug)
    if exercise is None:
        return
    video = (
        db.execute(
            select(ExerciseVideo)
            .where(
                ExerciseVideo.exercise_slug == exercise_slug,
                ExerciseVideo.status == "published",
            )
            .order_by(ExerciseVideo.updated_at.desc())
        )
        .scalars()
        .first()
    )
    exercise.video_url = video.video_url if video else None
    exercise.thumbnail_url = video.poster_url if video else None
    exercise.source = video.source if video else None
    exercise.license = video.license_note if video else None


def _publish_video(db: DBSession, video: ExerciseVideo) -> None:
    others = db.execute(
        select(ExerciseVideo).where(
            ExerciseVideo.exercise_slug == video.exercise_slug,
            ExerciseVideo.id != video.id,
            ExerciseVideo.status == "published",
        )
    ).scalars()
    for other in others:
        other.status = "archived"
        other.updated_at = utcnow()
    video.status = "published"
    video.updated_at = utcnow()
    db.flush()
    _sync_exercise_video(db, video.exercise_slug)


@router.get("/auth/check")
def auth_check(actor: AdminAuth):
    return {"ok": True, "actor": actor, "env": settings.app_env}


@router.get("/stats")
def stats(actor: AdminAuth, db: DBSession):
    now = datetime.now(timezone.utc)
    since_7d = now - timedelta(days=7)
    since_30d = now - timedelta(days=30)
    since_14d = now - timedelta(days=14)

    def count_of(model, *conditions):
        return select(func.count()).select_from(model).where(*conditions).scalar_subquery()

    totals = db.execute(
        select(
            count_of(User, User.deleted_at.is_(None)).label("users_total"),
            count_of(
                User,
                User.deleted_at.is_(None),
                User.created_at >= since_7d,
            ).label("users_new_7d"),
            count_of(Profile, Profile.onboarded_at.is_not(None)).label("onboarded"),
            count_of(WorkoutSession).label("sessions_total"),
            count_of(
                WorkoutSession, WorkoutSession.started_at >= since_7d
            ).label("sessions_7d"),
            count_of(Program, Program.status == "active").label("programs_active"),
            count_of(Program).label("programs_total"),
            count_of(ChatSession).label("chats_total"),
            count_of(ChatMessage).label("messages_total"),
            count_of(
                ChatMessage, ChatMessage.safety_flag.is_not(None)
            ).label("safety_total"),
            count_of(EquipmentScan).label("scans_total"),
            count_of(Exercise).label("exercises_total"),
            count_of(MealPlan).label("meals_total"),
            count_of(AIJob, AIJob.status != "ok").label("ai_errors"),
        )
    ).one()
    users_total = int(totals.users_total or 0)
    users_new_7d = int(totals.users_new_7d or 0)
    onboarded = int(totals.onboarded or 0)
    sessions_total = int(totals.sessions_total or 0)
    sessions_7d = int(totals.sessions_7d or 0)
    programs_active = int(totals.programs_active or 0)
    programs_total = int(totals.programs_total or 0)
    chats_total = int(totals.chats_total or 0)
    messages_total = int(totals.messages_total or 0)
    safety_total = int(totals.safety_total or 0)
    scans_total = int(totals.scans_total or 0)
    exercises_total = int(totals.exercises_total or 0)
    meals_total = int(totals.meals_total or 0)
    ai_errors = int(totals.ai_errors or 0)

    active_7d = (
        db.scalar(
            select(func.count()).select_from(
                select(WorkoutSession.user_id)
                .where(WorkoutSession.started_at >= since_7d)
                .union(
                    select(ChatSession.user_id).where(
                        ChatSession.created_at >= since_7d
                    )
                )
                .subquery()
            )
        )
        or 0
    )

    active_30d = (
        db.scalar(
            select(func.count()).select_from(
                select(WorkoutSession.user_id)
                .where(WorkoutSession.started_at >= since_30d)
                .union(
                    select(ChatSession.user_id).where(
                        ChatSession.created_at >= since_30d
                    )
                )
                .subquery()
            )
        )
        or 0
    )

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
    for equipment in db.execute(select(Profile.equipment)).scalars():
        for item in equipment or []:
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

    recent_user_rows = db.execute(
        select(User)
        .where(User.deleted_at.is_(None))
        .order_by(User.created_at.desc())
        .limit(5)
    ).scalars().all()
    recent_profiles = _profiles_by_user(db, [user.id for user in recent_user_rows])
    recent_users = [
        {
            "id": user.id,
            "nickname": (
                recent_profiles[user.id].nickname
                if user.id in recent_profiles
                else "未建档"
            ),
            "created_at": _iso(user.created_at),
        }
        for user in recent_user_rows
    ]

    recent_workout_rows = db.execute(
        select(WorkoutSession)
        .options(selectinload(WorkoutSession.sets))
        .order_by(WorkoutSession.started_at.desc())
        .limit(5)
    ).scalars().all()
    recent_workout_profiles = _profiles_by_user(
        db, [session.user_id for session in recent_workout_rows]
    )
    recent_workouts = []
    for session in recent_workout_rows:
        profile = recent_workout_profiles.get(session.user_id)
        item = _workout_summary(session)
        item["nickname"] = profile.nickname if profile else session.user_id[:8]
        recent_workouts.append(item)

    safety_rows = db.execute(
        select(ChatMessage, ChatSession, Profile)
        .join(ChatSession, ChatSession.id == ChatMessage.session_id)
        .outerjoin(Profile, Profile.user_id == ChatSession.user_id)
        .where(ChatMessage.safety_flag.is_not(None))
        .order_by(ChatMessage.created_at.desc())
        .limit(5)
    ).all()
    recent_safety = [
        {
            "id": message.id,
            "user_id": session.user_id,
            "nickname": profile.nickname if profile else "未知用户",
            "safety_flag": message.safety_flag,
            "content": message.content[:160],
            "created_at": _iso(message.created_at),
        }
        for message, session, profile in safety_rows
    ]

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
        .options(program_load_options())
        .where(Program.user_id == user_id)
        .order_by(Program.created_at.desc())
    ).scalars().all()
    workouts = db.execute(
        select(WorkoutSession)
        .options(selectinload(WorkoutSession.sets))
        .where(WorkoutSession.user_id == user_id)
        .order_by(WorkoutSession.started_at.desc())
        .limit(50)
    ).scalars().all()
    chats = db.execute(
        select(ChatSession)
        .options(selectinload(ChatSession.messages))
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

    totals = db.execute(
        select(
            func.count(func.distinct(WorkoutSession.id)),
            func.coalesce(func.sum(SetLog.weight_kg * SetLog.reps), 0.0),
        )
        .select_from(WorkoutSession)
        .outerjoin(
            SetLog,
            and_(
                SetLog.session_id == WorkoutSession.id,
                SetLog.completed.is_(True),
            ),
        )
        .where(WorkoutSession.user_id == user_id)
    ).one()
    counts = db.execute(
        select(
            select(func.count())
            .select_from(Program)
            .where(Program.user_id == user_id)
            .scalar_subquery(),
            select(func.count())
            .select_from(ChatSession)
            .where(ChatSession.user_id == user_id)
            .scalar_subquery(),
            select(func.count())
            .select_from(EquipmentScan)
            .where(EquipmentScan.user_id == user_id)
            .scalar_subquery(),
            select(func.count())
            .select_from(MealPlan)
            .where(MealPlan.user_id == user_id)
            .scalar_subquery(),
        )
    ).one()
    programs_total, chats_total, scans_total, meals_total = (
        int(value or 0) for value in counts
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
            "workouts": int(totals[0] or 0),
            "volume_kg": round(float(totals[1] or 0), 1),
            "programs": int(programs_total),
            "chats": int(chats_total),
            "scans": int(scans_total),
            "meals": int(meals_total),
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
            statement.options(program_load_options())
            .order_by(Program.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        .scalars()
        .unique()
        .all()
    )
    items = []
    profiles = _profiles_by_user(db, [program.user_id for program in programs])
    for program in programs:
        profile = profiles.get(program.user_id)
        item = _program_summary(program)
        item["nickname"] = profile.nickname if profile else "未建档"
        items.append(item)
    return {"items": items, "total": total, "limit": limit, "offset": offset}


@router.get("/programs/{program_id}")
def program_detail(program_id: str, actor: AdminAuth, db: DBSession):
    program = load_program(db, program_id)
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
    lock_user(db, program.user_id)
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
            statement.options(selectinload(WorkoutSession.sets))
            .order_by(WorkoutSession.started_at.desc())
            .limit(limit)
            .offset(offset)
        )
        .scalars()
        .unique()
        .all()
    )
    items = []
    profiles = _profiles_by_user(db, [session.user_id for session in sessions])
    for session in sessions:
        profile = profiles.get(session.user_id)
        item = _workout_summary(session)
        item["nickname"] = profile.nickname if profile else "未建档"
        items.append(item)
    return {"items": items, "total": total, "limit": limit, "offset": offset}


@router.get("/workouts/{workout_id}")
def workout_detail(workout_id: str, actor: AdminAuth, db: DBSession):
    session = (
        db.execute(
            select(WorkoutSession)
            .options(selectinload(WorkoutSession.sets))
            .where(WorkoutSession.id == workout_id)
        )
        .scalar_one_or_none()
    )
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
            statement.options(selectinload(ChatSession.messages))
            .order_by(ChatSession.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        .scalars()
        .unique()
        .all()
    )
    items = []
    profiles = _profiles_by_user(db, [chat.user_id for chat in chats])
    for chat in chats:
        profile = profiles.get(chat.user_id)
        item = _chat_summary(chat)
        item["nickname"] = profile.nickname if profile else "未建档"
        items.append(item)
    return {"items": items, "total": total, "limit": limit, "offset": offset}


@router.get("/chats/{chat_id}")
def chat_detail(chat_id: str, actor: AdminAuth, db: DBSession):
    chat = db.get(ChatSession, chat_id, options=[selectinload(ChatSession.messages)])
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


@router.post("/videos/upload")
async def upload_video_file(
    actor: AdminAuth,
    file: UploadFile = File(...),
    kind: str = Form(default="video"),
):
    url, size = await _store_video_upload(file, kind)
    return {"url": url, "size": size, "kind": kind}


@router.get("/videos")
def list_videos(
    actor: AdminAuth,
    db: DBSession,
    q: str = Query(default="", max_length=80),
    status: str = Query(default="", max_length=20),
    limit: int = Query(default=100, ge=1, le=300),
    offset: int = Query(default=0, ge=0),
):
    statement = select(ExerciseVideo, Exercise).join(
        Exercise, Exercise.slug == ExerciseVideo.exercise_slug
    )
    text = q.strip()
    if text:
        statement = statement.where(
            or_(
                ExerciseVideo.title.contains(text),
                ExerciseVideo.exercise_slug.contains(text),
                Exercise.name_zh.contains(text),
            )
        )
    if status:
        statement = statement.where(ExerciseVideo.status == status)
    total = db.scalar(select(func.count()).select_from(statement.subquery())) or 0
    rows = db.execute(
        statement.order_by(ExerciseVideo.updated_at.desc())
        .limit(limit)
        .offset(offset)
    ).all()
    return {
        "items": [_video_dict(video, exercise) for video, exercise in rows],
        "total": total,
        "limit": limit,
        "offset": offset,
    }


@router.get("/videos/{video_id}")
def video_detail(video_id: str, actor: AdminAuth, db: DBSession):
    video = db.get(ExerciseVideo, video_id)
    if video is None:
        raise HTTPException(status_code=404, detail="教学视频不存在")
    return _video_dict(video, db.get(Exercise, video.exercise_slug))


@router.post("/videos")
def create_video(
    payload: ExerciseVideoCreate,
    actor: AdminAuth,
    db: DBSession,
):
    exercise = db.get(Exercise, payload.exercise_slug)
    if exercise is None:
        raise HTTPException(status_code=404, detail="动作不存在")
    video = ExerciseVideo(
        exercise_slug=payload.exercise_slug,
        title=payload.title.strip(),
        description=(payload.description or "").strip() or None,
        video_url=payload.video_url.strip(),
        poster_url=(payload.poster_url or "").strip() or None,
        duration_seconds=payload.duration_seconds,
        source=(payload.source or "").strip() or None,
        license_note=(payload.license_note or "").strip() or None,
        license_expires_at=payload.license_expires_at,
        status="draft",
        created_by=actor,
    )
    db.add(video)
    db.flush()
    if payload.status == "published":
        _publish_video(db, video)
    db.commit()
    db.refresh(video)
    _audit(
        db,
        actor,
        "video.create",
        "exercise_video",
        video.id,
        {"exercise_slug": video.exercise_slug, "status": video.status},
    )
    return _video_dict(video, exercise)


@router.patch("/videos/{video_id}")
def update_video(
    video_id: str,
    payload: ExerciseVideoUpdate,
    actor: AdminAuth,
    db: DBSession,
):
    video = db.get(ExerciseVideo, video_id)
    if video is None:
        raise HTTPException(status_code=404, detail="教学视频不存在")
    old_video_url = video.video_url
    old_poster_url = video.poster_url
    changes = payload.model_dump(exclude_unset=True)
    new_status = changes.pop("status", None)
    for field, value in changes.items():
        if isinstance(value, str):
            value = value.strip() or None
        setattr(video, field, value)
    if new_status == "published":
        _publish_video(db, video)
    elif new_status is not None:
        video.status = new_status
        video.updated_at = utcnow()
        db.flush()
        _sync_exercise_video(db, video.exercise_slug)
    elif video.status == "published":
        video.updated_at = utcnow()
        _sync_exercise_video(db, video.exercise_slug)
    db.commit()
    db.refresh(video)
    if old_video_url != video.video_url:
        remove_media_url(old_video_url)
    if old_poster_url != video.poster_url:
        remove_media_url(old_poster_url)
    _audit(
        db,
        actor,
        "video.update",
        "exercise_video",
        video.id,
        {"fields": sorted(changes.keys()) + (["status"] if new_status else [])},
    )
    return _video_dict(video, db.get(Exercise, video.exercise_slug))


@router.post("/videos/{video_id}/publish")
def publish_video(video_id: str, actor: AdminAuth, db: DBSession):
    video = db.get(ExerciseVideo, video_id)
    if video is None:
        raise HTTPException(status_code=404, detail="教学视频不存在")
    _publish_video(db, video)
    db.commit()
    db.refresh(video)
    _audit(
        db,
        actor,
        "video.publish",
        "exercise_video",
        video.id,
        {"exercise_slug": video.exercise_slug},
    )
    return _video_dict(video, db.get(Exercise, video.exercise_slug))


@router.post("/videos/{video_id}/unpublish")
def unpublish_video(video_id: str, actor: AdminAuth, db: DBSession):
    video = db.get(ExerciseVideo, video_id)
    if video is None:
        raise HTTPException(status_code=404, detail="教学视频不存在")
    video.status = "draft"
    video.updated_at = utcnow()
    db.flush()
    _sync_exercise_video(db, video.exercise_slug)
    db.commit()
    db.refresh(video)
    _audit(
        db,
        actor,
        "video.unpublish",
        "exercise_video",
        video.id,
        {"exercise_slug": video.exercise_slug},
    )
    return _video_dict(video, db.get(Exercise, video.exercise_slug))


@router.delete("/videos/{video_id}")
def delete_video(video_id: str, actor: AdminAuth, db: DBSession):
    video = db.get(ExerciseVideo, video_id)
    if video is None:
        raise HTTPException(status_code=404, detail="教学视频不存在")
    exercise_slug = video.exercise_slug
    remove_media_url(video.video_url)
    remove_media_url(video.poster_url)
    db.delete(video)
    db.flush()
    _sync_exercise_video(db, exercise_slug)
    db.commit()
    _audit(
        db,
        actor,
        "video.delete",
        "exercise_video",
        video_id,
        {"exercise_slug": exercise_slug},
    )
    return {"ok": True}


AI_KIND_LABELS = {
    "plan": "训练计划生成",
    "coach_trainer": "健身教练",
    "coach_rehab": "康复师",
    "coach_nutrition": "营养师",
    "food_vision": "饮食照片识别",
    "body_vision": "体型照片分析",
    "equipment_vision": "器械照片识别",
}

AI_SKILLS = [
    {
        "key": "trainer",
        "name": "健身教练",
        "description": "训练动作、计划调整、负荷与恢复建议",
        "prompt_version": "v1",
    },
    {
        "key": "rehab",
        "name": "康复师",
        "description": "疼痛分级、红旗症状识别、保守活动与转诊建议",
        "prompt_version": "v1",
    },
    {
        "key": "nutrition",
        "name": "营养师",
        "description": "热量、蛋白质、膳食结构与特殊人群提示",
        "prompt_version": "v1",
    },
]


def _ai_job_dict(job: AIJob, profile: Profile | None = None) -> dict:
    return {
        "id": job.id,
        "user_id": job.user_id,
        "nickname": profile.nickname if profile else None,
        "kind": job.kind,
        "kind_label": AI_KIND_LABELS.get(job.kind, job.kind),
        "model": job.model,
        "prompt_version": job.prompt_version,
        "input_tokens": job.input_tokens,
        "output_tokens": job.output_tokens,
        "latency_ms": job.latency_ms,
        "status": job.status,
        "error": job.error,
        "created_at": _iso(job.created_at),
    }


@router.get("/ai/overview")
def ai_overview(
    actor: AdminAuth,
    db: DBSession,
    days: int = Query(default=30, ge=1, le=90),
):
    since = utcnow() - timedelta(days=days)
    where = (AIJob.created_at >= since,)
    aggregate = db.execute(
        select(
            func.count(AIJob.id),
            func.coalesce(func.sum(case((AIJob.status == "ok", 1), else_=0)), 0),
            func.coalesce(func.sum(case((AIJob.status == "fallback", 1), else_=0)), 0),
            func.coalesce(func.avg(AIJob.latency_ms), 0),
            func.coalesce(func.sum(AIJob.input_tokens), 0),
            func.coalesce(func.sum(AIJob.output_tokens), 0),
        ).where(*where)
    ).one()
    total = int(aggregate[0] or 0)
    ok = int(aggregate[1] or 0)
    fallback = int(aggregate[2] or 0)
    latencies_avg = float(aggregate[3] or 0)
    input_tokens = int(aggregate[4] or 0)
    output_tokens = int(aggregate[5] or 0)

    by_kind: dict[str, dict] = {}
    for kind, calls, errors in db.execute(
        select(
            AIJob.kind,
            func.count(AIJob.id),
            func.coalesce(
                func.sum(case((AIJob.status != "ok", 1), else_=0)), 0
            ),
        )
        .where(*where)
        .group_by(AIJob.kind)
    ).all():
        by_kind[kind] = {
            "kind": kind,
            "label": AI_KIND_LABELS.get(kind, kind),
            "calls": int(calls or 0),
            "errors": int(errors or 0),
        }

    daily = {
        (day.isoformat() if hasattr(day, "isoformat") else str(day)): int(calls)
        for day, calls in db.execute(
            select(func.date(AIJob.created_at), func.count(AIJob.id))
            .where(*where)
            .group_by(func.date(AIJob.created_at))
            .order_by(func.date(AIJob.created_at))
        ).all()
    }

    skills = []
    for skill in AI_SKILLS:
        kind = f"coach_{skill['key']}"
        skills.append(
            {
                **skill,
                "calls": by_kind.get(kind, {}).get("calls", 0),
                "errors": by_kind.get(kind, {}).get("errors", 0),
                "available": not settings.use_mock_llm,
            }
        )

    return {
        "window_days": days,
        "total": total,
        "ok": ok,
        "fallback": fallback,
        "errors": total - ok - fallback,
        "success_rate": round(ok / total, 4) if total else 0,
        "avg_latency_ms": round(latencies_avg) if total else None,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "by_kind": sorted(by_kind.values(), key=lambda item: -item["calls"]),
        "daily": [
            {"date": day, "calls": daily.get(day, 0)}
            for day in sorted(daily)
        ],
        "provider": {
            "provider": settings.llm_provider,
            "model": settings.llm_model,
            "base_url": settings.llm_base_url,
            "mode": "mock" if settings.use_mock_llm else "remote",
            "configured": bool(settings.llm_api_key),
        },
        "skills": skills,
    }


@router.get("/ai/jobs")
def list_ai_jobs(
    actor: AdminAuth,
    db: DBSession,
    q: str = Query(default="", max_length=80),
    status: str = Query(default="", max_length=20),
    kind: str = Query(default="", max_length=40),
    limit: int = Query(default=100, ge=1, le=300),
    offset: int = Query(default=0, ge=0),
):
    statement = select(AIJob).outerjoin(User, User.id == AIJob.user_id).outerjoin(
        Profile, Profile.user_id == AIJob.user_id
    )
    text = q.strip()
    if text:
        statement = statement.where(
            or_(
                AIJob.user_id.contains(text),
                AIJob.kind.contains(text),
                AIJob.model.contains(text),
                AIJob.error.contains(text),
                Profile.nickname.contains(text),
            )
        )
    if status:
        statement = statement.where(AIJob.status == status)
    if kind:
        statement = statement.where(AIJob.kind == kind)
    total = db.scalar(select(func.count()).select_from(statement.subquery())) or 0
    jobs = (
        db.execute(
            statement.order_by(AIJob.created_at.desc()).limit(limit).offset(offset)
        )
        .scalars()
        .unique()
        .all()
    )
    profiles = {
        profile.user_id: profile
        for profile in db.execute(
            select(Profile).where(
                Profile.user_id.in_([job.user_id for job in jobs if job.user_id])
            )
        ).scalars()
    } if jobs else {}
    return {
        "items": [_ai_job_dict(job, profiles.get(job.user_id)) for job in jobs],
        "total": total,
        "limit": limit,
        "offset": offset,
    }


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
