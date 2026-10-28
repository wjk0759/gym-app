"""器械识别：视觉模型优先，Mock 兜底。

真实路径调用配置的视觉模型（默认 DeepSeek 视觉），返回器械类别与动作名，
再映射到当前启用的动作库。未配置视觉模型时回退确定性 Mock。
"""

from __future__ import annotations

import base64
import hashlib
import logging
import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..models import Exercise
from . import llm

logger = logging.getLogger(__name__)

SUPPORTED_EQUIPMENT = ("machine", "cable", "barbell", "dumbbell", "kettlebell")

_SYSTEM_PROMPT = (
    "你是健身房器械识别助手。根据图片判断器械类型和对应动作。"
    "如果图片不是健身器械，如实说明拍到的是什么，不要硬猜。"
    "只输出一个 JSON 对象，不要解释。"
)

_USER_PROMPT = (
    '识别图片里的内容，输出 JSON：'
    '{"description":"如实描述图片里有什么",'
    '"equipment":"machine|cable|barbell|dumbbell|kettlebell|bodyweight|none",'
    '"name":"器械或动作中文名","confidence":0.0到1.0}。'
    '如果图片不是健身器械（比如一块木头、手、地面、文字），equipment 输出 "none"，'
    'description 必须如实写清楚这是什么、为什么不是健身器械。只输出 JSON。'
)


def _active_exercises(db: Session) -> list[Exercise]:
    rows = (
        db.execute(
            select(Exercise).where(
                Exercise.is_active.is_(True),
                Exercise.equipment.in_(SUPPORTED_EQUIPMENT),
            )
        )
        .scalars()
        .all()
    )
    if not rows:
        rows = (
            db.execute(select(Exercise).where(Exercise.is_active.is_(True)))
            .scalars()
            .all()
        )
    return list(rows)


async def recognize(db: Session, image_bytes: bytes, filename: str) -> dict:
    if settings.use_mock_vision:
        return _mock_recognize(db, image_bytes, filename)

    try:
        result = await llm.complete_vision_json(
            _SYSTEM_PROMPT, _USER_PROMPT, base64.b64encode(image_bytes).decode()
        )
    except Exception as exc:  # noqa: BLE001 - 识别失败回退，不让拍照崩溃
        logger.warning("equipment vision failed, fallback to mock: %s", exc)
        payload = _mock_recognize(db, image_bytes, filename)
        payload["warning"] = f"视觉识别失败，已回退本地匹配：{str(exc)[:200]}"
        return payload

    equipment = str(result.get("equipment") or "").lower()
    name = str(result.get("name") or "").strip()
    description = str(result.get("description") or name or "").strip()
    confidence = _clamp_confidence(result.get("confidence"))

    if equipment == "none":
        return {
            "scan_id": str(uuid.uuid4()),
            "candidates": [],
            "needs_confirmation": True,
            "not_in_library": False,
            "name": name,
            "description": description or "未识别到健身器械",
            "model": settings.vision_model,
            "image_name": filename,
        }

    rows = _active_exercises(db)
    matched = [item for item in rows if _name_overlap(name, item.name_zh)]
    if not matched:
        return {
            "scan_id": str(uuid.uuid4()),
            "candidates": [],
            "needs_confirmation": True,
            "not_in_library": True,
            "name": name,
            "description": (
                description
                or (
                    f"识别到「{name}」，但当前动作库未收录，请手动添加或反馈。"
                    if name
                    else "未能匹配动作库中的器械，请手动添加或反馈。"
                )
            ),
            "model": settings.vision_model,
            "image_name": filename,
        }

    def rank(item: Exercise) -> tuple[int, int]:
        return (0 if _name_overlap(name, item.name_zh) else 1, item.difficulty)

    ordered = sorted(matched, key=rank)[:3]
    candidates = []
    for index, exercise in enumerate(ordered):
        candidates.append(
            {
                "slug": exercise.slug,
                "name_zh": exercise.name_zh,
                "muscle_group": exercise.muscle_group,
                "equipment": exercise.equipment,
                "confidence": round(max(0.30, confidence - index * 0.18), 2),
                "video_url": exercise.video_url,
            }
        )

    return {
        "scan_id": str(uuid.uuid4()),
        "candidates": candidates,
        "needs_confirmation": bool(candidates) and candidates[0]["confidence"] < 0.6,
        "not_in_library": False,
        "name": name,
        "description": description or name,
        "model": settings.vision_model,
        "image_name": filename,
    }


def _name_overlap(a: str, b: str) -> bool:
    a = (a or "").strip()
    b = (b or "").strip()
    if not a or not b:
        return False
    if a in b or b in a:
        return True
    bigrams = {a[i : i + 2] for i in range(len(a) - 1)}
    return any(bigram in b for bigram in bigrams)


def _clamp_confidence(value) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return 0.7
    return max(0.0, min(1.0, number))


def _mock_recognize(db: Session, image_bytes: bytes, filename: str) -> dict:
    rows = _active_exercises(db)

    # 用图片内容做确定性偏移，保证同一张图结果稳定，便于测试
    digest = hashlib.sha256(image_bytes).digest()
    start = digest[0] % max(1, len(rows))
    rotated = list(rows[start:]) + list(rows[:start])

    confidences = [0.91, 0.64, 0.48]
    candidates = []
    for exercise, confidence in zip(rotated[:3], confidences, strict=False):
        candidates.append(
            {
                "slug": exercise.slug,
                "name_zh": exercise.name_zh,
                "muscle_group": exercise.muscle_group,
                "equipment": exercise.equipment,
                "confidence": confidence,
                "video_url": exercise.video_url,
            }
        )

    return {
        "scan_id": str(uuid.uuid4()),
        "candidates": candidates,
        "needs_confirmation": (candidates[0]["confidence"] < 0.6) if candidates else True,
        "model": "mock",
        "image_name": filename,
    }
