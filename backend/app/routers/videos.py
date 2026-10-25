from __future__ import annotations

from fastapi import APIRouter, Request
from sqlalchemy import select

from ..deps import DBSession
from ..models import Exercise, ExerciseVideo

router = APIRouter(tags=["videos"])


def _absolute_url(request: Request, url: str | None) -> str | None:
    if not url or not url.startswith("/"):
        return url
    return str(request.base_url).rstrip("/") + url


@router.get("/videos/{exercise_slug}")
def exercise_video(exercise_slug: str, request: Request, db: DBSession):
    exercise = db.get(Exercise, exercise_slug)
    video = (
        db.execute(
            select(ExerciseVideo)
            .where(
                ExerciseVideo.exercise_slug == exercise_slug,
                ExerciseVideo.status == "published",
            )
            .order_by(ExerciseVideo.updated_at.desc())
        )
        .scalars()
        .first()
    )
    if video:
        return {
            "exercise_slug": exercise_slug,
            "exercise_name": exercise.name_zh if exercise else None,
            "video": {
                "id": video.id,
                "title": video.title,
                "description": video.description,
                "video_url": _absolute_url(request, video.video_url),
                "poster_url": _absolute_url(request, video.poster_url),
                "duration_seconds": video.duration_seconds,
                "source": video.source,
                "license_note": video.license_note,
                "version": video.version,
                "updated_at": video.updated_at.isoformat(),
            },
        }

    if exercise and exercise.video_url:
        return {
            "exercise_slug": exercise_slug,
            "exercise_name": exercise.name_zh,
            "video": {
                "id": None,
                "title": exercise.name_zh,
                "description": exercise.instructions,
                "video_url": _absolute_url(request, exercise.video_url),
                "poster_url": _absolute_url(request, exercise.thumbnail_url),
                "duration_seconds": None,
                "source": exercise.source,
                "license_note": exercise.license,
                "version": 0,
                "updated_at": exercise.created_at.isoformat(),
            },
        }

    return {
        "exercise_slug": exercise_slug,
        "exercise_name": exercise.name_zh if exercise else None,
        "video": None,
    }
