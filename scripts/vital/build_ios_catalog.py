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
DST = ROOT / "ios" / "FitAI" / "Resources" / "vital_exercises.json"

# 计划白名单（常用动作）排除规则：器械/肌群/来源包/动作名四类。
# 其余动作仍可搜索、可看详情，但不进 AI 计划池。
PLAN_EXCLUDE_EQUIPMENT = {"other"}
PLAN_EXCLUDE_MUSCLE = {"cardio"}
PLAN_EXCLUDE_PACKS = {"yoga", "wallpilates", "homepilates"}
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


def is_plan_eligible(a: dict) -> bool:
    if a.get("equipment") in PLAN_EXCLUDE_EQUIPMENT:
        return False
    if a.get("muscle_group") in PLAN_EXCLUDE_MUSCLE:
        return False
    packs = {md.get("pack") for md in a.get("media", [])}
    if packs & PLAN_EXCLUDE_PACKS:
        return False
    name = a.get("name_zh") or ""
    return not any(k in name for k in NON_PLAN_KEYWORDS)


def main() -> None:
    actions = json.loads(SRC.read_text(encoding="utf-8"))
    rows = []
    eligible = 0
    for a in actions:
        plan_ok = is_plan_eligible(a)
        eligible += 1 if plan_ok else 0
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
