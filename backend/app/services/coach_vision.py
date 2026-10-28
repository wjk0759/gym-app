"""教练视觉分析：训练、饮食、器械、体型和一般健身问题。

只根据画面中可见的内容回答，不猜测镜头外，不做医疗诊断。
"""

from __future__ import annotations

import base64
import logging

from ..config import settings
from . import llm

logger = logging.getLogger(__name__)

VALID_MODES = {"training", "nutrition", "equipment", "body", "general"}

SYSTEM_PROMPT = (
    "你是 FitAI 的 AI 私人健身教练，正在看用户上传的图片或视频关键帧。"
    "你的工作范围包括训练动作、饮食营养、健身器械、体型体态、恢复和一般健身问题。"
    "先根据用户问题和画面内容判断本轮意图，不要默认所有图片都是训练动作。"
    "训练动作：mode=training，观察可见姿势、动作阶段、器械和安全风险，next_cue 只给一个最重要的动作提示。"
    "食物/营养：mode=nutrition，识别食物、份量和营养，热量和克数是估算，明确提示需要称重；不要给动作提示。"
    "器械：mode=equipment，说明器械名称、用途、可练部位和替代方案；除非用户明确问动作，否则不点评动作。"
    "体型/体态：mode=body，只描述可见体态和训练重点，不诊断、不评价身材、不制造焦虑。"
    "其他健身相关：mode=general，直接回答；与健身无关的内容简短说明你的服务范围，不要硬套训练模板。"
    "多张照片或视频关键帧按上传顺序看，动作变化比单帧更重要。"
    "只根据画面中明确可见的内容回答，不猜测镜头外动作，不诊断伤病。"
    "如果出现胸痛、晕厥、明显畸形、无法承重等急性风险，safety_flag 输出 medical_referral，并建议立即停止训练、线下就医。"
    "只输出一个 JSON 对象，不要输出 Markdown。"
)

USER_PROMPT = (
    "请根据用户问题和图片内容选择 mode，输出 JSON："
    '{"mode":"training|nutrition|equipment|body|general",'
    '"is_training":true或false,'
    '"summary":"一句话结论",'
    '"observations":["最多 4 条可见事实、估算或判断"],'
    '"next_cue":"仅 training 模式给一个动作要点；其他模式必须为 null",'
    '"safety_flag":null或"medical_referral"}'
    "如果图片是食物，summary 直接回答热量/营养问题；如果是训练，summary 直接说动作问题；"
    "不要输出固定的训练点评模板。"
)

_TRAINING_WORDS = (
    "动作",
    "姿势",
    "深蹲",
    "硬拉",
    "卧推",
    "推举",
    "划船",
    "引体",
    "俯卧撑",
    "弓步",
    "臀桥",
    "平板支撑",
    "发力",
    "标准",
    "训练",
    "组",
    "次",
    "膝盖",
    "腰",
    "肩",
    "肘",
    "腕",
    "疼",
    "痛",
)

_NUTRITION_WORDS = (
    "热量",
    "卡路里",
    "千卡",
    "大卡",
    "kcal",
    "吃",
    "食物",
    "餐",
    "饭",
    "饮食",
    "营养",
    "蛋白",
    "碳水",
    "脂肪",
    "榴莲",
    "水果",
    "蔬菜",
    "奶",
    "饮料",
    "零食",
    "外卖",
    "食谱",
    "份量",
    "克",
    "减脂餐",
    "增肌餐",
)

_EQUIPMENT_WORDS = (
    "器械",
    "器材",
    "哑铃",
    "杠铃",
    "壶铃",
    "弹力带",
    "史密斯",
    "龙门架",
    "划船机",
    "跑步机",
    "椭圆机",
    "单车",
    "腿举",
    "蝴蝶机",
    "绳索",
    "怎么用",
    "替代",
)

_BODY_WORDS = (
    "体型",
    "体态",
    "身材",
    "体脂",
    "腹肌",
    "肌肉",
    "胖",
    "瘦",
    "比例",
    "圆肩",
    "驼背",
    "骨盆",
    "腿型",
)


def _question_mode(question: str) -> str | None:
    """从问题里猜一个意图，避免视觉模型把所有图片都按训练动作回答。"""
    text = question.strip().lower()
    if not text:
        return None

    scores = {
        "training": sum(1 for word in _TRAINING_WORDS if word in text),
        "nutrition": sum(1 for word in _NUTRITION_WORDS if word in text),
        "equipment": sum(1 for word in _EQUIPMENT_WORDS if word in text),
        "body": sum(1 for word in _BODY_WORDS if word in text),
    }
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else None


async def review(image_bytes: bytes, question: str = "") -> dict:
    if not image_bytes:
        return _fallback("没有收到图片")
    return await review_many([image_bytes], question)


async def review_many(images: list[bytes], question: str = "") -> dict:
    if not images:
        return _fallback("没有收到图片")
    if settings.use_mock_vision:
        return _fallback("当前未配置视觉模型")

    intent = _question_mode(question)
    prompt = USER_PROMPT
    if len(images) > 1:
        prompt += f"\n本次共有 {len(images)} 张图片或关键帧，请按上传顺序综合判断。"
    if intent:
        prompt += f"\n本轮用户意图更接近：{intent}。除非画面明显不符，优先按这个模式回答。"
    if question.strip():
        prompt += f"\n用户问题：{question.strip()[:2000]}"
    else:
        prompt += "\n用户没有补充文字。先识别图片内容再选择 mode，不要默认 training。"

    try:
        raw = await llm.complete_vision_json(
            SYSTEM_PROMPT,
            prompt,
            [base64.b64encode(image).decode() for image in images],
        )
    except Exception as exc:  # noqa: BLE001 - 视觉失败必须降级而不是让拍照崩溃
        logger.warning("coach vision failed: %s", exc)
        return _fallback(f"视觉分析失败：{str(exc)[:160]}")

    summary = str(raw.get("summary") or "").strip()[:400]
    if not summary:
        return _fallback("视觉模型没有返回有效分析")

    observations_raw = raw.get("observations")
    if isinstance(observations_raw, str):
        observations_raw = [observations_raw]
    observations = [
        str(item).strip()[:160]
        for item in (observations_raw or [])
        if str(item).strip()
    ][:4]

    raw_mode = str(raw.get("mode") or "").strip().lower()
    mode = raw_mode if raw_mode in VALID_MODES else (intent or "general")
    if intent:
        mode = intent
    if mode not in VALID_MODES:
        mode = "general"

    raw_training = raw.get("is_training")
    if isinstance(raw_training, str):
        is_training = raw_training.strip().lower() not in {"false", "0", "no"}
    elif raw_training is None:
        is_training = mode == "training"
    else:
        is_training = bool(raw_training)

    if mode != "training":
        is_training = False

    next_cue = str(raw.get("next_cue") or "").strip()[:240]
    if mode != "training" or not is_training:
        next_cue = ""

    safety_flag = str(raw.get("safety_flag") or "").strip()
    if safety_flag not in {"medical_referral"}:
        safety_flag = ""

    return {
        "mode": mode,
        "is_training": is_training,
        "summary": summary,
        "observations": observations,
        "next_cue": next_cue,
        "safety_flag": safety_flag or None,
        "warning": None,
    }


def _fallback(reason: str) -> dict:
    return {
        "mode": "general",
        "is_training": False,
        "summary": "这次没有连上视觉模型，暂时无法可靠分析这张图。",
        "observations": [],
        "next_cue": "",
        "safety_flag": None,
        "warning": reason[:200],
    }
