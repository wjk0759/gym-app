from __future__ import annotations

from pathlib import Path

from .config import settings

MEDIA_ROOT = Path(settings.media_root).resolve()
VIDEO_DIR = MEDIA_ROOT / "videos"
POSTER_DIR = MEDIA_ROOT / "posters"


def ensure_media_dirs() -> None:
    VIDEO_DIR.mkdir(parents=True, exist_ok=True)
    POSTER_DIR.mkdir(parents=True, exist_ok=True)