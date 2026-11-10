#!/usr/bin/env python3
"""Build the iOS-bundled Vital exercise catalog.

Reads the merged/renamed catalog (data/vital/vital_actions_v2.json) and emits
ios/FitAI/Resources/vital_exercises.json in the exact shape the iOS
``ResourceExercise`` decoder expects, plus ``aliases`` / ``slug_aliases``.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "data" / "vital" / "vital_actions_v2.json"
TAXONOMY = ROOT / "data" / "vital" / "taxonomy_v1.json"
EMAP = ROOT / "data" / "vital" / "equipment_exercise_map.json"
DST = ROOT / "ios" / "FitAI" / "Resources" / "vital_exercises.json"

# 计划白名单：只允许「力量」训练类型，再排除居家变式/颈部等不适合进通用计划的动作。
HOME_VARIANT_KEYWORDS = (
    "水瓶", "持瓶", "毛巾", "椅上", "椅子", "凳上", "卧凳", "桌", "颈部", "颈推",
)


def is_plan_eligible(a: dict, training_type: str) -> bool:
    if training_type != "力量":
        return False
    name = a.get("name_zh") or ""
    return not any(k in name for k in HOME_VARIANT_KEYWORDS)


def variant_key_for(md: dict) -> str:
    vid = str(md.get("video_id") or "").strip()
    stem = Path(md.get("source_file", "")).stem
    return f"{md.get('pack', '')}-{vid or stem}"


def media_urls(a: dict) -> tuple[str | None, str | None]:
    """主变体的 poster / phone 视频相对路径（无媒体时返回 None）。"""
    media = a.get("media") or []
    if not media:
        return None, None
    primary = next((m for m in media if m.get("primary_for_watch")), media[0])
    key = variant_key_for(primary)
    base = f"/media/exercises/vital/{a['slug']}/{key}/v1"
    return f"{base}/poster.jpg", f"{base}/iphone.mp4"


def variant_media(a: dict) -> list[dict]:
    """全部变体的 poster / phone 视频，按视觉优先级排序。"""
    media = a.get("media") or []
    ordered = sorted(
        media,
        key=lambda m: (m.get("visual_priority") or 99, m.get("source_file") or ""),
    )
    result = []
    for m in ordered:
        key = variant_key_for(m)
        base = f"/media/exercises/vital/{a['slug']}/{key}/v1"
        result.append(
            {
                "poster_url": f"{base}/poster.jpg",
                "video_url": f"{base}/iphone.mp4",
                "visual_style": m.get("visual_style"),
                "visual_priority": m.get("visual_priority"),
            }
        )
    return result


def main() -> None:
    actions = json.loads(SRC.read_text(encoding="utf-8"))
    tax = json.loads(TAXONOMY.read_text(encoding="utf-8"))
    tax_by = {e["slug"]: e for e in tax["exercises"]}
    emap = json.loads(EMAP.read_text(encoding="utf-8"))["mapping"]
    eq_by: dict[str, list[str]] = {}
    for group, slugs in emap.items():
        for s in slugs:
            eq_by.setdefault(s, []).append(group)

    rows = []
    eligible = 0
    for a in actions:
        t = tax_by.get(a["slug"], {})
        training_type = t.get("training_type") or "力量"
        body_part = t.get("body_part")
        muscle_primary = t.get("muscle_primary")
        plan_ok = is_plan_eligible(a, training_type)
        eligible += 1 if plan_ok else 0
        thumbnail_url, video_url = media_urls(a)
        steps = a.get("instructions_zh") or []
        instructions = "\n".join(str(s) for s in steps) if steps else None
        rows.append(
            {
                "slug": a["slug"],
                "name_zh": a["name_zh"],
                "name_en": a.get("name_en") or None,
                "muscle_group": a.get("muscle_group") or "core",
                "equipment": a.get("equipment") or "other",
                "is_compound": bool(a.get("is_compound")),
                "difficulty": int(a.get("difficulty") or 1),
                "instructions": instructions,
                "contraindications": [],
                "aliases": sorted(a.get("aliases") or []),
                "slug_aliases": sorted(a.get("slug_aliases") or []),
                "plan_eligible": plan_ok,
                # 新分类维度
                "training_type": training_type,
                "body_part": body_part,
                "muscle_primary": muscle_primary,
                "muscle_secondary": t.get("muscle_secondary") or [],
                "movement_pattern": t.get("movement_pattern"),
                "equipment_types": sorted(eq_by.get(a["slug"], [])),
                # 桥接字段：现有两级侧栏直接复用部位/主肌群
                "category_l1": body_part,
                "category_l2": muscle_primary or None,
                "thumbnail_url": thumbnail_url,
                "video_url": video_url,
                "media": variant_media(a),
            }
        )
    rows.sort(key=lambda r: r["name_zh"])
    DST.write_text(
        json.dumps(rows, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    size = DST.stat().st_size
    print(f"actions={len(rows)} plan_eligible={eligible} bytes={size}")
    print(f"wrote {DST}")


if __name__ == "__main__":
    main()
