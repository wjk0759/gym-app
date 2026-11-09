#!/usr/bin/env python3
"""Classify Vital actions into the two-level category taxonomy (v2).

Rule-based on source ``target`` / ``secondary_muscles`` / ``category`` plus
name overrides for the cases where the source target is coarse or wrong
(face pull, deadlift, planks). Ambiguous rows keep low confidence and
``needs_review=1``.
"""

from __future__ import annotations

import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "data" / "vital" / "vital_actions_v2.json"
OUT = ROOT / "data" / "vital" / "category_classification.csv"
PILOT = ROOT / "data" / "vital" / "category_pilot.csv"

TAXONOMY = {
    "胸": ["上胸", "中下胸"],
    "背": ["背阔肌", "大圆肌", "菱形肌", "中下斜方", "上斜方", "竖脊肌"],
    "腿": ["股四头", "腘绳肌"],
    "肩": ["前束", "中束", "后束"],
    "前锯肌": [],
    "斜方肌": [],
    "手臂": ["二头", "三头"],
    "小腿": [],
    "前臂": [],
    "臀部": ["上臀", "下臀"],
    "功能性": ["髋", "膝关节", "肩关节"],
    "核心": [],
    "腹部": ["腹直肌", "侧腹"],
    "热身动作": ["胸", "上背", "下背", "腘绳肌", "大腿", "臀部", "肩膀"],
    "拉伸": ["胸", "上背", "下背", "腘绳肌", "大腿", "臀部", "肩膀"],
    "有氧": [],
    "全身": [],
    "other": [],
}


def _has(name: str, *keys: str) -> bool:
    return any(k in name for k in keys)


def region_l2(target: str, name: str, secondary: list[str]) -> str | None:
    t = target
    if "pectoral" in t or "chest" in t:
        return "胸"
    if "hamstring" in t:
        return "腘绳肌"
    if "quad" in t:
        return "大腿"
    if "glute" in t:
        return "臀部"
    if "deltoid" in t or "shoulder" in t:
        return "肩膀"
    if "lower back" in t or "erector" in t:
        return "下背"
    if "trap" in t or "rhomboid" in t:
        return "上背"
    joined = " ".join([target] + secondary)
    if "shoulder" in joined or "deltoid" in joined:
        return "肩膀"
    if "hamstring" in joined:
        return "腘绳肌"
    if "quad" in joined:
        return "大腿"
    if "glute" in joined:
        return "臀部"
    if "lower back" in joined or "erector" in joined:
        return "下背"
    if "trap" in joined or "rhomboid" in joined:
        return "上背"
    if "pectoral" in joined or "chest" in joined:
        return "胸"
    if _has(name, "胸"):
        return "胸"
    if _has(name, "肩"):
        return "肩膀"
    if _has(name, "臀"):
        return "臀部"
    if _has(name, "腘绳"):
        return "腘绳肌"
    if _has(name, "大腿", "股四"):
        return "大腿"
    if _has(name, "下背", "腰"):
        return "下背"
    if _has(name, "上背"):
        return "上背"
    return None


def classify(a: dict) -> tuple[str, str | None, float, str]:
    name = a.get("name_zh") or ""
    en = (a.get("name_en") or "").lower()
    target = (a.get("target") or "").strip().lower()
    secondary = [str(s).strip().lower() for s in (a.get("secondary_muscles") or [])]
    cat = (a.get("category") or "").strip().lower()

    # --- 类型分类 ---
    if cat == "stretching":
        l2 = region_l2(target, name, secondary)
        return "拉伸", l2, 0.8 if l2 else 0.55, "category=stretching"
    if _has(name, "热身"):
        l2 = region_l2(target, name, secondary)
        return "热身动作", l2, 0.8 if l2 else 0.55, "name=热身"
    # 全身复合（须在 cardio 之前）
    if _has(name, "波比", "立卧", "土耳其", "抓举", "挺举", "高翻", "火箭推", "农夫", "熊抱", "搬", "man maker", "clean"):
        return "全身", None, 0.85, "name=全身复合"
    if cat == "cardio" or target in ("cardiovascular system", "cardio"):
        return "有氧", None, 0.95, "category=cardio"
    if cat == "plyometrics" and _has(name, "波比", "立卧", "开合"):
        return "全身", None, 0.8, "plyometrics+全身"
    if cat in ("mobility", "balance"):
        if _has(name, "腕"):
            return "前臂", None, 0.6, "mobility+腕"
        if _has(name, "踝"):
            return "小腿", None, 0.6, "mobility+踝"
        if _has(name, "肩") or "shoulder" in en:
            return "功能性", "肩关节", 0.75, f"category={cat}"
        if _has(name, "膝") or "knee" in en:
            return "功能性", "膝关节", 0.75, f"category={cat}"
        return "功能性", "髋", 0.7, f"category={cat}"
    if cat == "rehabilitation":
        if _has(name, "拉伸") or "stretch" in en:
            return "拉伸", region_l2(target, name, secondary), 0.55, "rehab+拉伸"
        return "功能性", None, 0.55, "category=rehabilitation"

    # --- 名称覆盖（源 target 粗/错） ---
    if _has(name, "前锯肌", "肩胛", "祈祷推"):
        return "前锯肌", None, 0.85, "name=前锯肌"
    if _has(name, "面拉", "face pull"):
        return "肩", "后束", 0.9, "name=面拉"
    if _has(name, "山羊挺身", "背屈伸", "back extension", "hyperextension"):
        return "背", "竖脊肌", 0.85, "name=山羊挺身"
    if "硬拉" in name:
        if _has(name, "罗马尼亚", "直腿"):
            return "腿", "腘绳肌", 0.75, "name=罗马尼亚硬拉"
        return "背", "竖脊肌", 0.7, "name=硬拉"
    if any(k in name for k in ("平板支撑", "侧平板", "反向平板", "肘撑平板", "L坐支撑", "坐姿支撑", "靠墙支撑")):
        return "核心", None, 0.85, "name=支撑"

    # --- 肌肉分类 ---
    if target in ("pectorals", "chest", "lower chest"):
        return "胸", "上胸" if "上斜" in name else "中下胸", 0.9, f"target={target}"
    if target == "lats":
        return "背", "背阔肌", 0.95, "target=lats"
    if target == "rhomboids":
        return "背", "菱形肌", 0.95, "target=rhomboids"
    if target == "teres major":
        return "背", "大圆肌", 0.9, "target=teres major"
    if target == "traps":
        if _has(name, "耸肩", "直立划船", "斜方"):
            return "斜方肌", None, 0.9, "target=traps+耸肩"
        if _has(name, "中下", "下斜"):
            return "背", "中下斜方", 0.7, "target=traps+中下"
        return "背", "上斜方", 0.7, "target=traps+上斜"
    if target == "lower back":
        return "背", "竖脊肌", 0.9, "target=lower back"
    if target in ("upper back", "back"):
        return "背", "菱形肌" if "菱形" in name else "背阔肌", 0.75, f"target={target}"

    if target == "quads":
        return "腿", "股四头", 0.95, "target=quads"
    if target == "hamstrings":
        return "腿", "腘绳肌", 0.95, "target=hamstrings"
    if target == "upper legs":
        if _has(name, "腿弯举", "腘绳", "硬拉"):
            return "腿", "腘绳肌", 0.8, "target=upper legs+腘绳"
        if _has(name, "腿屈伸", "深蹲", "腿举", "弓步", "箭步"):
            return "腿", "股四头", 0.8, "target=upper legs+股四"
        return "腿", None, 0.6, "target=upper legs"
    if target == "lower legs":
        return "小腿", None, 0.85, "target=lower legs"
    if target in ("adductors", "inner thighs", "hip adductors"):
        return "腿", None, 0.55, "target=adductors"
    if target in ("hip abductors", "abductors"):
        return "臀部", "上臀", 0.85, "target=abductors"
    if target == "glutes":
        l2 = "上臀" if _has(name, "外展", "侧抬", "蚌式", "臀中", "侧卧") else "下臀"
        return "臀部", l2, 0.85, "target=glutes"

    if target in ("delts", "lateral delts", "deltoids", "shoulders"):
        if _has(name, "前平举", "前束", "推举", "肩推", "推肩", "军推"):
            return "肩", "前束", 0.8, "target=delts+前"
        if _has(name, "侧平举", "中束", "侧举", "平举"):
            return "肩", "中束", 0.8, "target=delts+侧"
        if _has(name, "后束", "后飞", "反向飞鸟", "后平举"):
            return "肩", "后束", 0.8, "target=delts+后"
        return "肩", "前束", 0.6, "target=delts默认"

    if target == "biceps":
        return "手臂", "二头", 0.95, "target=biceps"
    if target == "triceps":
        return "手臂", "三头", 0.95, "target=triceps"
    if target == "upper arms":
        if _has(name, "弯举"):
            return "手臂", "二头", 0.75, "target=upper arms+弯举"
        return "手臂", "三头", 0.7, "target=upper arms"
    if target in ("forearms", "lower arms"):
        return "前臂", None, 0.9, "target=forearms"
    if target == "calves":
        return "小腿", None, 0.95, "target=calves"

    if target == "abs":
        if _has(name, "平板", "支撑", "死虫", "鸟狗", "空心", "抗旋"):
            return "核心", None, 0.85, "target=abs+稳定"
        return "腹部", "腹直肌", 0.9, "target=abs"
    if target == "obliques":
        return "腹部", "侧腹", 0.9, "target=obliques"
    if target == "waist":
        if _has(name, "平板", "支撑", "侧"):
            return "核心", None, 0.7, "target=waist+稳定"
        return "腹部", "腹直肌", 0.7, "target=waist"
    if target == "hip flexors":
        return "核心", None, 0.55, "target=hip flexors"
    if target == "neck":
        return "other", None, 0.6, "target=neck"
    if target == "serratus anterior":
        return "前锯肌", None, 0.9, "target=serratus"

    return "other", None, 0.5, "未匹配"


def main() -> None:
    actions = json.loads(SRC.read_text(encoding="utf-8"))
    rows = []
    for a in actions:
        l1, l2, conf, reason = classify(a)
        rows.append({
            "slug": a["slug"], "name_zh": a["name_zh"],
            "name_en": a.get("name_en") or "", "target": a.get("target") or "",
            "secondary": "/".join(a.get("secondary_muscles") or []),
            "category": a.get("category") or "", "l1": l1, "l2": l2 or "",
            "confidence": conf, "reason": reason,
            "needs_review": 1 if conf < 0.8 else 0,
        })

    fields = ["slug", "name_zh", "name_en", "target", "secondary", "category",
              "l1", "l2", "confidence", "reason", "needs_review"]
    with OUT.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)

    tricky = [
        "vital-barbell-bench-press-flat", "vital-incline-dumbbell-bench-press",
        "vital-dips", "vital-pull-up", "vital-barbell-row", "vital-cable-face-pull",
        "vital-barbell-deadlift", "vital-barbell-romanian-deadlift",
        "vital-barbell-hip-thrust", "vital-cable-hip-abduction", "vital-barbell-shrug",
        "vital-dumbbell-lateral-raise", "vital-dumbbell-biceps-curl", "vital-triceps-pushdown",
        "vital-plank", "vital-crunch", "vital-hanging-knee-raise", "vital-burpee",
        "vital-treadmill-run", "vital-donkey-kick", "vital-standing-hamstring-stretch",
        "vital-push-up", "vital-reverse-plank", "vital-landmine-sissy-squat",
        "vital-side-plank", "vital-ab-wheel-rollout", "vital-kettlebell-swing",
        "vital-front-squat", "vital-copenhagen-plank", "vital-lying-leg-curl-machine",
        "vital-roman-deadlift", "vital-hex-bar-deadlift",
    ]
    by_slug = {r["slug"]: r for r in rows}
    pilot_slugs = [s for s in tricky if s in by_slug]
    seen = set(pilot_slugs)
    for l1 in TAXONOMY:
        for r in rows:
            if r["l1"] == l1 and r["slug"] not in seen:
                pilot_slugs.append(r["slug"])
                seen.add(r["slug"])
                break
    pilot = [by_slug[s] for s in pilot_slugs]

    with PILOT.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(pilot)

    from collections import Counter
    print("total", len(rows), "needs_review", sum(r["needs_review"] for r in rows))
    print("L1", dict(Counter(r["l1"] for r in rows)))
    print("pilot", len(pilot), "wrote", OUT.name, PILOT.name)


if __name__ == "__main__":
    main()
