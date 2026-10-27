from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from ..models import Exercise, Goal, PlanExercise, Program, ProgramDay, Profile
from .locking import lock_user


def program_load_options():
    """一次性加载计划日与动作，避免序列化时逐行触发 lazy load。"""
    return selectinload(Program.days).selectinload(ProgramDay.exercises)


def load_program(db: Session, program_id: str) -> Program | None:
    return (
        db.execute(
            select(Program)
            .options(program_load_options())
            .where(Program.id == program_id)
            .execution_options(populate_existing=True)
        )
        .scalar_one_or_none()
    )


def profile_to_dict(profile: Profile) -> dict:
    return {
        "nickname": profile.nickname,
        "sex": profile.sex,
        "birth_date": profile.birth_date.isoformat() if profile.birth_date else None,
        "age": profile.age,
        "height_cm": profile.height_cm,
        "weight_kg": profile.weight_kg,
        "body_fat_pct": profile.body_fat_pct,
        "bmi": profile.bmi,
        "chest_cm": profile.chest_cm,
        "waist_cm": profile.waist_cm,
        "hip_cm": profile.hip_cm,
        "experience": profile.experience,
        "injuries": profile.injuries or [],
        "equipment": profile.equipment or [],
        "weekly_days": profile.weekly_days,
        "session_minutes": profile.session_minutes,
        "onboarded": profile.onboarded_at is not None,
    }


def goal_to_dict(goal: Goal | None) -> dict | None:
    if goal is None:
        return None
    return {
        "id": goal.id,
        "type": goal.type,
        "target_weight_kg": goal.target_weight_kg,
        "target_body_fat_pct": goal.target_body_fat_pct,
        "target_waist_cm": goal.target_waist_cm,
        "target_date": goal.target_date.isoformat() if goal.target_date else None,
        "status": goal.status,
    }


def serialize_program(program: Program) -> dict:
    days = []
    for day in program.days:
        exercises = []
        for item in day.exercises:
            exercise: Exercise | None = item.exercise
            exercises.append(
                {
                    "id": item.id,
                    "slug": item.exercise_slug,
                    "name_zh": exercise.name_zh if exercise else item.exercise_slug,
                    "muscle_group": exercise.muscle_group if exercise else None,
                    "equipment": exercise.equipment if exercise else None,
                    "video_url": exercise.video_url if exercise else None,
                    "order_index": item.order_index,
                    "sets": item.sets,
                    "reps": item.reps,
                    "weight_kg": item.weight_kg,
                    "rest_sec": item.rest_sec,
                    "rpe": item.rpe,
                    "notes": item.notes,
                }
            )
        days.append(
            {
                "id": day.id,
                "week_index": day.week_index,
                "weekday": day.weekday,
                "title": day.title,
                "focus": day.focus or [],
                "exercises": exercises,
            }
        )
    return {
        "id": program.id,
        "title": program.title,
        "goal_type": program.goal_type,
        "version": program.version,
        "status": program.status,
        "start_date": program.start_date.isoformat(),
        "weeks": program.weeks,
        "generated_by": program.generated_by,
        "model_name": program.model_name,
        "created_at": program.created_at.isoformat(),
        "days": days,
    }


def _archive_active(db: Session, user_id: str) -> None:
    active = (
        db.execute(
            select(Program).where(
                Program.user_id == user_id, Program.status == "active"
            )
        )
        .scalars()
        .all()
    )
    for item in active:
        item.status = "archived"
    # 先 flush，避免 Postgres 的部分唯一索引在插入新 active 计划时冲突
    db.flush()


def _next_version(db: Session, user_id: str) -> int:
    current = db.execute(
        select(func.max(Program.version)).where(Program.user_id == user_id)
    ).scalar()
    return int(current or 0) + 1


def save_plan(
    db: Session,
    user_id: str,
    plan_doc: dict,
    goal_type: str,
    generated_by: str,
    model_name: str | None = None,
) -> Program:
    lock_user(db, user_id)
    _archive_active(db, user_id)
    program = Program(
        user_id=user_id,
        title=plan_doc["title"],
        goal_type=goal_type,
        version=_next_version(db, user_id),
        status="active",
        weeks=int(plan_doc.get("weeks", 4)),
        generated_by=generated_by,
        model_name=model_name,
    )
    for day_doc in plan_doc["days"]:
        day = ProgramDay(
            week_index=int(day_doc["week_index"]),
            weekday=int(day_doc["weekday"]),
            title=str(day_doc["title"]),
            focus=list(day_doc.get("focus") or []),
        )
        for item in day_doc["exercises"]:
            day.exercises.append(
                PlanExercise(
                    exercise_slug=item["slug"],
                    order_index=int(item["order_index"]),
                    sets=int(item["sets"]),
                    reps=str(item["reps"]),
                    weight_kg=item.get("weight_kg"),
                    rest_sec=int(item["rest_sec"]),
                    rpe=item.get("rpe"),
                )
            )
        program.days.append(day)

    db.add(program)
    db.commit()
    return load_program(db, program.id) or program


def clone_program(
    db: Session,
    user_id: str,
    source: Program,
    sets_delta: int = 0,
    weight_multiplier: float = 1.0,
    title_suffix: str = "",
    generated_by: str = "ai",
) -> Program:
    lock_user(db, user_id)
    _archive_active(db, user_id)
    version = _next_version(db, user_id)
    program = Program(
        user_id=user_id,
        title=(source.title + title_suffix)[:120],
        goal_type=source.goal_type,
        version=version,
        status="active",
        weeks=source.weeks,
        generated_by=generated_by,
        model_name="rule-adjustment",
    )
    for day in source.days:
        new_day = ProgramDay(
            week_index=day.week_index,
            weekday=day.weekday,
            title=day.title,
            focus=list(day.focus or []),
        )
        for item in day.exercises:
            weight = item.weight_kg
            if weight is not None and weight_multiplier != 1.0:
                weight = round(weight * weight_multiplier * 2) / 2
            new_day.exercises.append(
                PlanExercise(
                    exercise_slug=item.exercise_slug,
                    order_index=item.order_index,
                    sets=max(2, min(6, item.sets + sets_delta)),
                    reps=item.reps,
                    weight_kg=weight,
                    rest_sec=item.rest_sec,
                    rpe=item.rpe,
                    notes=item.notes,
                )
            )
        program.days.append(new_day)

    db.add(program)
    db.commit()
    return load_program(db, program.id) or program
