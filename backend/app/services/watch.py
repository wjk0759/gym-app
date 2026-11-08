from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import ExerciseMediaAsset, Profile, ProgramDay

_SEX_FALLBACK = {"male": 2, "female": 2, "unisex": 1}


def media_for_day(db: Session, user_id: str, day: ProgramDay) -> list[dict]:
    """Resolve the best published derivative per exercise for a plan day."""
    return media_for_slugs(
        db,
        user_id,
        [item.exercise_slug for item in day.exercises],
    )


def media_for_slugs(db: Session, user_id: str, slugs: list[str]) -> list[dict]:
    """Resolve the best published derivative per exercise.

    Exact sex wins, then unisex, then the other sex as a last visual fallback.
    The client always has a poster/text fallback if a clip is missing.
    """
    profile = db.get(Profile, user_id)
    preferred = (profile.sex if profile else None) or "unisex"
    slugs = list(dict.fromkeys(item for item in slugs if item))[:20]
    if not slugs:
        return []

    rows = (
        db.execute(
            select(ExerciseMediaAsset)
            .where(
                ExerciseMediaAsset.exercise_slug.in_(slugs),
                ExerciseMediaAsset.status == "published",
            )
            .order_by(
                ExerciseMediaAsset.exercise_slug,
                ExerciseMediaAsset.version.desc(),
            )
        )
        .scalars()
        .all()
    )

    chosen: dict[str, ExerciseMediaAsset] = {}
    for row in rows:
        current = chosen.get(row.exercise_slug)
        if current is None or _rank(row.sex, preferred) < _rank(
            current.sex,
            preferred,
        ):
            chosen[row.exercise_slug] = row

    return [
        {
            "exercise_slug": row.exercise_slug,
            "sex": row.sex,
            "watch_url": row.watch_url,
            "phone_url": row.phone_url,
            "poster_url": row.poster_url,
            "duration_seconds": row.duration_seconds,
            "loop_start_ms": row.loop_start_ms,
            "loop_end_ms": row.loop_end_ms,
            "sha256": row.watch_sha256,
            "version": row.version,
        }
        for row in chosen.values()
    ]


def _rank(sex: str, preferred: str) -> int:
    if sex == preferred:
        return 0
    return _SEX_FALLBACK.get(sex, 3)
