"""Single-exercise plan edits.

Covers swapping one exercise and changing sets/reps/weight/rest/removing one
exercise. The whole day is snapshotted so undo can restore it atomically.
"""

from __future__ import annotations

import re
from datetime import date, datetime
from zoneinfo import ZoneInfo

from sqlalchemy.orm import Session

from ....models import Program, ProgramDay
from ..registry import Capability, register
from .training import _source_day
from .training_edit import (
    _day_by_focus,
    _resolve_exercise,
    _snapshot,
)

CAPABILITY = register(
    Capability(
        id="training.edit_day_exercise",
        domain="training",
        kind="write",
        title="修改单个动作",
        description="替换动作，或修改组数、次数、重量、休息",
        requires_confirmation=True,
        undo=True,
        events=("TrainingPlanAdjusted",),
    )
)

_SWAP = re.compile(r"(?:换成|替换成|替换为|改为)\s*([^，。；;]+)")
_ADD = re.compile(r"(?:加上|加一个|加个|增加|再加)\s*([^，。；;]+)")
_BATCH_SPLIT = re.compile(r"[，,；;]\s*")
_BATCH_CHANGE = re.compile(
    r"改成|加到|调到|重量|休息|每组|\d+\s*(?:组|次|kg|公斤)",
    re.IGNORECASE,
)
_EXERCISE_HINT = re.compile(
    r"卧推|深蹲|硬拉|划船|推举|飞鸟|弯举|下压|引体|"
    r"臂屈伸|腿举|推胸|蝴蝶机|夹胸|侧平举|后束|卷腹|臀桥"
)
_SETS = re.compile(r"(\d+)\s*组")
_REPS = re.compile(r"(\d+)(?:\s*[-~到]\s*(\d+))?\s*次")
_WEIGHT = re.compile(r"(\d+(?:\.\d+)?)\s*(?:kg|公斤)", re.IGNORECASE)
_REST = re.compile(r"休息\s*(\d+)\s*秒")
_REMOVE = re.compile(r"删掉|去掉|删除")


def _day_candidates(context: dict, message: str, today: date) -> list[dict]:
    plan = context.get("plan") if isinstance(context, dict) else None
    days = plan.get("days") if isinstance(plan, dict) else None
    if not isinstance(days, list):
        return []
    ordered = sorted(
        [item for item in days if isinstance(item, dict)],
        key=lambda item: str(item.get("date") or ""),
    )
    upcoming = [
        item for item in ordered if str(item.get("date") or "") >= today.isoformat()
    ]
    past = [
        item for item in reversed(ordered)
        if str(item.get("date") or "") < today.isoformat()
    ]
    ordered = upcoming + past
    preferred = []
    source = _source_day(message, context, today=today)
    if source is not None:
        preferred.append(source)
    focus = _day_by_focus(context, message, today)
    if focus is not None and focus not in preferred:
        preferred.append(focus)
    result = list(preferred)
    for item in ordered:
        if item not in result:
            result.append(item)
    return result


def _match_exercise(day: ProgramDay, message: str):
    best = None
    for item in day.exercises:
        name = item.exercise.name_zh if item.exercise else ""
        if not name:
            continue
        score = 0
        if name in message:
            score = len(name)
        else:
            core = re.sub(
                r"^(哑铃|杠铃|史密斯机|绳索|器械|固定|辅助|坐姿|站姿|"
                r"上斜|下斜|窄距|宽距)",
                "",
                name,
            )
            if len(core) >= 2 and core in message:
                score = len(core)
        if score and (best is None or score > best[0]):
            best = (score, item)
    return best[1] if best is not None else None


def _find_day_and_exercise(
    db: Session,
    user_id: str,
    context: dict,
    message: str,
    today: date,
):
    plan = context.get("plan") if isinstance(context, dict) else {}
    plan_id = str(plan.get("id") or "")
    program = db.get(Program, plan_id) if plan_id else None
    if program is None or program.user_id != user_id or program.status != "active":
        return None
    for item in _day_candidates(context, message, today):
        day_id = str(item.get("id") or "")
        if not day_id:
            continue
        day = db.get(ProgramDay, day_id)
        if day is None or day.program_id != program.id:
            continue
        exercise = _match_exercise(day, message)
        if exercise is not None:
            return program, day, exercise, item
    return None


def _clean_exercise_name(value: str) -> str:
    cleaned = value.strip(" 动作。.！!")
    cleaned = re.split(
        r"\s+(?=\d|组|次|kg|公斤|重量|休息|每组)",
        cleaned,
        maxsplit=1,
    )[0]
    return cleaned.strip(" 动作。.！!")


def _apply_params(message: str, item: dict) -> dict | None:
    match = _SETS.search(message)
    if match:
        value = int(match.group(1))
        if not 1 <= value <= 10:
            return None
        item["sets"] = value
    match = _REPS.search(message)
    if match:
        low = int(match.group(1))
        high = int(match.group(2)) if match.group(2) else low
        if not 1 <= low <= high <= 50:
            return None
        item["reps"] = f"{low}-{high}" if high != low else str(low)
    match = _WEIGHT.search(message)
    if match:
        value = float(match.group(1))
        if not 0 <= value <= 500:
            return None
        item["weight_kg"] = value
    match = _REST.search(message)
    if match:
        value = int(match.group(1))
        if not 0 <= value <= 300:
            return None
        item["rest_sec"] = value
    return item


def _parse_after(message: str, current, new_slug: str | None) -> dict | None:
    after = {
        "slug": new_slug or current.exercise_slug,
        "sets": current.sets,
        "reps": current.reps,
        "weight_kg": current.weight_kg,
        "rest_sec": current.rest_sec,
        "rpe": current.rpe,
        "notes": current.notes,
    }
    changed = False
    if new_slug is not None:
        after["weight_kg"] = None
        changed = True
    match = _SETS.search(message)
    if match:
        value = int(match.group(1))
        if not 1 <= value <= 10:
            return None
        after["sets"] = value
        changed = True
    match = _REPS.search(message)
    if match:
        low = int(match.group(1))
        high = int(match.group(2)) if match.group(2) else low
        if not 1 <= low <= high <= 50:
            return None
        after["reps"] = f"{low}-{high}" if high != low else str(low)
        changed = True
    match = _WEIGHT.search(message)
    if match:
        value = float(match.group(1))
        if not 0 <= value <= 500:
            return None
        after["weight_kg"] = value
        changed = True
    match = _REST.search(message)
    if match:
        value = int(match.group(1))
        if not 0 <= value <= 300:
            return None
        after["rest_sec"] = value
        changed = True
    return after if changed else None


def _resolve_add(
    db: Session,
    user_id: str,
    message: str,
    context: dict,
    today: date,
    add_match: re.Match,
) -> dict:
    plan = context.get("plan") if isinstance(context, dict) else {}
    program = db.get(Program, str(plan.get("id") or ""))
    if program is None or program.user_id != user_id or program.status != "active":
        return {"ready": False, "questions": ["当前计划不在服务端，先在训练手账里同步计划。"]}
    target = None
    for item in _day_candidates(context, message, today):
        day = db.get(ProgramDay, str(item.get("id") or ""))
        if day is not None and day.program_id == program.id:
            target = (day, item)
            break
    if target is None:
        return {"ready": False, "questions": ["想加到哪一天？告诉我今天、明天或周几。"]}
    day, context_day = target
    raw = add_match.group(1)
    names = [
        _clean_exercise_name(item)
        for item in re.split(r"\s*和\s*|、|,|，|/", raw)
        if _clean_exercise_name(item)
    ]
    if not names:
        return {"ready": False, "questions": ["想加哪个动作？"]}
    resolved: list[tuple[str, str]] = []
    seen_slugs: set[str] = set()
    for name in names:
        exercise, resolved_name = _resolve_exercise(db, name)
        if exercise is None:
            return {
                "ready": False,
                "questions": [f"没有找到「{name}」这个动作，换个说法试试。"],
            }
        if exercise.slug in seen_slugs or any(
            item.exercise_slug == exercise.slug for item in day.exercises
        ):
            return {
                "ready": False,
                "questions": [f"「{resolved_name}」已经在这次训练里了。"],
            }
        seen_slugs.add(exercise.slug)
        resolved.append((exercise.slug, resolved_name))

    template = day.exercises[0] if day.exercises else None
    new_items = []
    for slug, resolved_name in resolved:
        new_item = {
            "slug": slug,
            "sets": template.sets if template is not None else 3,
            "reps": template.reps if template is not None else "8-12",
            "weight_kg": None,
            "rest_sec": template.rest_sec if template is not None else 90,
            "rpe": template.rpe if template is not None else 7.5,
            "notes": None,
        }
        if _apply_params(message, new_item) is None:
            return {
                "ready": False,
                "questions": [f"「{resolved_name}」的参数不太对，再确认一下。"],
            }
        new_items.append(new_item)

    before = _snapshot(day)
    date_label = str(context_day.get("date") or "")
    watchouts = []
    if re.search(r"今天|今日", message) and date_label != today.isoformat():
        watchouts.append(f"今天没有对应训练，按 {date_label or '下一个训练日'} 处理。")
    names_text = "、".join(name for _, name in resolved)
    return {
        "ready": True,
        "payload": {
            "plan_id": program.id,
            "day_id": day.id,
            "date": date_label,
            "title": day.title,
            "before": before,
            "exercises": [*before, *new_items],
            "summary": (
                f"准备在{date_label}的「{day.title}」加上「{names_text}」，"
                f"{new_items[0]['sets']} 组 × {new_items[0]['reps']}。"
            ),
            "wins": [name for _, name in resolved],
            "watchouts": watchouts,
            "actions": [],
        },
    }


def _resolve_batch(
    db: Session,
    user_id: str,
    message: str,
    context: dict,
    today: date,
) -> dict | None:
    segments = [
        item.strip()
        for item in _BATCH_SPLIT.split(message)
        if item.strip()
    ]
    actionable = [
        item
        for item in segments
        if _EXERCISE_HINT.search(item)
        and _BATCH_CHANGE.search(item)
        and not re.search(r"换成|替换|加上|加一个|加个|删掉|去掉|删除", item)
    ]
    if len(actionable) < 2:
        return None
    found = _find_day_and_exercise(db, user_id, context, actionable[0], today)
    if found is None:
        return {
            "ready": False,
            "questions": ["没有在计划里找到这些动作，先确认动作名或训练日。"],
        }
    program, day, _, context_day = found
    before = _snapshot(day)
    by_id = {item["id"]: item for item in before}
    wins = []
    for segment in actionable:
        current = _match_exercise(day, segment)
        if current is None:
            return {
                "ready": False,
                "questions": [f"没有在今天计划里找到「{segment}」里的动作。"],
            }
        after = _parse_after(segment, current, None)
        if after is None:
            return {
                "ready": False,
                "questions": [f"没看懂「{segment}」要改成什么。"],
            }
        by_id[current.id] = after
        name = current.exercise.name_zh if current.exercise else current.exercise_slug
        wins.append(f"{name}：{after['sets']} 组 × {after['reps']}")
    exercises = [by_id[item["id"]] for item in before if item["id"] in by_id]
    date_label = str(context_day.get("date") or "")
    return {
        "ready": True,
        "payload": {
            "plan_id": program.id,
            "day_id": day.id,
            "date": date_label,
            "title": day.title,
            "before": before,
            "exercises": exercises,
            "summary": (
                f"准备修改{date_label}的「{day.title}」里的 "
                f"{len(actionable)} 个动作。"
            ),
            "wins": wins,
            "watchouts": [],
            "actions": [],
        },
    }


def resolve(
    db: Session,
    user_id: str,
    message: str,
    context: dict,
) -> dict:
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    batch = _resolve_batch(db, user_id, message, context, today)
    if batch is not None:
        return batch
    add_match = _ADD.search(message)
    if add_match:
        return _resolve_add(db, user_id, message, context, today, add_match)

    found = _find_day_and_exercise(db, user_id, context, message, today)
    if found is None:
        return {
            "ready": False,
            "questions": ["没有在计划里找到这个动作，先确认动作名或训练日。"],
        }
    program, day, current, context_day = found
    new_slug = None
    new_name = None
    swap_match = _SWAP.search(message)
    if swap_match:
        new_name = _clean_exercise_name(swap_match.group(1))
        exercise, resolved_name = _resolve_exercise(db, new_name)
        if exercise is None:
            return {
                "ready": False,
                "questions": [f"没有找到「{new_name}」这个动作，换个说法试试。"],
            }
        new_slug = exercise.slug
        new_name = resolved_name

    remove = bool(_REMOVE.search(message))
    if remove and len(day.exercises) <= 1:
        return {
            "ready": False,
            "questions": ["这是当天最后一个动作，先加一个替代动作再删除。"],
        }
    after = _parse_after(message, current, new_slug)
    if remove:
        after = None
    if after is None and not remove:
        return {
            "ready": False,
            "questions": [
                "想怎么改？可以说“换成哑铃卧推”“改成4组”“重量加到20kg”。"
            ],
        }

    before = _snapshot(day)
    exercises = []
    for item in before:
        if item.get("id") == current.id:
            if not remove:
                exercises.append(after)
            continue
        exercises.append(item)
    old_name = current.exercise.name_zh if current.exercise else current.exercise_slug
    date_label = str(context_day.get("date") or "")
    watchouts: list[str] = []
    if re.search(r"今天|今日", message) and date_label != today.isoformat():
        watchouts.append(f"今天没有对应训练，按 {date_label or '下一个训练日'} 处理。")
    if new_name is not None:
        watchouts.append("换动作后重量已清空，按新动作重新选重量。")
    if remove:
        summary = f"准备从{date_label}的「{day.title}」删除「{old_name}」。"
        wins = [f"删除 {old_name}"]
    elif new_name:
        summary = (
            f"准备把{date_label}的「{day.title}」里的"
            f"「{old_name}」换成「{new_name}」。"
        )
        wins = [f"{old_name} → {new_name}"]
    else:
        summary = f"准备修改{date_label}的「{day.title}」里的「{old_name}」。"
        wins = [f"{old_name}：{after['sets']} 组 × {after['reps']}"]
        if after.get("weight_kg") is not None:
            wins.append(f"重量 {after['weight_kg']} kg")
        if after.get("rest_sec") is not None:
            wins.append(f"休息 {after['rest_sec']} 秒")
    return {
        "ready": True,
        "payload": {
            "plan_id": program.id,
            "day_id": day.id,
            "date": date_label,
            "title": day.title,
            "before": before,
            "exercises": exercises,
            "summary": summary,
            "wins": wins,
            "watchouts": watchouts,
            "actions": [],
        },
    }
