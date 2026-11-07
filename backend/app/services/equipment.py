"""Equipment recognition: catalog-constrained vision, honest failures.

The vision model never invents exercise names. It picks one equipment type
from ``equipment_catalog`` and the backend maps that type to actions that
already exist in the active library. If vision fails, the API returns an
explicit ``unavailable`` result instead of pretending that random exercises
are real matches.
"""

from __future__ import annotations

import base64
import logging
import uuid
from contextlib import suppress

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..models import EquipmentLibraryItem, Exercise, Profile
from . import equipment_catalog, llm

logger = logging.getLogger(__name__)

_SYSTEM_PROMPT = """你是叫练的健身器械识别助手。你只判断图片中的健身器械类型，并从给定目录中选择。
规则：
1. 只能选择目录中存在的 equipment_slug；看不清或不是健身器械时用 unknown。
2. 图片里有多台器械时，选择占据画面主体、最靠近镜头的那一台。
3. 不要靠品牌或颜色猜；优先看结构：座椅、靠背、脚踏板、配重片、滑轮、把手、轨道、绳索。
4. 同一台器械可做多个动作时，最多列 3 个目录里给该器械的动作 slug。
5. 只输出一个 JSON 对象，不要解释。"""


def _user_prompt(ocr_text: str = "") -> str:
    ocr_block = ""
    if ocr_text:
        hint = equipment_catalog.match_name(ocr_text)
        hint_line = (
            f"\nOCR 匹配提示：{hint.slug}（{hint.name_zh}）"
            if hint is not None
            else ""
        )
        ocr_block = (
            f"\nOCR 在图片上读到的文字：{ocr_text}\n"
            "如果这段文字明确是画面主体器械的品牌/型号/动作名，把它作为强证据；"
            "如果文字属于背景里的另一台器械，忽略它。"
            f"{hint_line}\n"
        )
    return f"""器械目录：
{equipment_catalog.prompt_catalog()}
{ocr_block}
识别这张照片，严格输出 JSON：
{{
  "is_gym_equipment": true,
  "equipment_slug": "目录里的 slug 或 unknown",
  "equipment_name": "中文名",
  "confidence": 0.0,
  "visible_features": ["看到的 2-4 个结构特征"],
  "exercise_slugs": ["最多 3 个目录里给该器械的动作 slug"],
  "description": "一句话说明"
}}
如果不是健身器械：equipment_slug 用 "unknown"，exercise_slugs 输出 []，description 如实说明。"""


def available_equipment_types(
    db: Session,
    user_id: str,
    profile_equipment: list[str] | None,
) -> list[str]:
    """Equipment types the user can actually use.

    The personal equipment library is authoritative; the profile list remains a
    compatibility fallback for users who have not added library items yet.
    Bodyweight is always available.
    """
    rows = (
        db.execute(
            select(EquipmentLibraryItem.equipment).where(
                EquipmentLibraryItem.user_id == user_id,
                EquipmentLibraryItem.equipment.is_not(None),
            )
        )
        .scalars()
        .all()
    )
    types = {str(value).strip() for value in rows if value and str(value).strip()}
    if types:
        types.add("bodyweight")
        return sorted(types)
    types.update(str(value) for value in (profile_equipment or []) if value)
    types.add("bodyweight")
    return sorted(types)


def refresh_profile_equipment_cache(db: Session, user_id: str) -> None:
    """Keep the profile equipment list in sync with the personal library."""
    profile = db.get(Profile, user_id)
    if profile is None:
        return
    profile.equipment = available_equipment_types(
        db, user_id, profile.equipment
    )


def _active_exercises(db: Session) -> list[Exercise]:
    return list(
        db.execute(
            select(Exercise).where(Exercise.is_active.is_(True))
        )
        .scalars()
        .all()
    )


async def recognize(
    db: Session,
    image_bytes: bytes,
    filename: str,
    *,
    user_id: str | None = None,
    ocr_text: str = "",
) -> dict:
    if settings.use_mock_vision:
        return _unavailable(
            filename,
            "视觉模型未配置，暂时无法识别。",
        )

    usage: dict[str, int] = {}
    try:
        result = await llm.complete_vision_json(
            _SYSTEM_PROMPT,
            _user_prompt(ocr_text),
            base64.b64encode(image_bytes).decode(),
            usage=usage,
            db=db,
            user_id=user_id,
            kind="equipment_scan",
        )
    except Exception as exc:  # noqa: BLE001 - return an honest UI state
        logger.warning("equipment vision failed: %s", exc)
        with suppress(Exception):
            llm.record_job(
                db,
                user_id,
                kind="equipment_scan",
                status="failed",
                model=settings.vision_model_name,
                error=str(exc)[:500],
                usage=usage,
            )
        return _unavailable(
            filename,
            "视觉识别暂时不可用，请稍后重试。",
        )

    return _map_result(db, result, filename)


def _map_result(db: Session, result: dict, filename: str) -> dict:
    equipment_slug = str(result.get("equipment_slug") or "").strip().lower()
    equipment_name = str(result.get("equipment_name") or "").strip()
    description = str(result.get("description") or "").strip()
    confidence = _clamp_confidence(result.get("confidence"))
    features = result.get("visible_features")
    if not isinstance(features, list):
        features = []

    if result.get("is_gym_equipment") is False or equipment_slug == "unknown":
        return {
            "scan_id": str(uuid.uuid4()),
            "candidates": [],
            "needs_confirmation": True,
            "not_in_library": False,
            "name": equipment_name or "未知",
            "description": description or "未识别到健身器械。",
            "equipment_slug": "unknown",
            "equipment_name": equipment_name,
            "confidence": confidence,
            "visible_features": features,
            "model": settings.vision_model_name,
            "image_name": filename,
            "status": "not_gym_equipment",
        }

    catalog = (
        equipment_catalog.get(equipment_slug)
        or equipment_catalog.match_name(equipment_name)
        or equipment_catalog.match_name(str(result.get("name") or ""))
    )
    if catalog is None:
        return {
            "scan_id": str(uuid.uuid4()),
            "candidates": [],
            "needs_confirmation": True,
            "not_in_library": True,
            "name": equipment_name or "未收录器械",
            "description": description
            or f"识别到「{equipment_name or '器械'}」，但当前动作库未收录。",
            "equipment_slug": equipment_slug or "unknown",
            "equipment_name": equipment_name,
            "confidence": confidence,
            "visible_features": features,
            "model": settings.vision_model_name,
            "image_name": filename,
            "status": "unknown_equipment",
        }

    rows = {
        item.slug: item
        for item in _active_exercises(db)
        if item.slug in set(catalog.exercise_slugs)
    }
    requested = [
        str(item).strip()
        for item in (
            result.get("exercise_slugs")
            if isinstance(result.get("exercise_slugs"), list)
            else []
        )
        if str(item).strip() in catalog.exercise_slugs
    ]
    ordered = requested + [
        slug for slug in catalog.exercise_slugs if slug not in requested
    ]

    candidates: list[dict] = []
    for index, slug in enumerate(ordered):
        exercise = rows.get(slug)
        if exercise is None:
            continue
        candidates.append(
            {
                "slug": exercise.slug,
                "name_zh": exercise.name_zh,
                "muscle_group": exercise.muscle_group,
                "equipment": exercise.equipment,
                "confidence": round(
                    max(0.30, confidence - index * 0.14), 2
                ),
                "video_url": exercise.video_url,
            }
        )
        if len(candidates) == 3:
            break

    if not candidates:
        return {
            "scan_id": str(uuid.uuid4()),
            "candidates": [],
            "needs_confirmation": True,
            "not_in_library": True,
            "name": catalog.name_zh,
            "description": description
            or f"识别到「{catalog.name_zh}」，但当前动作库未收录。",
            "equipment_slug": catalog.slug,
            "equipment_name": catalog.name_zh,
            "confidence": confidence,
            "visible_features": features,
            "model": settings.vision_model_name,
            "image_name": filename,
            "status": "no_actions",
        }

    return {
        "scan_id": str(uuid.uuid4()),
        "candidates": candidates,
        "needs_confirmation": confidence < 0.6,
        "not_in_library": False,
        "name": catalog.name_zh,
        "description": description or f"识别到「{catalog.name_zh}」。",
        "equipment_slug": catalog.slug,
        "equipment_name": catalog.name_zh,
        "confidence": confidence,
        "visible_features": features,
        "model": settings.vision_model_name,
        "image_name": filename,
        "status": "ok",
    }


def _unavailable(filename: str, message: str) -> dict:
    return {
        "scan_id": str(uuid.uuid4()),
        "candidates": [],
        "needs_confirmation": True,
        "not_in_library": False,
        "name": "",
        "description": message,
        "equipment_slug": "unknown",
        "equipment_name": "",
        "confidence": 0.0,
        "visible_features": [],
        "model": settings.vision_model_name or "unavailable",
        "image_name": filename,
        "status": "unavailable",
        "warning": message,
    }


def _clamp_confidence(value) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return 0.0
    return max(0.0, min(1.0, number))
