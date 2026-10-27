"""Database concurrency helpers shared by services and routers."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import User


def lock_user(db: Session, user_id: str) -> None:
    """Serialize writes that must be unique per user (active plan/goal).

    MySQL takes a row lock; SQLite ignores ``FOR UPDATE`` and serializes the
    write itself. The call is a no-op for a missing user; the subsequent insert
    will raise the normal foreign-key error.
    """
    db.execute(
        select(User.id).where(User.id == user_id).with_for_update()
    ).scalar_one_or_none()
