from __future__ import annotations

from pathlib import Path

from .config import settings

MEDIA_ROOT = Path(settings.media_root).resolve()
VIDEO_DIR = MEDIA_ROOT / "videos"
POSTER_DIR = MEDIA_ROOT / "posters"
AVATAR_DIR = MEDIA_ROOT / "avatars"


def ensure_media_dirs() -> None:
    VIDEO_DIR.mkdir(parents=True, exist_ok=True)
    POSTER_DIR.mkdir(parents=True, exist_ok=True)
    AVATAR_DIR.mkdir(parents=True, exist_ok=True)


def public_media_url(value: str | None) -> str | None:
    """Turn a stored media path into an absolute URL for API responses.

    The database keeps relative ``/media/...`` paths so the deployment can move
    between domains without rewriting rows. External OAuth avatars are already
    absolute and pass through unchanged.
    """
    if value is None:
        return None
    text = value.strip()
    if not text:
        return None
    if text.startswith(("http://", "https://")):
        return text
    if not text.startswith("/"):
        return text
    base = settings.public_base_url.rstrip("/")
    return f"{base}{text}" if base else text