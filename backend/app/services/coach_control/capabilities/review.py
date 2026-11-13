"""Weekly review read capability."""

from __future__ import annotations

from sqlalchemy.orm import Session

from ...agent import generate_weekly_review
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="review.weekly",
        domain="review",
        kind="read",
        title="本周复盘",
        description="读取本周训练、饮食和执行率，并给出一个下一步建议",
        requires_confirmation=False,
        undo=False,
        events=("WeeklyReviewGenerated",),
    )
)


def resolve(db: Session, user_id: str) -> dict:
    review = generate_weekly_review(db, user_id)
    return {
        "ready": True,
        "payload": {
            "summary": review.get("summary"),
            "wins": review.get("wins") or [],
            "watchouts": review.get("watchouts") or [],
            "actions": review.get("actions") or [],
            "generated_at": review.get("generated_at"),
            "week_start": review.get("week_start"),
        },
    }
