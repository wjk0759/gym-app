"""Exercise preferences from the coach."""

from __future__ import annotations

import re
from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ....models import Exercise, UserExerciseDislike, utcnow
from ...exercise_search import search_exercises
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="training.dislike_exercise",
        domain="training",
        kind="write",
        title="避开动作",
        description="把动作加入或移出“不喜欢”，后续计划尽量避开",
        requires_confirmation=True,
        undo=True,
        events=("ExerciseDislikeUpdated",),
        refreshes=("profile",),
    )
)

ADD = re.compile(
    r"(?:不喜欢|不想练|讨厌|别安排|避开|不要安排)"
    r"\s*[：:]?\s*(.+)"
)
REMOVE = re.compile(
    r"(?:可以安排|恢复安排|不讨厌|从不喜欢(?:里|中)?"
    r"(?:去掉|移除|删掉))\s*[：:]?\s*(.+)"
)


def _exercise_name(match: re.Match | None) -> str:
    if match is None:
        return ""
    value = match.group(1).strip(" ，,。；;：:")
    value = re.sub(r"(?:这个|那个)?(?:动作|训练)$", "", value)
    value = re.sub(r"(?:了|吧|啦|呀)$", "", value)
    return value.strip()[:80]


def _dislike(
    db: Session,
    user_id: str,
    slug: str,
) -> UserExerciseDislike | None:
    return db.execute(
        select(UserExerciseDislike).where(
            UserExerciseDislike.user_id == user_id,
            UserExerciseDislike.slug == slug,
        )
    ).scalar_one_or_none()


def resolve(db: Session, user_id: str, message: str) -> dict:
    remove_match = REMOVE.search(message)
    add_match = ADD.search(message)
    remove = remove_match is not None
    name = _exercise_name(remove_match if remove else add_match)
    if not name:
        return {
            "ready": False,
            "questions": ["要避开哪个动作？例如“不喜欢深蹲”。"],
        }
    results = search_exercises(name, limit=3)
    slug = str(results[0].get("slug") or "") if results else ""
    resolved_name = (
        str(results[0].get("name_zh") or name) if results else name
    )
    if not slug:
        exercise = db.execute(
            select(Exercise).where(
                func.lower(Exercise.name_zh) == name.lower()
            )
        ).scalar_one_or_none()
        if exercise is None:
            exercise = db.execute(
                select(Exercise).where(
                    Exercise.name_zh.contains(name)
                ).limit(1)
            ).scalar_one_or_none()
        if exercise is not None:
            slug = exercise.slug
            resolved_name = exercise.name_zh
    if not slug:
        return {
            "ready": False,
            "questions": [f"没有找到动作「{name}」，换个名称试试。"],
        }
    existing = _dislike(db, user_id, slug)
    active = existing is not None and existing.deleted_at is None
    if remove and not active:
        return {
            "ready": False,
            "terminal": True,
            "questions": [f"「{resolved_name}」不在避开列表里。"],
        }
    if not remove and active:
        return {
            "ready": False,
            "terminal": True,
            "questions": [f"已经记住要避开「{resolved_name}」了。"],
        }
    return {
        "ready": True,
        "payload": {
            "slug": slug,
            "name": resolved_name,
            "dislike": not remove,
            "summary": (
                f"准备记住避开「{resolved_name}」，后续计划尽量不安排"
                if not remove
                else f"准备恢复安排「{resolved_name}」"
            ),
        },
    }


def execute(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    slug = str(payload.get("slug") or "")
    if not slug:
        raise ValueError("动作不能为空")
    item = _dislike(db, user_id, slug)
    existed = item is not None
    before = {
        "existed": existed,
        "deleted_at": (
            item.deleted_at.isoformat()
            if item is not None and item.deleted_at is not None
            else None
        ),
    }
    if item is None:
        item = UserExerciseDislike(user_id=user_id, slug=slug)
        db.add(item)
    if payload.get("dislike", True):
        item.deleted_at = None
    else:
        item.deleted_at = utcnow()
    db.flush()
    return {
        "before": before,
        "after": {
            "slug": slug,
            "name": payload.get("name"),
            "dislike": item.deleted_at is None,
        },
    }


def undo(
    db: Session,
    user_id: str,
    before: dict,
    payload: dict,
) -> dict:
    slug = str(payload.get("slug") or "")
    item = _dislike(db, user_id, slug)
    if item is None:
        return {"restored": False}
    if not before.get("existed"):
        db.delete(item)
    else:
        deleted_at = before.get("deleted_at")
        item.deleted_at = (
            datetime.fromisoformat(str(deleted_at))
            if deleted_at
            else None
        )
    db.flush()
    return {"restored": True}
