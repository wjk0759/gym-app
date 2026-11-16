"""Profile, goal and injury update capabilities."""

from __future__ import annotations

import re
from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from ....models import Exercise, Goal, Profile
from ...food_text import parse_food_date
from ...plan_validator import injury_tags
from ...queries import active_goal, active_program
from ...serializers import load_program
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="profile.update_goal",
        domain="profile",
        kind="write",
        title="更新目标",
        description="修改目标类型、目标体重或目标日期",
        requires_confirmation=True,
        undo=True,
        events=("GoalUpdated",),
        refreshes=("profile", "diet", "review"),
    )
)
UPDATE_CAPABILITY = register(
    Capability(
        id="profile.update",
        domain="profile",
        kind="write",
        title="修改个人资料",
        description="修改昵称、性别、身高或经验等级",
        requires_confirmation=True,
        undo=True,
        events=("ProfileUpdated",),
        refreshes=("profile", "body", "diet", "review"),
    )
)
INJURY_CAPABILITY = register(
    Capability(
        id="profile.update_injuries",
        domain="profile",
        kind="write",
        title="更新伤病限制",
        description="记录或修改伤病，并检查当前计划冲突",
        requires_confirmation=True,
        undo=True,
        events=("ProfileInjuriesUpdated",),
        refreshes=("profile", "review"),
    )
)

PROFILE_LABELS = {
    "nickname": "昵称",
    "sex": "性别",
    "height_cm": "身高",
    "experience": "经验",
}
EXPERIENCE_WORDS = {
    "beginner": ("新手", "入门", "刚开始"),
    "intermediate": ("中级", "进阶"),
    "advanced": ("高级", "老手", "很多年"),
}


def _extract_nickname(message: str) -> str | None:
    value = message.strip()
    match = re.match(
        r"^(?:请)?(?:以后)?叫我\s*([^\s，,。；;！!？?]{1,20})",
        value,
    )
    if match is not None:
        return match.group(1)
    match = re.search(
        r"昵称\s*(?:改成|改为|叫)?\s*([^\s，,。；;！!？?]{1,20})",
        value,
    )
    if match is not None:
        return match.group(1)
    match = re.search(
        r"名字\s*(?:改成|改为)\s*([^\s，,。；;！!？?]{1,20})",
        value,
    )
    return match.group(1) if match is not None else None


def _extract_height(message: str) -> float | None:
    match = re.search(
        r"身高\s*(?:是|为|改成|改为|调到)?\s*"
        r"(\d{3})(?:\s*(?:cm|厘米))?",
        message,
        flags=re.IGNORECASE,
    )
    if match is not None:
        return float(match.group(1))
    match = re.search(r"(\d)\s*米\s*(\d{1,2})", message)
    if match is not None:
        return float(int(match.group(1)) * 100 + int(match.group(2)))
    match = re.search(r"(\d\.\d{1,2})\s*米", message)
    if match is not None:
        return round(float(match.group(1)) * 100, 1)
    return None


def _extract_sex(message: str) -> str | None:
    if re.search(r"女生|女的|女性|性别.*女", message):
        return "female"
    if re.search(r"男生|男的|男性|性别.*男", message):
        return "male"
    return None


def _extract_experience(message: str) -> str | None:
    for value, words in EXPERIENCE_WORDS.items():
        if any(word in message for word in words) and re.search(
            r"训练|练|健身|水平|经验|我是",
            message,
        ):
            return value
    if re.search(r"练了\s*[1-3一二三]\s*年", message):
        return "intermediate"
    if re.search(r"练了\s*(?:[4-9四五六七八九]|十|很多)\s*年", message):
        return "advanced"
    return None


def resolve_update(message: str) -> dict:
    payload: dict = {}
    nickname = _extract_nickname(message)
    if nickname:
        payload["nickname"] = nickname
    height = _extract_height(message)
    if height is not None:
        if not 100 <= height <= 250:
            return {
                "ready": False,
                "questions": ["身高看起来不太对，再确认一下？"],
            }
        payload["height_cm"] = round(height, 1)
    sex = _extract_sex(message)
    if sex:
        payload["sex"] = sex
    experience = _extract_experience(message)
    if experience:
        payload["experience"] = experience
    if not payload:
        return {
            "ready": False,
            "questions": [
                "想改昵称、性别、身高还是训练经验？例如“身高178”。"
            ],
        }
    labels = []
    for field in ("nickname", "sex", "height_cm", "experience"):
        if field in payload:
            value = payload[field]
            if field == "sex":
                value = "女" if value == "female" else "男"
            elif field == "experience":
                value = {
                    "beginner": "新手",
                    "intermediate": "中级",
                    "advanced": "高级",
                }.get(value, value)
            labels.append(f"{PROFILE_LABELS[field]} {value}")
    return {
        "ready": True,
        "payload": payload,
        "summary": "准备更新" + "、".join(labels),
    }


def _injury_text(message: str) -> str:
    value = re.sub(
        r"^(?:请)?(?:帮我)?"
        r"(?:记录一下|记录|记一下|更新|修改|调整|以后|记得|注意)"
        r"[，,：:\s]*",
        "",
        message.strip(),
    )
    value = re.sub(
        r"^(?:我的)?伤病(?:是|为|改成|改为|变成)?[，,：:\s]*",
        "",
        value,
    )
    return value.strip(" 。.!！")


def _injury_conflicts(
    db: Session,
    user_id: str,
    injuries: list[str],
) -> list[dict]:
    tags = injury_tags(injuries)
    if not tags:
        return []
    program = active_program(db, user_id)
    if program is None:
        return []
    program = load_program(db, program.id) or program
    conflicts: list[dict] = []
    seen: set[str] = set()
    for day in program.days:
        for item in day.exercises:
            exercise = db.get(Exercise, item.exercise_slug)
            if exercise is None:
                continue
            if not (tags & set(exercise.contraindications or [])):
                continue
            name = exercise.name_zh or exercise.slug
            if name in seen:
                continue
            seen.add(name)
            conflicts.append(
                {"day": day.title, "exercise": name}
            )
    return conflicts


def _dedupe_injuries(values: list[str]) -> list[str]:
    result: list[str] = []
    for value in values:
        text = str(value).strip()
        if text and text not in result:
            result.append(text)
    return result


INJURY_BODY_PARTS = ("膝", "腰", "肩", "腕", "踝", "肘", "半月板")


def _injury_body_parts(text: str) -> list[str]:
    return [part for part in INJURY_BODY_PARTS if part in text]


def resolve_injuries(
    db: Session,
    user_id: str,
    message: str,
) -> dict:
    if re.search(r"怎么办|怎么|为什么|如何|吗|？|\?", message):
        return {
            "ready": False,
            "questions": ["这是想让我记录成伤病限制吗？可以直接说“记录膝盖有伤”。"],
        }
    profile = db.get(Profile, user_id)
    before = list(profile.injuries or []) if profile is not None else []
    resolution = re.search(
        r"不疼|不痛|好了|康复|没事了|没有伤病|伤好了|恢复了",
        message,
    )
    if resolution is not None:
        if not before:
            return {
                "ready": False,
                "terminal": True,
                "questions": ["目前没有伤病记录，不需要清除。"],
            }
        contrast = re.split(
            r"但(?:是)?|不过|[，,；;、]",
            message,
            maxsplit=1,
        )
        if len(contrast) == 2:
            recover_text, pain_text = contrast
            pain_active = bool(re.search(r"疼|痛", pain_text)) and not re.search(
                r"不疼|不痛", pain_text
            )
            if pain_active:
                remove_parts = _injury_body_parts(recover_text)
                keep_parts = _injury_body_parts(pain_text)
                if remove_parts:
                    remaining = [
                        item
                        for item in before
                        if any(part in item for part in keep_parts)
                        or not any(part in item for part in remove_parts)
                    ]
                else:
                    remaining = list(before)
            else:
                parts = _injury_body_parts(message)
                if parts:
                    remaining = [
                        item
                        for item in before
                        if not any(part in item for part in parts)
                    ]
                elif re.search(
                    r"没有伤病|都好了|全好了|伤好了|康复了|恢复了",
                    message,
                ) or len(before) == 1:
                    remaining = []
                else:
                    return {
                        "ready": False,
                        "questions": ["是哪一处不疼了？例如“膝盖不疼了”。"],
                    }
        else:
            parts = _injury_body_parts(message)
            if parts:
                remaining = [
                    item
                    for item in before
                    if not any(part in item for part in parts)
                ]
            elif re.search(
                r"没有伤病|都好了|全好了|伤好了|康复了|恢复了",
                message,
            ) or len(before) == 1:
                remaining = []
            else:
                return {
                    "ready": False,
                    "questions": ["是哪一处不疼了？例如“膝盖不疼了”。"],
                }
        if remaining == before:
            return {
                "ready": False,
                "terminal": True,
                "questions": ["没找到对应的伤病记录。"],
            }
        summary = (
            "准备清除伤病限制"
            if not remaining
            else f"准备把伤病更新为「{'、'.join(remaining)}」"
        )
        conflicts = _injury_conflicts(db, user_id, remaining)
        if conflicts:
            names = "、".join(item["exercise"] for item in conflicts[:3])
            summary += (
                f"；当前计划有 {len(conflicts)} 个动作可能不适合（{names}）"
            )
        return {
            "ready": True,
            "payload": {
                "injuries": remaining,
                "summary": summary,
                "conflicts": conflicts,
            },
        }
    content = _injury_text(message)
    if len(content) < 2 or not re.search(
        r"伤|疼|痛|不舒服|不能|避免|半月板|腰|膝|肩|腕|踝|肘",
        content,
    ):
        return {
            "ready": False,
            "questions": ["想记录哪里的伤病？例如“膝盖有伤”。"],
        }
    append = bool(
        before and re.search(r"也|还有|又|新增|另外", message)
    )
    final = (
        _dedupe_injuries([*before, content])
        if append
        else [content]
    )
    if append:
        summary = f"准备在原有伤病中追加「{content}」"
    elif before:
        summary = f"准备把伤病从「{'、'.join(before)}」改为「{content}」"
    else:
        summary = f"准备记录伤病「{content}」"
    conflicts = _injury_conflicts(db, user_id, final)
    if conflicts:
        names = "、".join(item["exercise"] for item in conflicts[:3])
        summary += f"；当前计划有 {len(conflicts)} 个动作可能不适合（{names}）"
    return {
        "ready": True,
        "payload": {
            "content": content,
            "injuries": final,
            "summary": summary,
            "conflicts": conflicts,
        },
    }


def _profile_snapshot(profile: Profile, fields: tuple[str, ...]) -> dict:
    return {field: getattr(profile, field) for field in fields}


def execute_update(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    profile = db.get(Profile, user_id)
    if profile is None:
        profile = Profile(user_id=user_id)
        db.add(profile)
    fields = ("nickname", "sex", "height_cm", "experience")
    before = _profile_snapshot(profile, fields)
    for field in fields:
        if field in payload:
            setattr(profile, field, payload[field])
    db.flush()
    goal = active_goal(db, user_id)
    if (
        goal is not None
        and goal.type == "lose_fat"
        and profile.bmi is not None
        and profile.bmi < 18.5
    ):
        raise ValueError(
            "当前 BMI 低于 18.5，不建议以减脂为目标；先调整目标或身高后再试。"
        )
    return {
        "before": before,
        "after": _profile_snapshot(profile, fields),
    }


def undo_update(
    db: Session,
    user_id: str,
    before: dict,
) -> dict:
    profile = db.get(Profile, user_id)
    if profile is None:
        profile = Profile(user_id=user_id)
        db.add(profile)
    for field, value in (before or {}).items():
        if field in {"nickname", "sex", "height_cm", "experience"}:
            setattr(profile, field, value)
    db.flush()
    return {"restored": True}


def execute_injuries(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    profile = db.get(Profile, user_id)
    if profile is None:
        profile = Profile(user_id=user_id)
        db.add(profile)
    before = list(profile.injuries or [])
    raw = payload.get("injuries")
    if raw is None:
        content = str(payload.get("content") or "").strip()[:200]
        if not content:
            raise ValueError("伤病内容不能为空")
        final = [content]
    else:
        final = _dedupe_injuries([str(item) for item in raw])
    profile.injuries = final
    db.flush()
    conflicts = _injury_conflicts(db, user_id, profile.injuries)
    return {
        "before": {"injuries": before},
        "after": {"injuries": profile.injuries},
        "conflicts": conflicts,
    }


def undo_injuries(
    db: Session,
    user_id: str,
    before: dict,
) -> dict:
    profile = db.get(Profile, user_id)
    if profile is None:
        profile = Profile(user_id=user_id)
        db.add(profile)
    profile.injuries = list((before or {}).get("injuries") or [])
    db.flush()
    return {"restored": True}


GOAL_TYPES = {
    "减脂": "lose_fat",
    "减肥": "lose_fat",
    "增肌": "build_muscle",
    "塑形": "recomp",
    "重塑": "recomp",
    "耐力": "endurance",
    "体能": "endurance",
}


def resolve(message: str) -> dict:
    goal_type = None
    for label, value in GOAL_TYPES.items():
        if label in message:
            goal_type = value
            break
    weight = None
    match = re.search(
        r"(?:目标(?:体重)?(?:改成|改为|调整到|设成|定到|到)?|"
        r"减到|增到|降到|涨到)\s*"
        r"(\d{2,3}(?:\.\d+)?)\s*(kg|公斤|斤)?",
        message,
        flags=re.IGNORECASE,
    )
    if match:
        weight = float(match.group(1))
        if match.group(2) == "斤":
            weight = weight / 2
    target_date = parse_food_date(message) if re.search(r"前|之前|目标日期", message) else None
    if goal_type is None and weight is None and target_date is None:
        return {
            "ready": False,
            "questions": ["想改目标类型、目标体重，还是目标日期？"],
        }
    payload: dict = {}
    if goal_type:
        payload["goal_type"] = goal_type
    if weight is not None:
        if not 25 <= weight <= 300:
            return {"ready": False, "questions": ["目标体重看起来不太对，再确认一下？"]}
        payload["target_weight_kg"] = round(weight, 1)
    if target_date:
        payload["target_date"] = target_date.isoformat()
    return {"ready": True, "payload": payload}


def _serialize(goal: Goal | None) -> dict:
    if goal is None:
        return {}
    return {
        "type": goal.type,
        "target_weight_kg": goal.target_weight_kg,
        "target_body_fat_pct": goal.target_body_fat_pct,
        "target_waist_cm": goal.target_waist_cm,
        "target_date": goal.target_date.isoformat() if goal.target_date else None,
        "status": goal.status,
    }


def execute(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    goal = db.execute(
        select(Goal).where(Goal.user_id == user_id, Goal.status == "active")
    ).scalar_one_or_none()
    before = _serialize(goal)
    if goal is None:
        goal = Goal(user_id=user_id, type="recomp", status="active")
        db.add(goal)
    if payload.get("goal_type"):
        goal.type = str(payload["goal_type"])
    if payload.get("target_weight_kg") is not None:
        goal.target_weight_kg = float(payload["target_weight_kg"])
    if payload.get("target_date"):
        goal.target_date = date.fromisoformat(str(payload["target_date"]))
    db.flush()
    return {"before": before, "after": _serialize(goal)}


def undo(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
    before: dict,
) -> dict:
    goal = db.execute(
        select(Goal).where(Goal.user_id == user_id, Goal.status == "active")
    ).scalar_one_or_none()
    if not before:
        if goal is not None:
            db.delete(goal)
            db.flush()
        return {"restored": True, "deleted": True}
    if goal is None:
        goal = Goal(user_id=user_id, type="recomp", status="active")
        db.add(goal)
    goal.type = str(before.get("type") or "recomp")
    goal.target_weight_kg = before.get("target_weight_kg")
    goal.target_body_fat_pct = before.get("target_body_fat_pct")
    goal.target_waist_cm = before.get("target_waist_cm")
    goal.target_date = (
        date.fromisoformat(before["target_date"])
        if before.get("target_date")
        else None
    )
    db.flush()
    return {"restored": True}
