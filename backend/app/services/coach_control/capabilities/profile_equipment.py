"""Profile equipment from the coach.

This is the onboarding/profile equipment list, not the personal equipment
library. The library remains the precise source; this capability is for users
who say "我有哑铃" or "家里只有弹力带" before they maintain a library.
"""

from __future__ import annotations

import re

from sqlalchemy.orm import Session

from ....models import Exercise, Profile
from ...equipment_inventory import (
    declared_profile_equipment,
    effective_after_profile,
    replace_profile_equipment,
)
from ...lexicon import EQUIPMENT_ALIASES, EQUIPMENT_LABELS
from ...queries import active_program
from ...serializers import load_program
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="profile.update_equipment",
        domain="profile",
        kind="write",
        title="更新档案器械",
        description="修改档案里可用的器械条件，后续计划按此调整",
        requires_confirmation=True,
        undo=True,
        events=("ProfileEquipmentUpdated",),
        refreshes=("profile",),
    )
)

REPLACE = re.compile(
    r"只有|只用|只练|只做|改成|换成|改为|我的器械是|设备是|器材是|"
    r"家里只有|现在只有"
)
REMOVE = re.compile(r"没有|没|不用|不需要|去掉|移除|删掉|不练")


def _mentioned(message: str) -> list[str]:
    text = message.lower()
    found: list[str] = []
    for value, aliases in EQUIPMENT_ALIASES.items():
        if any(alias.lower() in text for alias in aliases):
            found.append(value)
    return found


def _removed(message: str) -> list[str]:
    text = message.lower()
    result: list[str] = []
    for value, aliases in EQUIPMENT_ALIASES.items():
        for alias in aliases:
            if re.search(
                rf"(?:没有|没|不用|不需要|去掉|移除|删掉|不练)"
                rf"\s*[^，,。；;]{{0,4}}{re.escape(alias.lower())}",
                text,
            ) or re.search(
                rf"{re.escape(alias.lower())}\s*"
                rf"(?:没有|没了|不用了|去掉了|卖了|卖掉了|丢了|坏了|送人了)",
                text,
            ):
                result.append(value)
                break
    return result


def _replaced_out(message: str) -> list[str]:
    match = re.search(
        r"(?:把|将)?(.+?)(?:换成|换为|替换成|改为|改成)(.+)",
        message,
    )
    if match is None:
        return []
    before = match.group(1)
    return [
        value
        for value, aliases in EQUIPMENT_ALIASES.items()
        if any(alias in before for alias in aliases)
    ]


def _current(db: Session, user_id: str) -> list[str]:
    values = [
        item
        for item in declared_profile_equipment(db, user_id)
        if item in EQUIPMENT_LABELS
    ]
    if "bodyweight" not in values:
        values.append("bodyweight")
    return values


def _equipment_conflicts(
    db: Session,
    user_id: str,
    equipment: list[str],
) -> list[dict]:
    program = active_program(db, user_id)
    if program is None:
        return []
    program = load_program(db, program.id) or program
    effective = set(effective_after_profile(db, user_id, equipment))
    conflicts: list[dict] = []
    seen: set[str] = set()
    for day in program.days:
        for item in day.exercises:
            exercise = db.get(Exercise, item.exercise_slug)
            if exercise is None or exercise.equipment in effective:
                continue
            name = exercise.name_zh or exercise.slug
            if name in seen:
                continue
            seen.add(name)
            conflicts.append({"day": day.title, "exercise": name})
    return conflicts


def _summary(values: list[str]) -> str:
    labels = "、".join(EQUIPMENT_LABELS.get(item, item) for item in values)
    return f"准备把档案器械更新为「{labels}」"


def resolve(db: Session, user_id: str, message: str) -> dict:
    profile = db.get(Profile, user_id)
    if profile is None:
        return {"ready": False, "questions": ["请先完成个人档案。"]}
    current = _current(db, user_id)
    mentioned = _mentioned(message)
    removed = list(dict.fromkeys([*_removed(message), *_replaced_out(message)]))
    if not mentioned and not removed:
        return {
            "ready": False,
            "questions": [
                "想更新成什么器械？可以说“我有哑铃和弹力带”"
                "或“家里没有器械，只有徒手”。"
            ],
        }

    positive = [item for item in mentioned if item not in removed]
    no_gear = re.search(r"没有器械|没器械|无器械|不去健身房", message)
    if no_gear and not (set(positive) - {"bodyweight"}):
        base: list[str] = []
        positive = ["bodyweight"]
    elif REPLACE.search(message):
        base = []
    else:
        base = list(current)
    values = [item for item in base if item not in removed]
    values.extend(positive)
    values = list(dict.fromkeys(values))
    if "bodyweight" not in values:
        values.append("bodyweight")
    values.sort(key=list(EQUIPMENT_LABELS).index)
    if values == current:
        labels = "、".join(EQUIPMENT_LABELS.get(item, item) for item in values)
        return {
            "ready": False,
            "terminal": True,
            "questions": [f"档案器械已经是「{labels}」了。"],
        }

    summary = _summary(values)
    remaining_types = (
        set(effective_after_profile(db, user_id, values)) - set(values)
    ) & set(removed)
    if remaining_types:
        names = "、".join(
            EQUIPMENT_LABELS.get(item, item)
            for item in sorted(remaining_types)
        )
        summary += (
            f"；个人器械库/通用器械里仍保留「{names}」，"
            "计划仍可能使用"
        )
    conflicts = _equipment_conflicts(db, user_id, values)
    if conflicts:
        names = "、".join(item["exercise"] for item in conflicts[:3])
        summary += (
            f"；当前计划有 {len(conflicts)} 个动作需要其他器械（{names}）"
        )
    return {
        "ready": True,
        "payload": {
            "equipment": values,
            "summary": summary,
            "conflicts": conflicts,
        },
    }


def execute(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    before = _current(db, user_id)
    replace_profile_equipment(
        db,
        user_id,
        list(payload.get("equipment") or ["bodyweight"]),
    )
    db.flush()
    return {
        "before": {"equipment": before},
        "after": {"equipment": _current(db, user_id)},
    }


def undo(
    db: Session,
    user_id: str,
    before: dict,
    payload: dict,
) -> dict:
    replace_profile_equipment(
        db,
        user_id,
        list((before or {}).get("equipment") or ["bodyweight"]),
    )
    db.flush()
    return {"restored": True}
