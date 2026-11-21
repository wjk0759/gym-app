"""Profile, goal and injury update capabilities."""

from __future__ import annotations

import re
from datetime import date, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from ....models import Exercise, Goal, Profile, utcnow
from ...food_text import parse_food_date
from ...plan_validator import injury_tags
from ...queries import active_goal, active_program
from ...serializers import load_program
from ..injury_parse import parse_injury_message
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
    "birth_date": "出生日期",
    "height_cm": "身高",
    "experience": "经验",
    "weekly_days": "每周训练天数",
    "session_minutes": "单次时长",
}
EXPERIENCE_WORDS = {
    "beginner": ("新手", "入门", "刚开始"),
    "intermediate": ("中级", "进阶"),
    "advanced": ("高级", "老手", "很多年"),
}
CHINESE_NUMBERS = {
    "一": 1,
    "二": 2,
    "三": 3,
    "四": 4,
    "五": 5,
    "六": 6,
    "七": 7,
}


def _extract_birth_date(message: str) -> date | None:
    """Parse a birth month or age, never a full birthday we do not need.

    One month granularity is enough for age bands and nutrition targets. A
    bare year is allowed because users often say only "1995 年".
    """
    match = re.search(
        r"(19\d{2}|20\d{2})\s*[年./-]\s*(\d{1,2})",
        message,
    )
    if match is not None:
        year = int(match.group(1))
        month = int(match.group(2))
        if 1900 <= year <= date.today().year and 1 <= month <= 12:
            return date(year, month, 1)
    match = re.search(r"(19\d{2}|20\d{2})\s*年?", message)
    if match is not None:
        year = int(match.group(1))
        if 1900 <= year <= date.today().year:
            return date(year, 1, 1)
    match = re.search(r"(\d{2})\s*岁", message)
    if match is not None:
        age = int(match.group(1))
        if 12 <= age <= 90:
            return date(date.today().year - age, 1, 1)
    return None


def _extract_weekly_days(message: str) -> int | None:
    match = re.search(
        r"(?:每周|一周)\s*([1-7一二三四五六七])\s*(?:练|次|天)",
        message,
    )
    if match is None:
        match = re.search(r"([1-7一二三四五六七])\s*(?:练|次|天)", message)
    if match is None:
        return None
    raw = match.group(1)
    value = CHINESE_NUMBERS.get(raw) or int(raw)
    return value if 1 <= value <= 7 else None


def _extract_session_minutes(message: str) -> int | None:
    if "一个半小时" in message:
        return 90
    if "半小时" in message:
        return 30
    if "一小时" in message or "1小时" in message:
        return 60
    match = re.search(r"(\d{2,3})\s*分钟", message)
    if match is None:
        return None
    value = int(match.group(1))
    return value if 10 <= value <= 240 else None


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
    birth_date = _extract_birth_date(message)
    if birth_date is not None:
        payload["birth_date"] = birth_date.isoformat()
    weekly_days = _extract_weekly_days(message)
    if weekly_days is not None:
        payload["weekly_days"] = weekly_days
    session_minutes = _extract_session_minutes(message)
    if session_minutes is not None:
        payload["session_minutes"] = session_minutes
    experience = _extract_experience(message)
    if experience:
        payload["experience"] = experience
    if not payload:
        return {
            "ready": False,
            "questions": [
                "想改昵称、性别、身高、出生日期、训练频率还是训练经验？"
                "例如“身高178”或“每周3天，每次45分钟”。"
            ],
        }
    labels = []
    for field in (
        "nickname",
        "sex",
        "birth_date",
        "height_cm",
        "experience",
        "weekly_days",
        "session_minutes",
    ):
        if field in payload:
            value = payload[field]
            if field == "sex":
                value = "女" if value == "female" else "男"
            elif field == "birth_date":
                value = str(value)[:7]
            elif field == "experience":
                value = {
                    "beginner": "新手",
                    "intermediate": "中级",
                    "advanced": "高级",
                }.get(value, value)
            elif field == "weekly_days":
                value = f"每周 {value} 天"
            elif field == "session_minutes":
                value = f"每次 {value} 分钟"
            labels.append(f"{PROFILE_LABELS[field]} {value}")
    return {
        "ready": True,
        "payload": payload,
        "summary": "准备更新" + "、".join(labels),
    }


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
    parsed = parse_injury_message(message)

    remaining: list[str] | None
    if parsed.explicit_replace:
        remaining = None
    elif parsed.global_clear:
        remaining = []
    elif parsed.mentions:
        remaining = list(before)
        changed = False
        for part in parsed.recovered_parts:
            filtered = [item for item in remaining if part not in item]
            if len(filtered) != len(remaining):
                changed = True
            remaining = filtered
        new_texts: list[str] = []
        for mention in parsed.mentions:
            if mention.state != "ongoing":
                continue
            if any(mention.part in item for item in remaining):
                continue
            if mention.text and mention.text not in new_texts:
                new_texts.append(mention.text)
        if new_texts:
            remaining = _dedupe_injuries([*remaining, *new_texts])
            changed = True
        if not changed:
            if not before and parsed.recovered_parts and not parsed.ongoing_parts:
                return {
                    "ready": False,
                    "terminal": True,
                    "questions": ["目前没有伤病记录，不需要清除。"],
                }
            matches = [
                item
                for item in before
                if any(
                    part in item
                    for part in [
                        *parsed.recovered_parts,
                        *parsed.ongoing_parts,
                    ]
                )
            ]
            if matches:
                return {
                    "ready": False,
                    "terminal": True,
                    "questions": [
                        f"已经记着「{'、'.join(matches)}」还在恢复；"
                        "好了以后说“膝盖好了”，我再移除。"
                    ],
                }
            return {
                "ready": False,
                "terminal": True,
                "questions": ["没找到对应的伤病记录。"],
            }
    elif parsed.has_recovery:
        if not before:
            return {
                "ready": False,
                "terminal": True,
                "questions": ["目前没有伤病记录，不需要清除。"],
            }
        if len(before) == 1:
            remaining = []
        else:
            return {
                "ready": False,
                "questions": ["是哪一处不疼了？例如“膝盖不疼了”。"],
            }
    else:
        remaining = None

    if remaining is None:
        content = parsed.content
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
            summary += (
                f"；当前计划有 {len(conflicts)} 个动作可能不适合（{names}）"
            )
        return {
            "ready": True,
            "payload": {
                "content": content,
                "injuries": final,
                "summary": summary,
                "conflicts": conflicts,
            },
        }

    if not before and (
        parsed.global_clear
        or parsed.has_recovery
        or parsed.recovered_parts
    ):
        return {
            "ready": False,
            "terminal": True,
            "questions": ["目前没有伤病记录，不需要清除。"],
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


UPDATE_FIELDS = (
    "nickname",
    "sex",
    "birth_date",
    "height_cm",
    "experience",
    "weekly_days",
    "session_minutes",
    "onboarded_at",
)


def _json_value(value):
    """Make profile snapshots JSON-safe for the action ledger."""
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, date):
        return value.isoformat()
    return value


def _profile_snapshot(profile: Profile, fields: tuple[str, ...]) -> dict:
    return {field: _json_value(getattr(profile, field)) for field in fields}


def _profile_value(field: str, value):
    """Convert a JSON payload back to the column type on execute/undo."""
    if value is None:
        return None
    if field == "birth_date":
        return date.fromisoformat(str(value))
    if field == "onboarded_at":
        return datetime.fromisoformat(str(value))
    if field == "height_cm":
        return float(value)
    if field in {"weekly_days", "session_minutes"}:
        return int(value)
    return value


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
    before = _profile_snapshot(profile, UPDATE_FIELDS)
    for field in UPDATE_FIELDS:
        if field in payload:
            setattr(profile, field, _profile_value(field, payload[field]))
    # Conversational onboarding sets this only after all required slots were
    # collected, so the profile is not marked complete by a partial edit.
    if payload.get("mark_onboarded") and profile.onboarded_at is None:
        profile.onboarded_at = utcnow()
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
        "after": _profile_snapshot(profile, UPDATE_FIELDS),
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
        if field in UPDATE_FIELDS:
            setattr(profile, field, _profile_value(field, value))
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


def extract_goal_type(message: str) -> str | None:
    for label, value in GOAL_TYPES.items():
        if label in message:
            return value
    return None


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
