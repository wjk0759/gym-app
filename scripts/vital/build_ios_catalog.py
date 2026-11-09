#!/usr/bin/env python3
"""Build the iOS-bundled Vital exercise catalog.

Reads the merged/renamed catalog (data/vital/vital_actions_v2.json) and emits
ios/FitAI/Resources/vital_exercises.json in the exact shape the iOS
``ResourceExercise`` decoder expects, plus ``aliases`` / ``slug_aliases``.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "data" / "vital" / "vital_actions_v2.json"
DST = ROOT / "ios" / "FitAI" / "Resources" / "vital_exercises.json"

sys.path.insert(0, str(Path(__file__).resolve().parent))
from classify_categories import classify  # noqa: E402

# 计划白名单（常用动作）排除规则：器械/肌群/来源包/动作名四类。
# 其余动作仍可搜索、可看详情，但不进 AI 计划池。
PLAN_EXCLUDE_EQUIPMENT = {"other"}
PLAN_EXCLUDE_MUSCLE = {"cardio"}
PLAN_EXCLUDE_PACKS = {"yoga", "wallpilates", "homepilates"}
# The default plan pool is strength-only. Mobility, cardio warm-ups and the
# catch-all "other" branch stay searchable, but must not be auto-selected;
# users can still add them explicitly through their equipment library.
PLAN_EXCLUDE_CATEGORIES = {"拉伸", "有氧", "热身动作", "other"}
NON_PLAN_KEYWORDS = (
    # 拉伸 / 康复 / 放松 / 呼吸 / 冥想 / 热身 / 舒展 / 按摩 / 矫正 / 活动度
    "拉伸", "放松", "呼吸", "冥想", "绕环", "热身", "舒展", "按摩", "康复", "矫正", "活动度",
    # 普拉提 / 瑜伽 / 平衡
    "普拉提", "瑜伽", "平衡",
    # 居家器械变式（水瓶 / 毛巾 / 椅子 / 凳 / 桌）
    "水瓶", "持瓶", "毛巾", "椅上", "椅子", "凳上", "卧凳", "桌",
    # 瑜伽体式名
    "猫式", "猫牛", "婴儿式", "祈祷", "轮式", "三角式", "战士", "山式", "下犬", "上犬",
    "船式", "鱼王", "眼镜蛇", "蝗虫", "鸽子", "骆驼", "侧板式",
    # 倒立 / 杂技 / 高级核心
    "倒立", "空心", "龙旗", "尺蠖", "毛毛虫",
    # 颈部
    "颈部", "颈推",
    # 骨盆 / 腹横肌（康复激活）
    "骨盆", "腹横肌",
    # 坐姿前屈 / 盘腿 / 跪坐 / 足弓 / 踝
    "体前屈", "前屈", "盘腿", "跪坐", "足弓", "踝",
    # 拳击 / 灵活性 / 摆动 / 环绕
    "拳击", "出拳", "绕肩", "摆臂", "墙天使", "手腕", "环绕", "肩绕",
    # 步法 / 敏捷 / 滑 / 慢速 / 低冲击
    "梯", "滑", "碎步", "踢臀", "敏捷", "慢速", "低冲击",
)


def is_plan_eligible(a: dict, category_l1: str | None) -> bool:
    if category_l1 in PLAN_EXCLUDE_CATEGORIES:
        return False
    if a.get("equipment") in PLAN_EXCLUDE_EQUIPMENT:
        return False
    if a.get("muscle_group") in PLAN_EXCLUDE_MUSCLE:
        return False
    packs = {md.get("pack") for md in a.get("media", [])}
    if packs & PLAN_EXCLUDE_PACKS:
        return False
    name = a.get("name_zh") or ""
    return not any(k in name for k in NON_PLAN_KEYWORDS)


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
    rows = []
    eligible = 0
    for a in actions:
        l1, l2, conf, _reason = classify(a)
        plan_ok = is_plan_eligible(a, l1)
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
                "category_l1": l1,
                "category_l2": l2 or None,
                "category_confidence": conf,
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
