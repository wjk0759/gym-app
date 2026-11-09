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


def media_for_slugs(
    db: Session,
    user_id: str,
    slugs: list[str],
    all_variants: bool = False,
) -> list[dict]:
    """Resolve published media derivatives for a list of exercises.

    One exercise can now have several demo videos (different models / visual
    styles). The client always has a poster/text fallback if a clip is missing.

    * ``all_variants=False`` (Watch): one primary per exercise — lowest
      ``visual_priority``, then exact sex, unisex, other sex, latest version.
    * ``all_variants=True`` (phone): every published variant, sorted by
      ``visual_priority``, with ``is_primary_for_watch`` marking the first.
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
                ExerciseMediaAsset.visual_priority,
                ExerciseMediaAsset.version.desc(),
            )
        )
        .scalars()
        .all()
    )

    grouped: dict[str, list[ExerciseMediaAsset]] = {}
    for row in rows:
        grouped.setdefault(row.exercise_slug, []).append(row)

    def sort_key(row: ExerciseMediaAsset):
        return (
            row.visual_priority if row.visual_priority is not None else 99,
            _rank(row.sex, preferred),
            -(row.version or 1),
        )

    for group in grouped.values():
        group.sort(key=sort_key)

    result: list[dict] = []
    for slug in slugs:
        group = grouped.get(slug, [])
        if not group:
            continue
        items = group if all_variants else [group[0]]
        for index, row in enumerate(items):
            result.append(
                {
                    "media_id": row.id,
                    "exercise_slug": row.exercise_slug,
                    "sex": row.sex,
                    "variant_key": row.variant_key,
                    "source_pack": row.source_pack,
                    "visual_style": row.visual_style,
                    "visual_priority": row.visual_priority,
                    "is_primary_for_watch": index == 0,
                    "watch_url": row.watch_url,
                    "phone_url": row.phone_url,
                    "poster_url": row.poster_url,
                    "duration_seconds": row.duration_seconds,
                    "loop_start_ms": row.loop_start_ms,
                    "loop_end_ms": row.loop_end_ms,
                    "sha256": row.watch_sha256,
                    "version": row.version,
                }
            )
    return result


def _rank(sex: str, preferred: str) -> int:
    if sex == preferred:
        return 0
    return _SEX_FALLBACK.get(sex, 3)
