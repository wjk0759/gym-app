#!/usr/bin/env python3
"""Validate the bundled Vital catalog and media manifest.

This is a data contract check, not a content review. It guarantees that every
exercise shipped in the iOS catalog is searchable, has exactly one Watch
primary media, and stays out of the default plan pool when it is mobility,
cardio, warm-up or the catch-all category.
"""

from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "ios" / "FitAI" / "Resources" / "vital_exercises.json"
MEDIA = ROOT / "data" / "vital" / "media_manifest.json"

NON_PLAN_CATEGORIES = {"拉伸", "有氧", "热身动作", "other"}


def fail(message: str) -> None:
    print(f"catalog validation: {message}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    exercises = json.loads(CATALOG.read_text(encoding="utf-8"))
    media = json.loads(MEDIA.read_text(encoding="utf-8"))

    if not exercises:
        fail("exercise catalog is empty")
    if not media:
        fail("media manifest is empty")

    slugs = [exercise["slug"] for exercise in exercises]
    if len(slugs) != len(set(slugs)):
        fail("exercise slugs are not unique")

    by_slug: dict[str, list[dict]] = defaultdict(list)
    for row in media:
        slug = row.get("slug")
        if not slug:
            fail("media row without a slug")
        by_slug[slug].append(row)

    catalog_slugs = set(slugs)
    media_slugs = set(by_slug)
    missing = sorted(catalog_slugs - media_slugs)
    orphaned = sorted(media_slugs - catalog_slugs)
    if missing:
        fail(f"{len(missing)} exercises have no media, first: {missing[:5]}")
    if orphaned:
        fail(f"{len(orphaned)} media slugs are not in the catalog, first: {orphaned[:5]}")

    for slug, rows in by_slug.items():
        variants = [row.get("variant_key") for row in rows]
        if len(variants) != len(set(variants)):
            fail(f"{slug} has duplicate variant keys")
        primaries = [
            row for row in rows if row.get("is_primary_for_watch") is True
        ]
        if len(primaries) != 1:
            fail(f"{slug} must have exactly one Watch primary, got {len(primaries)}")
        for row in rows:
            if not row.get("source_file"):
                fail(f"{slug}/{row.get('variant_key')} has no source file")
            if int(row.get("size_bytes") or 0) <= 0:
                fail(f"{slug}/{row.get('variant_key')} has no positive size")

    for exercise in exercises:
        category = exercise.get("category_l1")
        if exercise.get("plan_eligible") and category in NON_PLAN_CATEGORIES:
            fail(
                f"{exercise['slug']} is plan_eligible but belongs to {category}"
            )

    plan_count = sum(1 for exercise in exercises if exercise.get("plan_eligible"))
    print(
        "catalog validation: ok "
        f"exercises={len(exercises)} plan_eligible={plan_count} "
        f"media_rows={len(media)} media_slugs={len(media_slugs)} "
        f"primary={sum(1 for row in media if row.get('is_primary_for_watch'))}"
    )


if __name__ == "__main__":
    main()
