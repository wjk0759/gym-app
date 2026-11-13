"""Server-owned drafts for multi-turn coach actions."""

from __future__ import annotations

import re
from datetime import timedelta
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import AgentActionDraft, utcnow
from .food_text import parse_amount_grams

DRAFT_TTL = timedelta(minutes=30)
ACTIVE_STATUSES = {"collecting", "ready"}
AFFIRMATIVE = re.compile(r"^(对|是|是的|可以|嗯|好|行|没错)[。.!！]?$")


def _is_expired(draft: AgentActionDraft) -> bool:
    expires = draft.expires_at
    if expires.tzinfo is None:
        from datetime import timezone

        expires = expires.replace(tzinfo=timezone.utc)
    return expires < utcnow()


def _cancel_existing(db: Session, user_id: str, session_id: str) -> None:
    rows = (
        db.execute(
            select(AgentActionDraft).where(
                AgentActionDraft.user_id == user_id,
                AgentActionDraft.session_id == session_id,
                AgentActionDraft.status.in_(ACTIVE_STATUSES),
            )
        )
        .scalars()
        .all()
    )
    for row in rows:
        row.status = "cancelled"
    if rows:
        db.flush()


def get_active_draft(
    db: Session, user_id: str, session_id: str | None
) -> AgentActionDraft | None:
    if not session_id:
        return None
    draft = (
        db.execute(
            select(AgentActionDraft)
            .where(
                AgentActionDraft.user_id == user_id,
                AgentActionDraft.session_id == session_id,
                AgentActionDraft.status.in_(ACTIVE_STATUSES),
            )
            .order_by(AgentActionDraft.updated_at.desc())
        )
        .scalars()
        .first()
    )
    if draft is None:
        return None
    if _is_expired(draft):
        draft.status = "expired"
        db.flush()
        return None
    return draft


def get_latest_active_draft(
    db: Session, user_id: str
) -> AgentActionDraft | None:
    """Latest active draft across sessions, used for cross-device restore."""

    rows = (
        db.execute(
            select(AgentActionDraft)
            .where(
                AgentActionDraft.user_id == user_id,
                AgentActionDraft.status.in_(ACTIVE_STATUSES),
            )
            .order_by(AgentActionDraft.updated_at.desc())
        )
        .scalars()
        .all()
    )
    result: AgentActionDraft | None = None
    changed = False
    for row in rows:
        if _is_expired(row):
            row.status = "expired"
            changed = True
        elif result is None:
            result = row
    if changed:
        db.flush()
    return result


def create_food_draft(
    db: Session,
    user_id: str,
    session_id: str | None,
    *,
    date: str,
    meal: str,
    raw_text: str,
    resolution: dict,
) -> AgentActionDraft | None:
    slots = list(resolution.get("missing_slots") or [])
    questions = [
        str(value)[:120]
        for value in (resolution.get("questions") or [])
        if str(value).strip()
    ]
    if not session_id or (not slots and not questions):
        return None
    if not slots:
        slots = [{"field": "raw_text", "question": questions[0]}]
    _cancel_existing(db, user_id, session_id)
    draft = AgentActionDraft(
        id=str(uuid4()),
        user_id=user_id,
        session_id=session_id,
        draft_type="log_food",
        payload={
            "date": date,
            "meal": meal,
            "raw_text": raw_text,
            "items": resolution.get("items") or [],
        },
        missing_slots=slots,
        status="collecting",
        expires_at=utcnow() + DRAFT_TTL,
    )
    db.add(draft)
    db.flush()
    return draft


def _scale_item(item: dict, grams: float) -> dict:
    old = float(item.get("grams") or 0)
    factor = grams / old if old > 0 else 1.0
    updated = {**item}
    updated["grams"] = round(grams)
    updated["portion"] = f"约{round(grams)}g"
    for key in ("kcal", "protein_g", "carbs_g", "fat_g"):
        if item.get(key) is not None:
            updated[key] = round(float(item[key]) * factor, 1)
    updated["confidence"] = max(float(item.get("confidence") or 0.5), 0.75)
    return updated


def answer_food_draft(
    db: Session,
    user_id: str,
    session_id: str | None,
    text: str,
) -> dict | None:
    draft = get_active_draft(db, user_id, session_id)
    if draft is None or draft.draft_type != "log_food":
        return None

    value = text.strip()
    if re.search(r"取消|不要了|算了|不记了", value):
        draft.status = "cancelled"
        db.flush()
        return {"draft_id": draft.id, "cancelled": True, "questions": []}

    payload_data = draft.payload or {}
    slots = list(draft.missing_slots or [])
    if not slots:
        draft.status = "consumed"
        db.flush()
        return {
            "draft_id": draft.id,
            "ready": True,
            "date": payload_data.get("date"),
            "meal": payload_data.get("meal"),
            "items": payload_data.get("items") or [],
            "questions": [],
        }

    slot = slots[0]
    item_index = slot.get("item_index")
    items = list((draft.payload or {}).get("items") or [])
    if not isinstance(item_index, int) or not 0 <= item_index < len(items):
        return {
            "draft_id": draft.id,
            "ready": False,
            "questions": [slot.get("question") or "请补充份量"],
            "missing_slots": slots,
        }

    grams = parse_amount_grams(value)
    if grams is None and AFFIRMATIVE.match(value):
        grams = float(slot.get("suggested_grams") or 0) or None
    if grams is None:
        return {
            "draft_id": draft.id,
            "ready": False,
            "questions": [slot.get("question") or "请补充份量"],
            "missing_slots": slots,
        }

    items[item_index] = _scale_item(items[item_index], grams)
    slots.pop(0)
    draft.payload = {**(draft.payload or {}), "items": items}
    draft.missing_slots = slots
    if slots:
        draft.status = "collecting"
    else:
        draft.status = "consumed"
    draft.updated_at = utcnow()
    db.flush()
    return {
        "draft_id": draft.id,
        "ready": not slots,
        "date": (draft.payload or {}).get("date"),
        "meal": (draft.payload or {}).get("meal"),
        "items": items,
        "questions": [item.get("question") for item in slots],
        "missing_slots": slots,
    }


def needs_raw_clarification(draft: AgentActionDraft | None) -> bool:
    return draft is not None and any(
        isinstance(slot, dict) and slot.get("field") == "raw_text"
        for slot in (draft.missing_slots or [])
    )


def draft_context(draft: AgentActionDraft | None) -> dict | None:
    if draft is None or draft.status != "collecting":
        return None
    return {
        "id": draft.id,
        "draft_type": draft.draft_type,
        "payload": draft.payload,
        "missing_slots": draft.missing_slots,
        "questions": [
            item.get("question") for item in (draft.missing_slots or [])
        ],
    }


def compact_draft(draft: AgentActionDraft | None) -> dict | None:
    if draft is None or draft.status != "collecting":
        return None
    meal = (draft.payload or {}).get("meal") or "这一餐"
    labels = {
        "breakfast": "早餐",
        "lunch": "午餐",
        "dinner": "晚餐",
        "snack": "加餐",
    }
    return {
        "id": draft.id,
        "type": draft.draft_type,
        "summary": f"正在记录{labels.get(meal, meal)}",
        "questions": [
            item.get("question") for item in (draft.missing_slots or [])
        ],
        "missing_slots": draft.missing_slots,
    }


def cancel_draft(db: Session, user_id: str, draft_id: str) -> bool:
    draft = db.get(AgentActionDraft, draft_id)
    if draft is None or draft.user_id != user_id:
        raise LookupError("草稿不存在")
    if draft.status not in ACTIVE_STATUSES:
        return False
    draft.status = "cancelled"
    db.flush()
    return True


def consume_draft(db: Session, user_id: str, draft_id: str) -> None:
    draft = db.get(AgentActionDraft, draft_id)
    if draft is not None and draft.user_id == user_id:
        draft.status = "consumed"
        db.flush()
