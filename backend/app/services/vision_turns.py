"""Shared helpers for photo analysis turns.

The legacy ``/coach/vision`` endpoint keeps its own ``ChatSession`` ledger for
old app builds. New builds use ``/coach/turns/vision`` and write the same
text-only visual turn into the control-plane ``CoachTurn`` table, so follow-up
questions and history pagination share one ledger.
"""

from __future__ import annotations

from fastapi import HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import CoachSession, CoachTurn, utcnow

MAX_VISION_FILES = 6
MAX_VISION_FILE_BYTES = 8 * 1024 * 1024
MAX_VISION_TOTAL_BYTES = 24 * 1024 * 1024
IMAGE_CONTENT_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/heic",
    "image/heif",
    "image/webp",
}


def require_image_upload(upload: UploadFile) -> None:
    """Photos are the API contract; video must be converted to frames first."""
    content_type = (upload.content_type or "").lower()
    if content_type and content_type not in IMAGE_CONTENT_TYPES:
        raise HTTPException(
            status_code=415,
            detail="请上传图片；视频请先抽取关键帧再上传",
        )


def safety_response(decision) -> dict:
    return {
        "mode": "general",
        "is_training": False,
        "summary": decision.reply or "",
        "observations": [],
        "next_cue": "",
        "safety_flag": decision.flag,
        "warning": None,
    }


def history_text(result: dict) -> str:
    parts: list[str] = []
    summary = str(result.get("summary") or "").strip()
    if summary:
        parts.append(summary)
    observations = result.get("observations") or []
    if observations:
        parts.append("可见：" + "；".join(str(item)[:80] for item in observations[:3]))
    next_cue = str(result.get("next_cue") or "").strip()
    if next_cue:
        parts.append("提示：" + next_cue[:240])
    return "\n".join(parts)[:4000] or "图片分析完成。"


def control_history_context(
    db: Session,
    user_id: str,
    session_id: str,
    limit: int = 6,
) -> str:
    rows = (
        db.execute(
            select(CoachTurn)
            .where(
                CoachTurn.user_id == user_id,
                CoachTurn.session_id == session_id,
            )
            .order_by(CoachTurn.created_at.desc(), CoachTurn.id.desc())
            .limit(limit)
        )
        .scalars()
        .all()
    )
    rows.reverse()
    lines: list[str] = []
    for item in rows:
        if item.input_text:
            lines.append(f"用户：{item.input_text[:300]}")
        if item.reply:
            lines.append(f"助手：{item.reply[:300]}")
    return "\n".join(lines)


def existing_turn_result(
    db: Session,
    user_id: str,
    cached: dict,
) -> dict | None:
    """Reuse the turn recorded for a cached photo result.

    A client retry with the same idempotency key must not append a duplicate
    visual turn to the history. Legacy cache rows have no turn id, so those
    still go through the normal recording path.
    """
    turn_id = cached.get("turn_id")
    if not turn_id:
        return None
    turn = db.get(CoachTurn, str(turn_id))
    if turn is None or turn.user_id != user_id:
        return None
    result = dict(cached)
    result["session_id"] = turn.session_id
    result["turn_id"] = turn.id
    return result


def record_control_vision_turn(
    db: Session,
    user_id: str,
    session: CoachSession,
    question: str,
    image_count: int,
    result: dict,
) -> dict:
    """Persist a text-only visual turn in the control-plane session.

    Raw images are deliberately not stored. The marker keeps the user side
    readable in history and tells later text turns that a photo was involved.
    """
    marker = "[图片]" if image_count <= 1 else f"[图片 x{image_count}]"
    content = f"{marker} {question.strip()}".strip()
    turn = CoachTurn(
        session_id=session.id,
        user_id=user_id,
        input_text=content[:2000],
        intent="coach.vision",
        status="completed",
        reply=history_text(result),
    )
    db.add(turn)
    session.last_turn_at = utcnow()
    session.updated_at = utcnow()
    db.flush()
    result = dict(result)
    result["session_id"] = session.id
    result["turn_id"] = turn.id
    return result
