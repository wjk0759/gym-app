#!/usr/bin/env python3
"""Build taxonomy v1 for the Vital exercise catalog.

Reads data/vital/vital_actions_v2.json (merged/renamed catalog) and derives the
orthogonal classification dimensions:

  training_type   力量 / 拉伸 / 有氧 / 瑜伽 / 普拉提 / 灵活性
  body_part       胸 / 背 / 肩 / 臂 / 腿 / 臀 / 核心 / 全身
  muscle_primary  Chinese primary muscle (from source ``target``)
  muscle_secondary Chinese secondary muscles
  movement_pattern 推 / 拉 / 蹲 / 髋铰链 / 弓步 / 旋转 / 提携 / 孤立 / 等长
  difficulty / is_compound  passthrough

Rules (locked):
  - pack override: yoga pack -> 瑜伽; homepilates/wallpilates -> 普拉提
  - otherwise category -> training_type
  - body_part from source ``target`` (0 unmapped)

Outputs:
  data/vital/taxonomy_v1.json    per-exercise classification + taxonomy defs
  data/vital/taxonomy_review.csv review queue (edge cases / conflicts)
"""

from __future__ import annotations

import csv
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "data" / "vital" / "vital_actions_v2.json"
OUT = ROOT / "data" / "vital" / "taxonomy_v1.json"
REVIEW = ROOT / "data" / "vital" / "taxonomy_review.csv"

TRAINING_TYPES = ["力量", "拉伸", "有氧", "瑜伽", "普拉提", "灵活性"]
BODY_PARTS = ["胸", "背", "肩", "臂", "腿", "臀", "核心", "全身"]
MOVEMENT_PATTERNS = ["推", "拉", "蹲", "髋铰链", "弓步", "旋转", "提携", "孤立", "等长"]

# pack -> training_type (pack wins over category)
PACK_TRAINING = {
    "yoga": "瑜伽",
    "homepilates": "普拉提",
    "wallpilates": "普拉提",
}

# category -> training_type (fallback)
CATEGORY_TRAINING = {
    "strength": "力量",
    "plyometrics": "力量",
    "cardio": "有氧",
    "stretching": "拉伸",
    "rehabilitation": "拉伸",
    "mobility": "灵活性",
    "balance": "灵活性",
}

# target -> body_part (8). Covers every value seen in the catalog.
TARGET_BODY_PART = {
    # 臀
    "glutes": "臀", "hip abductors": "臀",
    # 核心
    "abs": "核心", "obliques": "核心", "lower back": "核心", "core": "核心", "waist": "核心",
    # 腿
    "quads": "腿", "hamstrings": "腿", "calves": "腿", "soleus": "腿",
    "adductors": "腿", "inner thighs": "腿", "hip adductors": "腿", "abductors": "腿",
    "hip flexors": "腿", "tensor fasciae latae": "腿", "upper legs": "腿",
    "lower legs": "腿", "ankle stabilizers": "腿",
    # 肩
    "delts": "肩", "lateral delts": "肩", "front delts": "肩", "rear delts": "肩",
    "deltoids": "肩", "shoulders": "肩", "rotator cuff": "肩", "supraspinatus": "肩",
    "neck": "肩",
    # 臂
    "triceps": "臂", "biceps": "臂", "forearms": "臂", "brachialis": "臂",
    "brachioradialis": "臂", "upper arms": "臂", "lower arms": "臂",
    # 胸
    "pectorals": "胸", "chest": "胸", "lower chest": "胸", "upper chest": "胸",
    # 背
    "lats": "背", "upper back": "背", "rhomboids": "背", "back": "背",
    "teres major": "背", "traps": "背", "upper traps": "背",
    # 全身
    "cardiovascular system": "全身", "cardio": "全身",
}

MUSCLE_ZH = {
    "abs": "腹直肌", "obliques": "侧腹", "lower back": "下背", "core": "核心", "waist": "腰腹",
    "quads": "股四头", "hamstrings": "腘绳肌", "calves": "小腿", "soleus": "比目鱼肌",
    "adductors": "内收肌", "inner thighs": "大腿内侧", "hip adductors": "髋内收",
    "hip abductors": "髋外展", "abductors": "外展肌", "hip flexors": "髋屈肌",
    "glutes": "臀大肌", "tensor fasciae latae": "阔筋膜张肌",
    "delts": "三角肌", "lateral delts": "中束", "front delts": "前束", "rear delts": "后束",
    "deltoids": "三角肌", "shoulders": "肩", "rotator cuff": "肩袖", "supraspinatus": "冈上肌",
    "traps": "斜方肌", "upper traps": "上斜方", "neck": "颈",
    "lats": "背阔肌", "upper back": "上背", "rhomboids": "菱形肌", "back": "背", "teres major": "大圆肌",
    "pectorals": "胸大肌", "chest": "胸", "lower chest": "下胸", "upper chest": "上胸",
    "triceps": "三头", "biceps": "二头", "forearms": "前臂", "brachialis": "肱肌",
    "brachioradialis": "肱桡肌",
    "upper legs": "大腿", "lower legs": "小腿", "upper arms": "上臂", "lower arms": "前臂",
    "cardiovascular system": "心肺", "cardio": "心肺", "ankle stabilizers": "踝稳定肌",
}

# movement pattern keyword rules, applied on slug + name_en + name_zh (priority order).
# Strength-oriented; non-strength (yoga/stretch/cardio/pilates) mostly stays None and
# is sub-classified by its own L2 (pose type / mat-equipment / etc).
MOVEMENT_RULES = [
    ("提携", ["carry", "农夫", "行走", "提携", "搬运", "crawl", "熊爬", "march", "行军"]),
    ("旋转", ["rotation", "twist", "旋转", "转体", "torso", "windmill", "风车"]),
    ("弓步", ["lunge", "弓步", "箭步", "split squat", "分腿"]),
    ("髋铰链", ["deadlift", "硬拉", "good morning", "早安", "hinge", "romanian",
                "stiff", "rdl", "swing", "hip thrust", "臀推", "glute bridge", "bridge"]),
    ("蹲", ["squat", "蹲", "pistol", "leg press", "腿举", "hack squat"]),
    ("推", ["press", "推", "push", "bench", "dip", "卧推", "俯卧撑", "punch",
            "出拳", "boxing", "拳击", "jab"]),
    ("拉", ["pull", "row", "划船", "下拉", "引体", "pulldown", "chin", "面拉"]),
    ("等长", ["hold", "保持", "plank", "支撑", "static", "wall sit", "l-sit",
              "hollow", "静力", "isometric", "bird dog", "鸟狗"]),
    ("孤立", ["curl", "extension", "raise", "fly", "crunch", "shrug", "弯举",
              "屈伸", "侧平举", "卷腹", "提踵", "kickback", "后踢", "skull",
              "碎颅", "superman", "超人", "ytw", "y-t-w", "sit-up", "sit up",
              "仰卧起坐"]),
]


def packs(action: dict) -> set[str]:
    return {str(m.get("pack")) for m in (action.get("media") or [])}


def training_type(action: dict) -> tuple[str, str | None]:
    ps = packs(action)
    if "yoga" in ps:
        # Pure yoga pack -> 瑜伽. A yoga video alongside a strength-style pack
        # (100/200/430*/women400/home130) is ambiguous, flag for review.
        if len(ps) > 1:
            return "瑜伽", "mixed_yoga_pack"
        return "瑜伽", None
    if ps & {"homepilates", "wallpilates"}:
        return "普拉提", None
    cat = action.get("category") or ""
    return CATEGORY_TRAINING.get(cat, "未定"), (None if cat in CATEGORY_TRAINING else f"unknown_category={cat}")


def body_part(action: dict) -> tuple[str, str | None]:
    target = action.get("target") or ""
    bp = TARGET_BODY_PART.get(target)
    reason = None
    if target in ("neck", "traps", "upper traps", "lower back"):
        reason = f"edge_target={target}"
    if bp is None:
        reason = (reason or "") + f" unmapped_target={target}"
        bp = "未定"
    return bp, reason


def muscle_zh(value: str) -> str:
    return MUSCLE_ZH.get(value, value)


def movement_pattern(action: dict) -> str | None:
    text = " ".join([
        action.get("slug", ""),
        action.get("name_en") or "",
        action.get("name_zh") or "",
    ]).lower()
    for pattern, kws in MOVEMENT_RULES:
        if any(kw in text for kw in kws):
            return pattern
    return None


def main() -> None:
    actions = json.loads(SRC.read_text(encoding="utf-8"))

    tt_counter: Counter = Counter()
    bp_counter: Counter = Counter()
    review_rows: list[dict] = []
    out_exercises: list[dict] = []
    mp_missing = 0

    for a in actions:
        tt, tt_reason = training_type(a)
        bp, bp_reason = body_part(a)
        mp = movement_pattern(a)
        if mp is None:
            mp_missing += 1

        primary = muscle_zh(a.get("target") or "")
        secondary = [muscle_zh(x) for x in (a.get("secondary_muscles") or [])]

        # Review = true edge cases only, not "movement pattern missing".
        reasons = [r for r in (tt_reason, bp_reason) if r]
        review = " | ".join(reasons) or None

        tt_counter[tt] += 1
        bp_counter[bp] += 1

        rec = {
            "slug": a["slug"],
            "name_zh": a.get("name_zh"),
            "training_type": tt,
            "body_part": bp,
            "muscle_primary": primary,
            "muscle_secondary": secondary,
            "movement_pattern": mp,
            "difficulty": a.get("difficulty"),
            "is_compound": a.get("is_compound"),
            "review": review,
        }
        out_exercises.append(rec)

        if review:
            review_rows.append({
                "slug": a["slug"],
                "name_zh": a.get("name_zh") or "",
                "training_type": tt,
                "body_part": bp,
                "muscle_primary": primary,
                "movement_pattern": mp or "",
                "pack": ",".join(sorted(packs(a))),
                "category": a.get("category") or "",
                "target": a.get("target") or "",
                "reason": review,
            })

    taxonomy = {
        "version": "v1",
        "training_types": TRAINING_TYPES,
        "body_parts": BODY_PARTS,
        "movement_patterns": MOVEMENT_PATTERNS,
        "muscle_map": MUSCLE_ZH,
        "exercises": out_exercises,
    }
    OUT.write_text(json.dumps(taxonomy, ensure_ascii=False, indent=1), encoding="utf-8")

    with REVIEW.open("w", encoding="utf-8-sig", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(review_rows[0].keys()) if review_rows else
                                ["slug", "name_zh", "training_type", "body_part", "muscle_primary",
                                 "movement_pattern", "pack", "category", "target", "reason"])
        writer.writeheader()
        writer.writerows(review_rows)

    print("actions", len(actions))
    print("training_type:", dict(tt_counter.most_common()))
    print("body_part:", dict(bp_counter.most_common()))
    print("movement_pattern missing:", mp_missing, "/", len(actions))
    print("review rows:", len(review_rows))
    print("wrote", OUT.name, "and", REVIEW.name)


if __name__ == "__main__":
    main()
