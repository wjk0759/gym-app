"""Deterministic media-intent scenarios.

The text model is good at writing questions but bad at varying media fixtures.
This script pairs fixed, realistic fixtures with question templates so the
3,000-case bank has 200 photo/video cases without repeating one image forever.
"""

from __future__ import annotations

import json
from pathlib import Path

OUTPUT = Path(__file__).resolve().parent / "scenarios" / "media_200.jsonl"
PERSONAS = ["beginner", "intermediate", "rehab", "busy", "older"]

BODY = [
    ("全身正面照，光线一般", 17, 0.58),
    ("全身侧面照，光线充足", 19, 0.70),
    ("全身正面照，居家背景", 21, 0.62),
    ("半身照，室内光线偏暗", 24, 0.42),
    ("全身正面照，健身房镜前", 26, 0.66),
    ("全身侧面照，傍晚自然光", 18, 0.64),
    ("全身正面照，白墙背景", 22, 0.68),
    ("全身正面照，光线偏暗", 28, 0.38),
    ("半身照，窗边自然光", 20, 0.55),
    ("全身正面照，训练后拍摄", 23, 0.60),
]

EQUIPMENT = [
    ("坐姿推胸机", "胸部和肱三头肌"),
    ("史密斯机", "深蹲和推举"),
    ("龙门架", "夹胸和绳索下压"),
    ("腿举机", "股四头肌和臀"),
    ("壶铃", "摆荡和深蹲"),
    ("弹力带", "划船和臀腿激活"),
    ("哑铃", "上肢推拉"),
    ("高位下拉", "背阔肌和肱二头肌"),
    ("椭圆机", "心肺和下肢"),
    ("跑步机", "心肺和下肢"),
    ("辅助引体机", "背部和肱二头肌"),
    ("腿屈伸机", "股四头肌"),
]

FOOD = [
    ("鸡胸肉、米饭和西兰花", [{"name": "鸡胸肉", "grams": 150, "kcal": 250, "protein_g": 35}]),
    ("牛肉面加煎蛋", [{"name": "牛肉面", "grams": 500, "kcal": 650, "protein_g": 28}]),
    ("半糖珍珠奶茶", [{"name": "奶茶", "grams": 500, "kcal": 320, "protein_g": 4}]),
    ("清汤火锅，牛肉、豆腐和蔬菜", [{"name": "火锅", "grams": 600, "kcal": 760, "protein_g": 52}]),
    ("鸡蛋、全麦面包和牛奶", [{"name": "早餐", "grams": 350, "kcal": 430, "protein_g": 24}]),
    ("鸡胸沙拉", [{"name": "沙拉", "grams": 350, "kcal": 300, "protein_g": 30}]),
]

VIDEO = [
    ("深蹲", "深蹲侧面，底部膝盖轻微内扣", ["下蹲到大腿平行", "脚掌稳定"], "起身时把膝盖对准脚尖。"),
    ("硬拉", "硬拉侧面，杠铃离身体略远", ["背部基本中立", "锁定还可以"], "起拉前把杠铃贴紧小腿。"),
    ("卧推", "卧推侧面，肘部打开偏大", ["肩胛有后缩", "下放速度可控"], "下放时肘部收向身体约 45 度。"),
    ("引体向上", "引体正面，肩膀耸起", ["下巴过杠", "下放完整"], "先沉肩再拉，别用耸肩借力。"),
    ("箭步蹲", "箭步蹲正面，前膝内扣", ["步幅偏小", "躯干直立"], "前膝对准第二脚趾，步幅再大一点。"),
]

BODY_CONTEXTS = [
    "今天早上拍的",
    "昨晚练完拍的",
    "上周同角度拍的",
    "刚吃完饭拍的",
    "健身房灯光下拍的",
    "家里白墙前拍的",
    "出差酒店拍的",
    "早上空腹拍的",
    "训练前拍的",
    "训练后拍的",
]

BODY_QUESTIONS = [
    "教练，看这张照片我体脂大概多少？",
    "这张全身照能看出体脂吗？",
    "我想把体脂降到 15%，现在大概多少？",
    "最近体脂降了吗？",
    "帮我记录一下这次体脂。",
    "照片里能看出肌肉量吗？",
]

EQUIPMENT_QUESTIONS = [
    "这个{name}怎么调？",
    "{name}主要练哪里？",
    "没有{name}怎么替代？",
    "我第一次用{name}，要注意什么？",
    "{name}适合新手吗？",
]

FOOD_QUESTIONS = [
    "这顿{summary}热量多少？",
    "这个{summary}蛋白质够吗？",
    "减脂期吃{summary}行吗？",
    "练完吃{summary}可以吗？",
    "这顿{summary}大概多少卡？",
    "晚上吃{summary}会不会太多？",
    "这顿{summary}碳水高吗？",
]

VIDEO_QUESTIONS = [
    "看看我{action}的动作。",
    "{action}时膝盖有问题吗？",
    "这个{action}视频帮我抠下细节。",
    "我{action}总是找不到发力，帮我看下。",
    "只有 20 分钟，{action}这样练行吗？",
    "教练，我这个{action}标准吗？",
    "帮我看看{action}的起始位置。",
    "我练{action}之后腰有点酸，动作有问题吗？",
]


def make(category: str, index: int, question: str, visual: dict, expected: dict, note: str) -> dict:
    return {
        "id": f"media_{category}_{index + 1:03d}",
        "category": category,
        "persona": PERSONAS[index % len(PERSONAS)],
        "turns": [question],
        "visual_context": visual,
        "expected": {
            "must_include_any": expected["must_include_any"],
            "must_not_include": expected.get("must_not_include", ["我是 AI", "无法回答"]),
            "expected_actions": [],
            "expected_tools": [],
            "expected_safety": False,
            "body_fat_approx": expected.get("body_fat_approx", False),
            "max_sentences": 5,
        },
        "note": note,
    }


def main() -> None:
    items: list[dict] = []

    for index in range(60):
        summary, estimate, confidence = BODY[index % len(BODY)]
        base_question = BODY_QUESTIONS[index % len(BODY_QUESTIONS)]
        context = BODY_CONTEXTS[
            (index // len(BODY_QUESTIONS)) % len(BODY_CONTEXTS)
        ]
        question = f"{context}，{base_question}"
        asks_body_fat = "体脂" in question
        items.append(
            make(
                "body",
                index,
                question,
                {
                    "kind": "body_photo",
                    "summary": summary,
                    "body_fat_estimate": estimate,
                    "confidence": confidence,
                },
                {
                    "must_include_any": (
                        ["约", "大概", "左右", "%"]
                        if asks_body_fat
                        else ["肌肉", "训练", "照片", "看", "体型"]
                    ),
                    "body_fat_approx": asks_body_fat,
                },
                "deterministic body fixture",
            )
        )

    for index, (name, use) in enumerate(EQUIPMENT * 5):
        if index >= 60:
            break
        question = EQUIPMENT_QUESTIONS[index % len(EQUIPMENT_QUESTIONS)].format(name=name)
        items.append(
            make(
                "equipment",
                index,
                question,
                {"kind": "equipment_photo", "name": name, "summary": f"{name}，{use}"},
                {
                    "must_include_any": [
                        "练",
                        "调",
                        "做",
                        "次",
                        "组",
                        "替代",
                        "适合",
                        "器械",
                        "哑铃",
                        "杠铃",
                        "坡度",
                        "配重",
                        "注意",
                    ]
                },
                "deterministic equipment fixture",
            )
        )

    food_index = 0
    for summary, food_items in FOOD:
        for template in FOOD_QUESTIONS:
            if food_index >= 40:
                break
            items.append(
                make(
                    "food",
                    food_index,
                    template.format(summary=summary),
                    {"kind": "food_photo", "summary": summary, "items": food_items},
                    {"must_include_any": ["热量", "卡", "蛋白", "估算", "克"]},
                    "deterministic food fixture",
                )
            )
            food_index += 1

    video_index = 0
    for action, summary, observations, cue in VIDEO:
        for template in VIDEO_QUESTIONS:
            if video_index >= 40:
                break
            items.append(
                make(
                    "video",
                    video_index,
                    template.format(action=action),
                    {
                        "kind": "training_video",
                        "summary": summary,
                        "observations": observations,
                        "next_cue": cue,
                    },
                    {"must_include_any": ["动作", "膝", "肘", "肩", "提示", "调整", "视频"]},
                    "deterministic video fixture",
                )
            )
            video_index += 1

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("w", encoding="utf-8") as handle:
        for item in items:
            handle.write(json.dumps(item, ensure_ascii=False) + "\n")
    print(f"wrote {len(items)} media scenarios to {OUTPUT}")


if __name__ == "__main__":
    main()
