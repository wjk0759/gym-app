"""Guided conversational profile onboarding.

The coach collects the minimum set of profile fields over a few turns, then
hands the user one batch confirmation card built from existing write
capabilities. Parsing is deterministic: the model can phrase the question, but
it never decides what the user's height, goal or equipment is.

The draft lives in ``coach_pending`` with kind="draft" so a restart or a new
device can continue from the collected slots instead of starting over.
"""

from __future__ import annotations

import re
from datetime import date

from sqlalchemy.orm import Session

from ...models import Profile
from ..lexicon import EQUIPMENT_ALIASES, EQUIPMENT_LABELS
from ..queries import active_goal
from .capabilities.body import resolve as resolve_body
from .capabilities.profile import (
    CHINESE_NUMBERS,
    _extract_birth_date,
    _extract_height,
    _extract_session_minutes,
    _extract_sex,
    _extract_weekly_days,
    extract_goal_type,
)

# Order matters: the first missing field drives the next question.
REQUIRED = (
    "sex",
    "birth_date",
    "height_cm",
    "weight_kg",
    "goal_type",
    "weekly_days",
    "session_minutes",
    "equipment",
)
BASIC = ("sex", "birth_date", "height_cm", "weight_kg")
QUESTIONS = {
    "sex": "先确认性别：男还是女？",
    "birth_date": "出生年份和月份？例如“1995年6月”。",
    "height_cm": "身高多少？例如“178cm”。",
    "weight_kg": "现在体重多少？例如“72.5kg”。",
    "goal_type": "目标是什么：减脂、增肌、塑形还是体能？",
    "weekly_days": "每周能练几天？例如“3天”。",
    "session_minutes": "每次大概多少分钟？例如“45分钟”。",
    "equipment": "平时能用到哪些器械？例如“徒手、哑铃”，或者“只有健身房器械”。",
}
SKIP = re.compile(r"^(?:跳过|不知道|不想说|先不填|以后再说)[。！!]?$")


def _is_skip(message: str) -> bool:
    return bool(SKIP.match(message.strip()))


def _parse_weight(message: str) -> float | None:
    resolved = resolve_body(message)
    if resolved.get("ready"):
        value = (resolved.get("payload") or {}).get("weight_kg")
        if value is not None:
            return float(value)
    match = re.search(
        r"(?:体重|称重|重)\s*(?:是|为|:|：)?\s*(\d{2,3}(?:\.\d+)?)",
        message,
    )
    if match is None:
        return None
    value = float(match.group(1))
    return value if 20 <= value <= 300 else None


def _parse_equipment(message: str) -> list[str] | None:
    text = message.lower()
    if re.search(r"徒手|自重|没器械|没有器械|无器械|不去健身房|家里没", message):
        return ["bodyweight"]
    found = [
        value
        for value, aliases in EQUIPMENT_ALIASES.items()
        if value != "other" and any(alias.lower() in text for alias in aliases)
    ]
    if not found:
        return None
    if "bodyweight" not in found:
        found.append("bodyweight")
    found = list(dict.fromkeys(found))
    found.sort(key=list(EQUIPMENT_LABELS).index)
    return found


def _parse_slots(message: str, slots: dict, asked: list[str] | None = None) -> dict:
    """Merge every field the user mentioned into the draft.

    One sentence can fill several slots ("男，1995年6月，178cm，72kg"), which is
    why this returns a dict instead of asking one field at a time in code.
    """
    result = dict(slots)
    asked = asked or []

    # A bare answer ("72", "178", "3", "45") is only meaningful because we know
    # which question was just asked. Prefer height for 100–250 when both height
    # and weight are still open; otherwise treat it as weight.
    bare = re.fullmatch(
        r"\s*(\d{2,3}(?:\.\d+)?)\s*(kg|公斤|斤)?\s*",
        message,
        flags=re.IGNORECASE,
    )
    if bare is not None:
        value = float(bare.group(1))
        if bare.group(2) == "斤":
            value = value / 2
        if "height_cm" in asked and 100 <= value <= 250:
            result.setdefault("height_cm", round(value, 1))
        elif "weight_kg" in asked and 20 <= value <= 300:
            result.setdefault("weight_kg", round(value, 1))

    sex = _extract_sex(message)
    if sex:
        result["sex"] = sex
    elif re.match(r"^\s*男", message):
        result["sex"] = "male"
    elif re.match(r"^\s*女", message):
        result["sex"] = "female"
    birth_date = _extract_birth_date(message)
    if birth_date is not None:
        result["birth_date"] = birth_date.isoformat()
    height = _extract_height(message)
    if height is None:
        # The onboarding question is often answered with a bare "178".
        match = re.search(
            r"(?<!\d)(1[4-9]\d|2[0-2]\d)(?!\d)\s*(?:cm|厘米)?",
            message,
            flags=re.IGNORECASE,
        )
        if match is not None:
            height = float(match.group(1))
    if height is not None:
        result["height_cm"] = round(height, 1)
    weight = _parse_weight(message)
    if weight is not None:
        result["weight_kg"] = round(weight, 1)
    goal = extract_goal_type(message)
    if goal:
        result["goal_type"] = goal
    weekly_days = _extract_weekly_days(message)
    if weekly_days is None and "weekly_days" in asked:
        match = re.fullmatch(r"\s*([1-7一二三四五六七])\s*(?:天|次|练)?\s*", message)
        if match is not None:
            raw = match.group(1)
            weekly_days = CHINESE_NUMBERS.get(raw) or int(raw)
    if weekly_days is not None:
        result["weekly_days"] = weekly_days
    session_minutes = _extract_session_minutes(message)
    if session_minutes is None and "session_minutes" in asked:
        match = re.fullmatch(r"\s*(\d{2,3})\s*(?:分钟|min)?\s*", message)
        if match is not None:
            value = int(match.group(1))
            if 10 <= value <= 240:
                session_minutes = value
    if session_minutes is not None:
        result["session_minutes"] = session_minutes
    equipment = _parse_equipment(message)
    if equipment:
        result["equipment"] = equipment
    return result


def _existing_slots(db: Session, profile: Profile) -> dict:
    """Prefill only values the user can trust.

    Defaults such as male / 3 days / 45 minutes / bodyweight are not treated as
    answers until the profile was actually onboarded; otherwise every new user
    would never be asked about sex or schedule.
    """
    slots: dict = {}
    onboarded = profile.onboarded_at is not None
    if profile.birth_date is not None:
        slots["birth_date"] = profile.birth_date.isoformat()
    if profile.height_cm is not None:
        slots["height_cm"] = float(profile.height_cm)
    if profile.weight_kg is not None:
        slots["weight_kg"] = float(profile.weight_kg)
    if onboarded:
        if profile.sex in {"male", "female"}:
            slots["sex"] = profile.sex
        slots["weekly_days"] = int(profile.weekly_days or 3)
        slots["session_minutes"] = int(profile.session_minutes or 45)
        slots["equipment"] = list(profile.equipment or ["bodyweight"])
    elif profile.sex in {"female"}:
        # A non-default sex was deliberately chosen before onboarding.
        slots["sex"] = profile.sex
    goal = active_goal(db, profile.user_id)
    if goal is not None and goal.type:
        slots["goal_type"] = goal.type
    return slots


def _next_question(missing: list[str]) -> tuple[str, list[str]]:
    if set(BASIC).issubset(missing):
        return (
            "先填基础信息，可以一次说完：性别、出生年月、身高、体重。"
            "例如“男，1995年6月，178cm，72kg”。",
            list(BASIC),
        )
    if (
        {"weekly_days", "session_minutes"}.issubset(missing)
        and "goal_type" not in missing
    ):
        return (
            "每周能练几天、每次多久？例如“每周3天，每次45分钟”。",
            ["weekly_days", "session_minutes"],
        )
    field = missing[0]
    return QUESTIONS[field], [field]


def _profile_summary(slots: dict) -> str:
    parts = []
    if slots.get("sex"):
        parts.append("女" if slots["sex"] == "female" else "男")
    if slots.get("birth_date"):
        parts.append(str(slots["birth_date"])[:7])
    if slots.get("height_cm"):
        parts.append(f"{float(slots['height_cm']):g}cm")
    if slots.get("weight_kg"):
        parts.append(f"{float(slots['weight_kg']):g}kg")
    if slots.get("goal_type"):
        parts.append(
            {
                "lose_fat": "减脂",
                "build_muscle": "增肌",
                "recomp": "塑形",
                "endurance": "体能",
            }.get(slots["goal_type"], slots["goal_type"])
        )
    if slots.get("weekly_days") and slots.get("session_minutes"):
        parts.append(
            f"每周{int(slots['weekly_days'])}天×{int(slots['session_minutes'])}分钟"
        )
    if slots.get("equipment"):
        labels = "、".join(
            EQUIPMENT_LABELS.get(item, item) for item in slots["equipment"]
        )
        parts.append(labels)
    return "，".join(parts)


def _build_payload(slots: dict, skipped: list[str]) -> dict:
    """Translate collected slots into the existing write capabilities."""
    actions: list[dict] = []
    profile_payload: dict = {}
    for field in (
        "sex",
        "birth_date",
        "height_cm",
        "weekly_days",
        "session_minutes",
    ):
        if field in slots:
            profile_payload[field] = slots[field]
    if not skipped:
        # Only mark the profile complete when every required slot was answered.
        profile_payload["mark_onboarded"] = True
    if profile_payload:
        summary = "更新档案：" + _profile_summary(
            {key: slots[key] for key in slots if key in profile_payload}
        )
        profile_payload["summary"] = summary
        actions.append(
            {
                "capability_id": "profile.update",
                "payload": profile_payload,
                "summary": summary,
            }
        )

    if "weight_kg" in slots:
        summary = f"记录体重 {float(slots['weight_kg']):g} kg"
        actions.append(
            {
                "capability_id": "body.log_weight",
                "payload": {
                    "date": date.today().isoformat(),
                    "weight_kg": slots["weight_kg"],
                    "summary": summary,
                },
                "summary": summary,
            }
        )

    if "goal_type" in slots:
        labels = {
            "lose_fat": "减脂",
            "build_muscle": "增肌",
            "recomp": "塑形",
            "endurance": "体能",
        }
        summary = "设置目标：" + labels.get(slots["goal_type"], slots["goal_type"])
        actions.append(
            {
                "capability_id": "profile.update_goal",
                "payload": {
                    "goal_type": slots["goal_type"],
                    "summary": summary,
                },
                "summary": summary,
            }
        )

    if "equipment" in slots:
        labels = "、".join(
            EQUIPMENT_LABELS.get(item, item) for item in slots["equipment"]
        )
        summary = "更新器械：" + labels
        actions.append(
            {
                "capability_id": "profile.update_equipment",
                "payload": {
                    "equipment": slots["equipment"],
                    "summary": summary,
                },
                "summary": summary,
            }
        )

    return {
        "summary": "建立个人档案",
        "batch": actions,
        "reply": "档案信息已整理好，确认后一次写入。",
    }


def resolve(
    db: Session,
    user_id: str,
    message: str,
    draft: dict | None = None,
) -> dict:
    """Advance the onboarding draft by one user turn."""
    draft = draft or {}
    slots = dict(draft.get("slots") or {})
    skipped = [str(item) for item in draft.get("skipped") or [] if str(item)]
    asked = [str(item) for item in draft.get("asked") or [] if str(item)]
    profile = db.get(Profile, user_id)
    if profile is None:
        return {
            "ready": False,
            "slots": slots,
            "skipped": skipped,
            "asked": [],
            "missing": list(REQUIRED),
            "question": "先完成账号注册，我才能保存档案。",
            "terminal": True,
        }

    before = dict(slots)
    provided = False
    if _is_skip(message):
        for field in asked:
            if field not in skipped:
                skipped.append(field)
    else:
        slots = _parse_slots(message, slots, asked)
        provided = slots != before
        skipped = [field for field in skipped if field not in slots]

    # Merge trusted existing values without overwriting what the user just said.
    for field, value in _existing_slots(db, profile).items():
        slots.setdefault(field, value)

    missing = [
        field
        for field in REQUIRED
        if field not in slots and field not in skipped
    ]
    if not missing:
        if not provided and not skipped and profile.onboarded_at is not None:
            return {
                "ready": False,
                "slots": slots,
                "skipped": skipped,
                "asked": [],
                "missing": [],
                "question": "档案已经完整了，想改哪一项可以直接说。",
                "terminal": True,
            }
        if not slots:
            return {
                "ready": False,
                "slots": slots,
                "skipped": skipped,
                "asked": [],
                "missing": [],
                "question": "档案已经完整了，想改哪一项可以直接说。",
                "terminal": True,
            }
        payload = _build_payload(slots, skipped)
        summary = _profile_summary(slots)
        if skipped:
            reply = (
                f"先按这些信息建档：{summary}。"
                "跳过的项目之后可以在档案里补。确认后我会写入。"
            )
        else:
            reply = f"信息齐了：{summary}。确认后我会一次写入档案和体重记录。"
        return {
            "ready": True,
            "payload": payload,
            "slots": slots,
            "skipped": skipped,
            "missing": [],
            "reply": reply,
        }

    question, asked = _next_question(missing)
    return {
        "ready": False,
        "slots": slots,
        "skipped": skipped,
        "asked": asked,
        "missing": missing,
        "question": question,
    }
