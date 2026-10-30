"""Generate exercise Q&A cases for the RAG tool.

Run after `build_exercise_rag.py`; the cases assert that the coach actually
calls `lookup_exercise` and retrieves the expected exercise.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORPUS = ROOT / "data" / "exercises_rag.jsonl"
OUTPUT = Path(__file__).resolve().parent / "scenarios" / "exercise_120.jsonl"
PERSONAS = ["beginner", "intermediate", "rehab", "busy", "older"]
BODY_SYNONYMS = {
    "胸": ["胸", "胸大肌", "胸部"],
    "背": ["背", "背阔", "斜方"],
    "腿": ["腿", "股四头", "臀", "下肢"],
    "臀": ["臀", "臀大肌", "髋"],
    "肩": ["肩", "三角肌"],
    "手臂": ["手臂", "肱三头", "肱二头", "三头", "二头"],
    "前臂": ["前臂", "握力", "腕"],
    "核心": ["核心", "腹部", "腹肌", "侧板", "腰", "稳定"],
    "小腿": ["小腿", "腓肠", "比目鱼"],
    "有氧": ["有氧", "心肺", "心率"],
}
EXERCISE_SUFFIXES = [
    "俯卧撑",
    "深蹲",
    "卧推",
    "硬拉",
    "划船",
    "推举",
    "弯举",
    "飞鸟",
    "弓步",
    "臀桥",
    "平板支撑",
    "引体向上",
    "下拉",
    "腿举",
    "提踵",
    "伸展",
]


def load_rows() -> list[dict]:
    rows = []
    with CORPUS.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def main() -> None:
    rows = load_rows()
    # Top common exercises plus a spread across body parts/equipment.
    by_rank = sorted(rows, key=lambda item: item.get("common_rank", 999))
    selected: list[dict] = by_rank[:60]
    seen = {item["id"] for item in selected}
    for item in rows:
        if len(selected) >= 120:
            break
        if item["id"] not in seen:
            selected.append(item)
            seen.add(item["id"])

    equipment_prefixes = [
        "杠铃",
        "哑铃",
        "史密斯",
        "绳索",
        "弹力带",
        "壶铃",
        "固定器械",
        "EZ 杠",
        "阻力带",
        "药球",
        "稳定球",
        "波速球",
        "雪橇机",
        "六角杠",
        "奥林匹克杠",
    ]
    items = []
    for index, item in enumerate(selected[:120], 1):
        name = item["name_zh"]
        equipment = item.get("equipment_zh") or "器械"
        lookup_variants = [name]
        for prefix in equipment_prefixes:
            if name.startswith(prefix) and len(name) > len(prefix) + 1:
                lookup_variants.append(name[len(prefix) :])
                break
        for suffix in EXERCISE_SUFFIXES:
            if suffix in name:
                lookup_variants.append(suffix)
                break
        body = item.get("body_part_zh") or ""
        body_words = BODY_SYNONYMS.get(body, [body])
        keywords = [name, equipment, *body_words]
        question = (
            f"{name}怎么做？"
            if index % 2 == 0
            else f"{name}主要练哪里？"
        )
        items.append(
            {
                "id": f"exercise_{index:03d}",
                "category": "exercise",
                "persona": PERSONAS[index % len(PERSONAS)],
                "turns": [question],
                "visual_context": None,
                "expected": {
                    "must_include_any": keywords,
                    "must_not_include": ["我是 AI", "无法回答"],
                    "expected_actions": [],
                    "expected_tools": ["lookup_exercise"],
                    "lookup_names_any": lookup_variants,
                    "lookup_exact_names": [name],
                    "expected_safety": False,
                    "body_fat_approx": False,
                    "max_sentences": 5,
                },
                "note": f"RAG lookup for {name}",
            }
        )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("w", encoding="utf-8") as handle:
        for item in items:
            handle.write(json.dumps(item, ensure_ascii=False) + "\n")
    print(f"wrote {len(items)} scenarios to {OUTPUT}")


if __name__ == "__main__":
    main()
