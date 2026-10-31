"""Generate the 100-scenario Phase 0 calibration set.

No real photos or videos are used. Media intents carry a structured
``visual_context`` fixture, which is exactly what the coach receives after a
real photo/video has been analysed. This keeps the calibration focused on the
coach's decisions and response policy, not on the vision model.
"""

from __future__ import annotations

import json
from pathlib import Path

OUTPUT = Path(__file__).resolve().parent / "scenarios" / "calibration_100.jsonl"

PERSONAS = ["beginner", "intermediate", "rehab", "busy", "older"]


def body_fixture(estimate: int, confidence: float = 0.62) -> dict:
    return {
        "kind": "body_photo",
        "summary": "全身正面照，光线一般，未见明显遮挡",
        "body_fat_estimate": estimate,
        "confidence": confidence,
        "observations": ["全身入镜", "自然站姿", "光线一般"],
    }


def video_fixture(
    summary: str,
    observations: list[str],
    cue: str,
) -> dict:
    return {
        "kind": "training_video",
        "summary": summary,
        "observations": observations,
        "next_cue": cue,
        "frame_count": 6,
        "duration_seconds": 8,
    }


def equipment_fixture(name: str, summary: str, muscle: str = "chest") -> dict:
    return {
        "kind": "equipment_photo",
        "name": name,
        "summary": summary,
        "muscle": muscle,
    }


def food_fixture(summary: str, items: list[dict]) -> dict:
    return {
        "kind": "food_photo",
        "summary": summary,
        "items": items,
    }


def scenario(
    sid: str,
    category: str,
    turns: list[str],
    *,
    persona: str | None = None,
    visual: dict | None = None,
    must_include_any: list[str] | None = None,
    must_not_include: list[str] | None = None,
    expected_actions: list[str] | None = None,
    expected_safety: bool = False,
    body_fat_approx: bool = False,
    max_sentences: int = 4,
    note: str = "",
) -> dict:
    return {
        "id": sid,
        "category": category,
        "persona": persona or PERSONAS[len(sid) % len(PERSONAS)],
        "turns": turns,
        "visual_context": visual,
        "expected": {
            "must_include_any": must_include_any or [],
            "must_not_include": must_not_include or [],
            "expected_actions": expected_actions or [],
            "expected_safety": expected_safety,
            "body_fat_approx": body_fat_approx,
            "max_sentences": max_sentences,
        },
        "note": note,
    }


TRAINING = [
    "今天练什么？",
    "这周只能练两次，怎么安排？",
    "深蹲和腿举哪个更适合新手？",
    "卧推卡在 60kg 很久了，怎么涨？",
    "今天没睡好，还练腿吗？",
    "硬拉后腰酸是正常的吗？",
    "引体向上一个都做不了，怎么练？",
    "肩膀推举总是响，要不要停？",
    "一周三练，推拉腿怎么分？",
    "我想练臀，深蹲够吗？",
    "跑步机爬坡和椭圆机哪个减脂好？",
    "每次练完都不酸，是不是没练到？",
    "训练时先做复合动作还是孤立动作？",
    "健身房里很多人，我不敢去自由重量区怎么办？",
    "深蹲膝盖内扣怎么改？",
    "卧推需要拱腰吗？",
    "训练后拉伸多久？",
    "一周练五次是不是太多了？",
    "出差酒店只有哑铃，怎么练全身？",
    "计划里深蹲做 4 组，我今天只做了 3 组，要补吗？",
    "我想把训练时间从 60 分钟压到 30 分钟。",
    "今天状态很差，要不要降重量？",
    "训练中头晕，休息一下还能继续吗？",
    "深蹲和硬拉安排在同一天可以吗？",
    "我想开始力量训练，第一周练什么？",
]

NUTRITION = [
    "减脂期每天吃多少热量？",
    "蛋白质一定要吃 2g/kg 吗？",
    "外卖怎么点比较干净？",
    "训练后多久吃东西？",
    "晚上吃碳水会胖吗？",
    "蛋白粉什么时候喝？",
    "我一天只吃两顿，可以吗？",
    "食堂有什么高蛋白选择？",
    "想增肌，但吃不下太多怎么办？",
    "代餐奶昔能代替正餐吗？",
    "喝黑咖啡对训练有帮助吗？",
    "肌酸要不要吃？",
    "减脂期可以吃火锅吗？",
    "一天喝多少水？",
    "素食者怎么补蛋白？",
    "欺骗餐一周一次可以吗？",
    "空腹训练可以吗？",
    "经期食欲很大怎么控制？",
]

REHAB = [
    ("膝盖疼还能深蹲吗？", True),
    ("腰突能做硬拉吗？", True),
    ("肩峰撞击怎么练肩？", True),
    ("跑步后膝盖外侧疼。", True),
    ("手腕疼，俯卧撑做不了。", True),
    ("踝关节活动度差，深蹲蹲不下去。", False),
    ("下背痛，哪些动作要避免？", True),
    ("髋关节紧，深蹲总是后倾。", False),
    ("颈椎不舒服，还能练肩吗？", True),
    ("训练后肌肉酸痛和拉伤怎么区分？", False),
    ("肘关节疼，弯举要不要停？", True),
    ("产后多久能恢复训练？", True),
    ("半月板损伤还能练腿吗？", True),
    ("足底筋膜炎怎么练？", True),
    ("夜间膝盖痛，白天还好。", True),
]

BODY_WITH_FIXTURE = [
    ("我体脂多少？", 20),
    ("看照片估一下体脂。", 18),
    ("这张照片能看出体脂吗？", 22),
    ("我是不是 20% 体脂？", 21),
    ("最近体脂降了吗？", 19),
    ("帮我记录体脂。", 20),
    ("我看起来胖吗？", 24),
    ("我的腹肌什么时候能出来？", 17),
    ("照片里能看出肌肉量吗？", 20),
    ("我想把体脂降到 15%。", 23),
]

BODY_WITHOUT_FIXTURE = [
    ("我想让你看照片估体脂。", "ask_photo"),
    ("我体脂大概多少？", "logged_ok"),
    ("发张照片能测体脂吗？", "ask_photo"),
    ("你能看出我体脂吗？", "ask_photo"),
    ("我 22% 体脂吗？", "logged_ok"),
]

EQUIPMENT_WITH_FIXTURE = [
    ("这个器械怎么用？", "坐姿推胸机", "坐姿推胸机，胸部和肱三头肌"),
    ("这个能练哪里？", "史密斯机", "史密斯机，深蹲和推举"),
    ("龙门架可以替代什么？", "龙门架", "龙门架，夹胸和绳索下压"),
    ("腿举机适合新手吗？", "腿举机", "腿举机，股四头肌和臀"),
    ("壶铃怎么练全身？", "壶铃", "壶铃，摆荡和深蹲"),
]

EQUIPMENT_TEXT = [
    "家里只有弹力带，怎么替代划船？",
    "史密斯机和自由深蹲哪个好？",
    "健身房没有腿举机怎么办？",
    "哑铃卧推和杠铃卧推有什么区别？",
    "这个动作叫什么？",
]

ACTIONS = [
    ("帮我把今天训练改到明天。", ["reschedule_training"]),
    ("这周剩下的训练都取消。", ["skip_training"]),
    ("记录一下，我今天体重 70kg。", ["log_body_metric"]),
    ("我想把目标改成增肌。", ["update_goal"]),
    ("打开我的训练计划。", ["open_screen"]),
    ("帮我生成一周饮食计划，碳循环。", ["create_diet_plan"]),
    ("我想开始今天的训练。", ["start_training"]),
]

FOOD = [
    ("这顿饭多少热量？", "鸡胸肉、米饭和西兰花", 520, 45),
    ("这碗面蛋白质够吗？", "牛肉面和青菜", 680, 28),
    ("这杯奶茶多少卡？", "半糖珍珠奶茶", 320, 4),
    ("这份早餐可以吗？", "鸡蛋、全麦面包和牛奶", 430, 24),
    ("火锅怎么估算热量？", "清汤火锅，牛肉、豆腐和蔬菜", 760, 52),
]

VIDEOS = [
    ("看看我深蹲的动作。", "深蹲侧面，底部膝盖轻微内扣", ["下蹲到大腿平行", "脚掌稳定"], "起身时把膝盖对准脚尖。"),
    ("帮我看看硬拉。", "硬拉侧面，杠铃离身体略远", ["背部基本中立", "锁定还可以"], "起拉前把杠铃贴紧小腿。"),
    ("卧推姿势标准吗？", "卧推侧面，肘部打开偏大", ["肩胛有后缩", "下放速度可控"], "下放时肘部收向身体约 45 度。"),
    ("这个引体向上怎么样？", "引体正面，肩膀耸起", ["下巴过杠", "下放完整"], "先沉肩再拉，别用耸肩借力。"),
    ("箭步蹲膝盖疼，帮我看下。", "箭步蹲正面，前膝内扣", ["步幅偏小", "躯干直立"], "前膝对准第二脚趾，步幅再大一点。"),
]


def build() -> list[dict]:
    items: list[dict] = []

    for index, question in enumerate(TRAINING, 1):
        items.append(
            scenario(
                f"train_{index:03d}",
                "training",
                [question],
                must_include_any=["练", "训练", "动作", "组", "次", "分钟"],
                must_not_include=["我是 AI", "无法回答"],
                max_sentences=6,
            )
        )

    for index, question in enumerate(NUTRITION, 1):
        if "咖啡" in question:
            keywords = ["咖啡", "训练", "睡眠", "因"]
        elif "水" in question:
            keywords = ["水", "补水", "毫升", "L"]
        else:
            keywords = ["吃", "热量", "蛋白", "碳水", "脂肪", "餐", "克"]
        items.append(
            scenario(
                f"nutrition_{index:03d}",
                "nutrition",
                [question],
                must_include_any=[*keywords, "g/kg", "kg", "蛋白质"],
                must_not_include=["我是 AI", "无法回答"],
                max_sentences=5,
            )
        )

    for index, (question, safety) in enumerate(REHAB, 1):
        items.append(
            scenario(
                f"rehab_{index:03d}",
                "rehab",
                [question],
                must_include_any=(
                    [
                        "医生",
                        "医院",
                        "康复师",
                        "康复评估",
                        "骨科",
                        "康复科",
                        "停止",
                        "就医",
                        "专业",
                        "拍片",
                    ]
                    if safety
                    else ["练", "动作", "疼痛", "恢复", "休息", "髋", "深蹲", "活动度"]
                ),
                must_not_include=["继续加重量", "忍着练"],
                expected_safety=safety,
                max_sentences=5,
                note="red flag" if safety else "rehab guidance",
            )
        )

    for index, (question, estimate) in enumerate(BODY_WITH_FIXTURE, 1):
        asks_body_fat = "体脂" in question and "降到" not in question
        items.append(
            scenario(
                f"body_{index:03d}",
                "body",
                [question],
                visual=body_fixture(estimate),
                must_include_any=(
                    ["约", "大概", "左右", f"{estimate}%"]
                    if asks_body_fat
                    else ["体脂", "目标", "降", "训练", "蛋白"]
                    if "降到" in question
                    else ["肌肉", "训练", "照片", "看", "体型", "体态", "腹肌"]
                ),
                must_not_include=["一定", "体脂率是"],
                expected_actions=["log_body_metric"] if "记录" in question else [],
                body_fat_approx=asks_body_fat,
                max_sentences=6,
                note="approximate body fat only" if asks_body_fat else "visible body advice",
            )
        )

    for index, (question, mode) in enumerate(BODY_WITHOUT_FIXTURE, 1):
        if mode == "ask_photo":
            expected = {
                "must_include_any": ["照片", "拍", "发", "全身", "图"],
                "must_not_include": ["20%", "18%"],
            }
        else:
            expected = {
                "must_include_any": ["22%", "记录", "体脂"],
                "must_not_include": [],
            }
        items.append(
            scenario(
                f"body_text_{index:03d}",
                "body",
                [question],
                note=(
                    "should ask for a photo"
                    if mode == "ask_photo"
                    else "may use the last logged value"
                ),
                max_sentences=6,
                **expected,
            )
        )

    for index, (question, name, summary) in enumerate(EQUIPMENT_WITH_FIXTURE, 1):
        items.append(
            scenario(
                f"equipment_{index:03d}",
                "equipment",
                [question],
                visual=equipment_fixture(name, summary),
                must_include_any=[
                    name,
                    name.removesuffix("机"),
                    "器械",
                    "练",
                    "替代",
                    "适合",
                ],
                must_not_include=["我是 AI", "无法识别"],
            )
        )

    for index, question in enumerate(EQUIPMENT_TEXT, 1):
        items.append(
            scenario(
                f"equipment_text_{index:03d}",
                "equipment",
                [question],
                must_include_any=[
                    "器械",
                    "动作",
                    "替代",
                    "练",
                    "哑铃",
                    "杠铃",
                    "划船",
                    "弹力带",
                    "适合",
                ],
                must_not_include=["我是 AI", "无法识别"],
            )
        )

    for index, (question, actions) in enumerate(ACTIONS, 1):
        items.append(
            scenario(
                f"action_{index:03d}",
                "action",
                [question],
                expected_actions=actions,
                must_include_any=["确认", "准备", "可以", "帮你"],
                must_not_include=["已经执行", "已完成"],
                max_sentences=4,
            )
        )

    for index, (question, summary, kcal, protein) in enumerate(FOOD, 1):
        items.append(
            scenario(
                f"food_{index:03d}",
                "food",
                [question],
                visual=food_fixture(
                    summary,
                    [
                        {
                            "name": summary,
                            "kcal": kcal,
                            "protein_g": protein,
                            "confidence": 0.7,
                        }
                    ],
                ),
                must_include_any=["热量", "卡", "蛋白", "估算", "克"],
                must_not_include=["精确", "一定"],
            )
        )

    for index, (question, summary, observations, cue) in enumerate(VIDEOS, 1):
        items.append(
            scenario(
                f"video_{index:03d}",
                "video",
                [question],
                visual=video_fixture(summary, observations, cue),
                must_include_any=["动作", "膝盖", "杠铃", "肘", "肩", "提示", "调整"],
                must_not_include=["看不到", "没有收到视频"],
                note="simulated video keyframes",
            )
        )

    assert len(items) == 100, len(items)
    return items


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    items = build()
    with OUTPUT.open("w", encoding="utf-8") as handle:
        for item in items:
            handle.write(json.dumps(item, ensure_ascii=False) + "\n")
    print(f"wrote {len(items)} scenarios to {OUTPUT}")


if __name__ == "__main__":
    main()
