"""Deterministic citations for coach replies.

Citations are derived from the reply text and the exercise knowledge base, not
from the model. The model can mention an exercise; the server decides whether a
real exercise record exists and attaches its source/license. This keeps source
attribution honest even when the model hallucinates a name.
"""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import Exercise, Program
from .exercise_search import load_exercises


def _citation(
    name_zh: str,
    *,
    name_en: str | None = None,
    slug: str | None = None,
    source: str | None = None,
    license_name: str | None = None,
) -> dict:
    item = {"type": "exercise", "name_zh": name_zh}
    if name_en:
        item["name_en"] = name_en
    if slug:
        item["slug"] = slug
    if source:
        item["source"] = source
    if license_name:
        item["license"] = license_name
    return item


def _plan_candidates(
    db: Session,
    program: Program | None,
) -> list[tuple[str, dict]]:
    if program is None:
        return []
    slugs = {
        item.exercise_slug
        for day in program.days
        for item in day.exercises
    }
    if not slugs:
        return []
    rows = (
        db.execute(select(Exercise).where(Exercise.slug.in_(slugs)))
        .scalars()
        .all()
    )
    return [
        (
            row.name_zh,
            _citation(
                row.name_zh,
                name_en=row.name_en,
                slug=row.slug,
                source="current_plan",
            ),
        )
        for row in rows
    ]


def _rag_candidates(db: Session, reply: str) -> list[tuple[str, dict]]:
    matches = [
        item
        for item in load_exercises()
        if item.get("name_zh") and str(item["name_zh"]) in reply
    ]
    if not matches:
        return []

    names = [str(item["name_zh"]) for item in matches]
    slugs = {
        row.name_zh: row.slug
        for row in db.execute(
            select(Exercise).where(Exercise.name_zh.in_(names))
        ).scalars()
    }
    return [
        (
            str(item["name_zh"]),
            _citation(
                str(item["name_zh"]),
                name_en=str(item.get("name_en") or "") or None,
                slug=slugs.get(str(item["name_zh"])),
                source=str(item.get("source") or "") or None,
                license_name=str(item.get("license") or "") or None,
            ),
        )
        for item in matches
    ]


def build_reply_citations(
    db: Session,
    reply: str,
    *,
    program: Program | None = None,
    limit: int = 4,
) -> list[dict]:
    """Return up to ``limit`` verified exercise citations mentioned in reply."""
    text = (reply or "").strip()
    if not text:
        return []

    candidates = _plan_candidates(db, program) + _rag_candidates(db, text)
    # Longer names first: "杠铃卧推" must win over "卧推" when both match.
    candidates.sort(key=lambda pair: len(pair[0]), reverse=True)

    citations: list[dict] = []
    seen: set[str] = set()
    for name, item in candidates:
        if name in seen:
            continue
        if any(name in existing["name_zh"] for existing in citations):
            continue
        seen.add(name)
        citations.append(item)
        if len(citations) >= max(1, min(8, int(limit))):
            break
    return citations
