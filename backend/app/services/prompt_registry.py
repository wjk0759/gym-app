"""Stable prompt version labels for AI jobs, runs and feedback.

A version is derived from the exact prompt text instead of a manual counter, so
editing a prompt automatically creates a new label. Never pass user data here;
only the system prompt and fixed instruction blocks belong in the hash.
"""

from __future__ import annotations

import hashlib
import re
from functools import lru_cache

MAX_PROMPT_VERSION = 30


@lru_cache(maxsize=256)
def prompt_version(kind: str, *parts: str) -> str:
    """Return ``kind@<sha256-prefix>`` for a prompt and its fixed parts."""
    slug = re.sub(r"[^a-z0-9_]+", "_", kind.lower()).strip("_") or "prompt"
    digest = hashlib.sha256("\x00".join(parts).encode("utf-8")).hexdigest()[:8]
    return f"{slug}@{digest}"[:MAX_PROMPT_VERSION]
