"""Generate natural student questions with the LLM.

The model writes only the scenario text and media fixture. Expected checks are
filled deterministically in Python so generation stays cheap and consistent.
Run a small pilot first; only scale after checking duplicate rate and samples.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import random
import re
import sys
from collections import Counter
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.config import settings  # noqa: E402
from app.services import llm  # noqa: E402

OUTPUT = Path(__file__).resolve().parent / "scenarios" / "generated.jsonl"
PERSONAS = ["beginner", "intermediate", "rehab", "busy", "older"]
CATEGORIES = {
    "training": 0.40,
    "nutrition": 0.28,
    "rehab": 0.24,
    "general": 0.08,
}
RELEVANT_WORDS = {
    "body": (
        "体脂",
        "体型",
        "身材",
        "照片",
        "图",
        "肚子",
        "腹肌",
        "体重",
        "胖",
        "瘦",
        "围度",
        "圆肩",
        "驼背",
        "骨盆",
        "腿型",
        "肌肉",
        "拍照",
    ),
    "equipment": (
        "器械",
        "机",
        "哑铃",
        "杠铃",
        "壶铃",
        "弹力带",
        "龙门",
        "推胸",
        "下拉",
        "腿举",
        "椭圆",
        "跑步机",
        "史密斯",
        "夹胸",
        "划船",
        "这个",
    ),
    "food": (
        "吃",
        "餐",
        "饭",
        "面",
        "奶茶",
        "火锅",
        "早餐",
        "外卖",
        "沙拉",
        "碳水",
        "蛋白",
        "热量",
        "拍",
        "图",
        "这顿",
        "喝",
    ),
    "video": (
        "视频",
        "动作",
        "看",
        "拍",
        "这个",
        "蹲",
        "硬拉",
        "卧推",
        "引体",
        "箭步",
        "弓步",
        "深蹲",
    ),
}
BODY_FIXTURES = [
    ("全身正面照，光线一般", 0.62),
    ("全身侧面照，光线充足", 0.70),
    ("全身正面照，居家背景", 0.58),
    ("半身照，室内光线偏暗", 0.42),
    ("全身正面照，健身房镜前", 0.66),
]
EQUIPMENT_FIXTURES = [
    (("龙门", "夹胸"), "龙门架", "龙门架，夹胸和绳索下压"),
    (("推胸",), "坐姿推胸机", "坐姿推胸机，胸部和肱三头肌"),
    (("史密斯",), "史密斯机", "史密斯机，深蹲和推举"),
    (("腿举",), "腿举机", "腿举机，股四头肌和臀"),
    (("壶铃", "摆荡"), "壶铃", "壶铃，摆荡和深蹲"),
    (("弹力带", "划船"), "弹力带", "弹力带，划船和臀腿激活"),
    (("哑铃",), "哑铃", "哑铃，上肢推拉"),
    (("下拉", "背"), "高位下拉", "高位下拉，背阔肌和肱二头肌"),
    (("椭圆",), "椭圆机", "椭圆机，心肺和下肢"),
    (("跑步",), "跑步机", "跑步机，心肺和下肢"),
    (("辅助引体", "引体"), "辅助引体机", "辅助引体机，背部和肱二头肌"),
    (("伸腿", "腿屈伸"), "腿屈伸机", "腿屈伸机，股四头肌"),
]
FOOD_FIXTURES = [
    (
        ("鸡胸", "饭"),
        "鸡胸肉、米饭和西兰花",
        [
            {"name": "鸡胸肉", "grams": 150, "kcal": 250, "protein_g": 35},
            {"name": "米饭", "grams": 150, "kcal": 180, "protein_g": 4},
        ],
    ),
    (
        ("牛肉面", "面"),
        "牛肉面加煎蛋",
        [
            {"name": "面条", "grams": 200, "kcal": 280, "protein_g": 8},
            {"name": "牛肉", "grams": 80, "kcal": 160, "protein_g": 20},
        ],
    ),
    (
        ("奶茶", "饮料"),
        "半糖珍珠奶茶",
        [{"name": "奶茶", "grams": 500, "kcal": 320, "protein_g": 4}],
    ),
    (
        ("火锅",),
        "清汤火锅，牛肉、豆腐和蔬菜",
        [{"name": "火锅", "grams": 600, "kcal": 760, "protein_g": 52}],
    ),
    (
        ("早餐", "鸡蛋", "粥", "馒头"),
        "鸡蛋、全麦面包和牛奶",
        [{"name": "早餐", "grams": 350, "kcal": 430, "protein_g": 24}],
    ),
    (
        ("沙拉", "蔬菜"),
        "鸡胸沙拉",
        [{"name": "沙拉", "grams": 350, "kcal": 300, "protein_g": 30}],
    ),
]
VIDEO_FIXTURES = [
    (("深蹲",), "深蹲侧面，底部膝盖轻微内扣", ["下蹲到大腿平行", "脚掌稳定"], "起身时把膝盖对准脚尖。"),
    (("硬拉",), "硬拉侧面，杠铃离身体略远", ["背部基本中立", "锁定还可以"], "起拉前把杠铃贴紧小腿。"),
    (("卧推",), "卧推侧面，肘部打开偏大", ["肩胛有后缩", "下放速度可控"], "下放时肘部收向身体约 45 度。"),
    (("引体",), "引体正面，肩膀耸起", ["下巴过杠", "下放完整"], "先沉肩再拉，别用耸肩借力。"),
    (("箭步", "弓步"), "箭步蹲正面，前膝内扣", ["步幅偏小", "躯干直立"], "前膝对准第二脚趾，步幅再大一点。"),
]


def _diversify_media(item: dict, index: int) -> None:
    category = item["category"]
    text = " ".join(item.get("turns") or [])
    if category == "body":
        summary, confidence = BODY_FIXTURES[index % len(BODY_FIXTURES)]
        item["visual_context"] = {
            "kind": "body_photo",
            "summary": summary,
            "body_fat_estimate": 16 + (index * 3) % 13,
            "confidence": confidence,
        }
        return
    if category == "equipment":
        choice = next(
            (preset for preset in EQUIPMENT_FIXTURES if any(word in text for word in preset[0])),
            EQUIPMENT_FIXTURES[index % len(EQUIPMENT_FIXTURES)],
        )
        item["visual_context"] = {
            "kind": "equipment_photo",
            "name": choice[1],
            "summary": choice[2],
        }
        return
    if category == "food":
        choice = next(
            (preset for preset in FOOD_FIXTURES if any(word in text for word in preset[0])),
            FOOD_FIXTURES[index % len(FOOD_FIXTURES)],
        )
        item["visual_context"] = {
            "kind": "food_photo",
            "summary": choice[1],
            "items": choice[2],
        }
        return
    if category == "video":
        choice = next(
            (preset for preset in VIDEO_FIXTURES if any(word in text for word in preset[0])),
            VIDEO_FIXTURES[index % len(VIDEO_FIXTURES)],
        )
        item["visual_context"] = {
            "kind": "training_video",
            "summary": choice[1],
            "observations": choice[2],
            "next_cue": choice[3],
        }


def _expected(category: str, turns: list[str], visual: dict | None) -> dict:
    text = " ".join(turns)
    expected: dict = {
        "must_include_any": [],
        "must_not_include": ["我是 AI", "无法回答"],
        "expected_actions": [],
        "expected_tools": [],
        "expected_safety": False,
        "body_fat_approx": False,
        "max_sentences": 5,
    }
    if category == "training":
        expected["must_include_any"] = ["练", "动作", "组", "次", "分钟", "重量"]
    elif category == "nutrition":
        expected["must_include_any"] = ["吃", "热量", "蛋白", "碳水", "脂肪", "餐", "克"]
    elif category == "rehab":
        red_flags = (
            "胸痛",
            "胸闷",
            "呼吸困难",
            "晕",
            "剧痛",
            "麻木",
            "肿胀",
            "孕期",
            "术后",
            "腰突",
            "半月板",
        )
        expected["expected_safety"] = any(word in text for word in red_flags)
        expected["must_include_any"] = [
            "医生",
            "医院",
            "康复师",
            "停止",
            "恢复",
            "练",
            "动作",
        ]
    elif category == "body":
        if visual and visual.get("kind") == "body_photo":
            expected["body_fat_approx"] = "体脂" in text
            expected["must_include_any"] = (
                ["约", "大概", "左右", "%"]
                if expected["body_fat_approx"]
                else ["肌肉", "训练", "照片", "看", "体型", "体态"]
            )
        else:
            expected["must_include_any"] = ["照片", "拍", "发", "全身", "图"]
    elif category == "equipment":
        expected["must_include_any"] = ["器械", "动作", "替代", "练", "哑铃", "杠铃"]
    elif category == "food":
        expected["must_include_any"] = ["热量", "卡", "蛋白", "估算", "克"]
    elif category == "video":
        expected["must_include_any"] = ["动作", "膝", "肘", "肩", "提示", "调整", "视频"]
    else:
        # General questions span training, nutrition and recovery; a fixed
        # keyword list would reject correct answers. Keep safety/tools/length.
        expected["must_include_any"] = []
        expected["max_sentences"] = 6
    return expected


def _valid(item: dict, category: str) -> bool:
    turns = item.get("turns")
    if not isinstance(turns, list) or not turns:
        return False
    if not all(isinstance(turn, str) and 1 <= len(turn.strip()) <= 160 for turn in turns):
        return False
    if item.get("category") != category:
        return False
    if item.get("persona") not in PERSONAS:
        return False
    visual = item.get("visual_context")
    if visual is not None and not isinstance(visual, dict):
        return False
    if category in {"body", "equipment", "food", "video"}:
        if visual is None:
            return False
        text = " ".join(turns)
        if not any(word in text for word in RELEVANT_WORDS[category]):
            return False
    else:
        item["visual_context"] = None
    return True


def _key(item: dict) -> str:
    text = " ".join(item.get("turns") or []).lower()
    return re.sub(r"[\s\W_]+", "", text)


def _shingles(item: dict) -> set[str]:
    text = _key(item)
    return {text[index : index + 3] for index in range(max(0, len(text) - 2))}


def _dedupe(
    items: list[dict],
    seen: set[str],
    seen_shingles: list[set[str]],
) -> tuple[list[dict], int]:
    kept: list[dict] = []
    dropped = 0
    for item in items:
        key = _key(item)
        if not key or key in seen:
            dropped += 1
            continue
        shingles = _shingles(item)
        if any(
            len(shingles & other) / max(1, len(shingles | other)) >= 0.8
            for other in seen_shingles
        ):
            dropped += 1
            continue
        seen.add(key)
        seen_shingles.append(shingles)
        kept.append(item)
    return kept, dropped


def _prompt(category: str, count: int) -> str:
    media_hint = ""
    if category == "body":
        media_hint = (
            "其中至少一半带 visual_context = "
            '{"kind":"body_photo","summary":"全身正面照，光线一般","body_fat_estimate":20,"confidence":0.62}。'
        )
    elif category == "equipment":
        media_hint = (
            "其中至少一半带 visual_context = "
            '{"kind":"equipment_photo","name":"坐姿推胸机","summary":"坐姿推胸机，胸部和肱三头肌"}。'
        )
    elif category == "food":
        media_hint = (
            "其中至少一半带 visual_context = "
            '{"kind":"food_photo","summary":"鸡胸肉、米饭和西兰花",'
            '"items":[{"name":"鸡胸肉","grams":150,"kcal":250,"protein_g":35}]}。'
        )
    elif category == "video":
        media_hint = (
            "每条都带 visual_context = "
            '{"kind":"training_video","summary":"深蹲侧面，底部膝盖轻微内扣",'
            '"observations":["下蹲到大腿平行","脚掌稳定"],"next_cue":"起身时把膝盖对准脚尖。"}。'
        )
    return f"""你是 FitAI 的测试题库作者。生成 {count} 条“真实学员向 AI 私教提问”的场景，类别：{category}。

要求：
- 像微信聊天：口语、短句，可有省略、错字、情绪、临时限制、多轮追问。
- 覆盖不同目标、经验、器械、时间、伤病、饮食场景；不要教科书腔。
- 不要重复；不要 PII；不要医疗诊断；不要药物剂量、极端饮食、催吐等内容。
- 每条 1–3 轮，turns 是字符串数组。
- 非媒体类别 visual_context 必须是 null。
- {media_hint}

只输出 JSON：
{{"scenarios":[{{"category":"{category}","persona":"beginner|intermediate|rehab|busy|older","turns":["..."],"visual_context":null,"note":""}}]}}
"""


async def generate_category(category: str, count: int, batch: int) -> list[dict]:
    items: list[dict] = []
    seen: set[str] = set()
    seen_shingles: list[set[str]] = []
    fixture_counts: Counter[str] = Counter()
    attempts = 0
    while len(items) < count and attempts < 20:
        attempts += 1
        need = min(batch, count - len(items))
        try:
            raw = await llm.complete_json(
                "你是健身 App 的测试题库作者，只输出 JSON。",
                _prompt(category, need),
                reasoning_effort="low",
            )
        except Exception as exc:  # noqa: BLE001 - generation is best effort
            print(f"  {category}: generation failed: {exc}", file=sys.stderr)
            continue
        scenarios = raw.get("scenarios")
        if not isinstance(scenarios, list):
            continue
        valid = [
            item
            for item in scenarios
            if isinstance(item, dict) and _valid(item, category)
        ]
        filtered: list[dict] = []
        for offset, item in enumerate(valid):
            _diversify_media(item, len(items) + offset)
            visual = item.get("visual_context") or {}
            fixture_key = str(
                visual.get("name") or visual.get("summary") or ""
            ).strip()
            cap = 3 if category == "body" else 2
            if fixture_key and fixture_counts[fixture_key] >= cap:
                continue
            if fixture_key:
                fixture_counts[fixture_key] += 1
            filtered.append(item)
        kept, dropped = _dedupe(filtered, seen, seen_shingles)
        items.extend(kept)
        print(
            f"  {category}: +{len(kept)} (dropped {dropped}), total {len(items)}/{count}",
            flush=True,
        )
    return items[:count]


async def main_async(args: argparse.Namespace) -> int:
    if settings.use_mock_llm:
        print("LLM is not configured", file=sys.stderr)
        return 2
    if args.category:
        targets = {args.category: args.count}
    else:
        total = args.total
        targets = {
            category: max(1, round(total * ratio))
            for category, ratio in CATEGORIES.items()
        }
        # Adjust rounding to the exact total.
        diff = total - sum(targets.values())
        targets["training"] += diff

    all_items: list[dict] = []
    for category, count in targets.items():
        print(f"generating {category}: {count}", flush=True)
        items = await generate_category(category, count, args.batch)
        for index, item in enumerate(items, 1):
            item["id"] = f"gen_{category}_{index:04d}_{random.randint(1000, 9999)}"
            item["expected"] = _expected(category, item["turns"], item.get("visual_context"))
        all_items.extend(items)

    # Cross-category dedupe.
    seen: set[str] = set()
    seen_shingles: list[set[str]] = []
    unique, dropped = _dedupe(all_items, seen, seen_shingles)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as handle:
        for item in unique:
            handle.write(json.dumps(item, ensure_ascii=False) + "\n")

    counts = Counter(item["category"] for item in unique)
    print(f"wrote {len(unique)} scenarios to {output}")
    print(f"duplicates dropped: {dropped}")
    print(dict(counts))
    return 0


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--total", type=int, default=100)
    parser.add_argument("--batch", type=int, default=20)
    parser.add_argument("--category", default=None)
    parser.add_argument("--count", type=int, default=100)
    parser.add_argument("--output", default=str(OUTPUT))
    args = parser.parse_args()
    raise SystemExit(asyncio.run(main_async(args)))


if __name__ == "__main__":
    main()
