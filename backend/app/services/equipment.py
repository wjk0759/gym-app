"""器械识别：当前为可替换的 Mock 实现，接口形状与真实视觉模型一致。"""

from __future__ import annotations

import hashlib
import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..models import Exercise

SUPPORTED_EQUIPMENT = ("machine", "cable", "barbell", "dumbbell", "kettlebell")


async def recognize(db: Session, image_bytes: bytes, filename: str) -> dict:
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

    # 用图片内容做确定性偏移，保证同一张图结果稳定，便于测试
    digest = hashlib.sha256(image_bytes).digest()
    start = digest[0] % max(1, len(rows))
    rotated = list(rows[start:]) + list(rows[:start])

    confidences = [0.91, 0.64, 0.48]
    candidates = []
    for exercise, confidence in zip(rotated[:3], confidences):
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
        "model": "mock" if settings.use_mock_vision else settings.vision_model,
        "image_name": filename,
    }
