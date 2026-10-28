"""动作照片点评：真实视觉模型优先，失败时诚实降级。

只根据画面中可见内容给训练提示，不做医疗诊断，也不猜测镜头外动作。
"""

from __future__ import annotations

import base64
import logging

from ..config import settings
from . import llm

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = (
    "你是资深力量教练，正在看用户上传的一张或多张训练照片。"
    "多张照片按上传顺序看，动作变化比单帧更重要；如果画面不是训练动作、健身器械或食物，"
    "is_training 输出 false，并如实说明拍到了什么。"
    "只点评画面里明确可见的内容，不猜测镜头外动作，不诊断伤病。"
    "如果出现胸痛、晕厥、明显畸形、无法承重等急性风险，safety_flag 输出 medical_referral，"
    "并建议立即停止训练、线下就医。"
    "只输出一个 JSON 对象，不要 Markdown。"
)

USER_PROMPT = (
    "请点评这些训练照片（按上传顺序）。输出 JSON："
    '{"is_training":true或false,'
    '"summary":"一句话结论",'
    '"observations":["最多4条可见问题或做得好的地方"],'
    '"next_cue":"下一组只提醒一个最重要的动作提示",'
    '"safety_flag":null或"medical_referral"}'
)


async def review(image_bytes: bytes, question: str = "") -> dict:
    if not image_bytes:
        return _fallback("没有收到图片")
    return await review_many([image_bytes], question)


async def review_many(images: list[bytes], question: str = "") -> dict:
    if not images:
        return _fallback("没有收到图片")
    if settings.use_mock_vision:
        return _fallback("当前未配置视觉模型")

    prompt = USER_PROMPT
    if len(images) > 1:
        prompt += f"\n本次共有 {len(images)} 张照片，请按上传顺序综合判断。"
    if question.strip():
        prompt += f"\n用户补充：{question.strip()[:300]}"

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
        return _fallback("视觉模型没有返回有效点评")

    observations_raw = raw.get("observations")
    if isinstance(observations_raw, str):
        observations_raw = [observations_raw]
    observations = [
        str(item).strip()[:160]
        for item in (observations_raw or [])
        if str(item).strip()
    ][:4]
    next_cue = str(raw.get("next_cue") or "").strip()[:240]
    safety_flag = str(raw.get("safety_flag") or "").strip()
    if safety_flag not in {"medical_referral"}:
        safety_flag = ""

    is_training = raw.get("is_training", True)
    if isinstance(is_training, str):
        is_training = is_training.strip().lower() not in {"false", "0", "no"}

    return {
        "is_training": bool(is_training),
        "summary": summary,
        "observations": observations,
        "next_cue": next_cue,
        "safety_flag": safety_flag or None,
        "warning": None,
    }


def _fallback(reason: str) -> dict:
    return {
        "is_training": False,
        "summary": "这次没有连上视觉模型，暂时无法可靠点评动作。",
        "observations": [],
        "next_cue": "先用文字告诉我动作、重量，以及哪里不舒服，我继续帮你判断。",
        "safety_flag": None,
        "warning": reason[:200],
    }
