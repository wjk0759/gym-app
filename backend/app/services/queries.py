"""Small, shared query helpers.

Keeping these reads in one place prevents subtle divergence between the app
routes, the coach agent, and the admin control plane. Every program load uses
the same eager-loading strategy so serializers never trigger N+1 queries.
"""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import Goal, Program, ProgramDay
from .serializers import program_load_options


def active_program(db: Session, user_id: str) -> Program | None:
    return (
        db.execute(
            select(Program)
            .options(program_load_options())
            .where(Program.user_id == user_id, Program.status == "active")
            .order_by(Program.version.desc())
        )
        .scalars()
        .first()
    )


def active_goal(db: Session, user_id: str) -> Goal | None:
    """Return the newest active goal.

    The data model expects one active goal per user, but using ``first`` here
    keeps legacy rows with duplicates from turning every profile read into an
    HTTP 500 error.
    """
    return (
        db.execute(
            select(Goal)
            .where(Goal.user_id == user_id, Goal.status == "active")
            .order_by(Goal.created_at.desc())
        )
        .scalars()
        .first()
    )


def owned_program(db: Session, user_id: str, program_id: str) -> Program | None:
    return db.execute(
        select(Program)
        .options(program_load_options())
        .where(Program.id == program_id, Program.user_id == user_id)
        .execution_options(populate_existing=True)
    ).scalar_one_or_none()


def owned_program_day(db: Session, user_id: str, day_id: str) -> ProgramDay | None:
    return db.execute(
        select(ProgramDay)
        .join(Program, Program.id == ProgramDay.program_id)
        .where(ProgramDay.id == day_id, Program.user_id == user_id)
    ).scalar_one_or_none()
