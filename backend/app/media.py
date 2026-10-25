from __future__ import annotations

from pathlib import Path

from .config import settings

MEDIA_ROOT = Path(settings.media_root).resolve()
VIDEO_DIR = MEDIA_ROOT / "videos"
POSTER_DIR = MEDIA_ROOT / "posters"


def ensure_media_dirs() -> None:
    VIDEO_DIR.mkdir(parents=True, exist_ok=True)
    POSTER_DIR.mkdir(parents=True, exist_ok=True)


def media_url(path: Path) -> str:
    relative = path.resolve().relative_to(MEDIA_ROOT)
    return "/media/" + relative.as_posix()


def remove_media_url(url: str | None) -> None:
    if not url or not url.startswith("/media/"):
        return
    candidate = (MEDIA_ROOT / url.removeprefix("/media/")).resolve()
    if MEDIA_ROOT not in candidate.parents:
        return
    try:
        candidate.unlink(missing_ok=True)
    except OSError:
        pass
