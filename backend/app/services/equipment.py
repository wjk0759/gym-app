"""Equipment recognition: catalog-constrained vision, honest failures.

The catalog and the equipment->exercise mapping now live in the database
(``equipment_types`` / ``equipment_type_exercises``). The vision model picks one
fixed-machine type; the backend maps it to exercises from the DB.
"""

from __future__ import annotations

import base64
import logging
import uuid
from contextlib import suppress

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..models import (
    EquipmentLibraryItem,
    EquipmentType,
    EquipmentTypeExercise,
    Exercise,
    Profile,
    UserUniversalEquipment,
)
from . import llm

logger = logging.getLogger(__name__)

_TYPE_TO_EQUIPMENT = {
    "dumbbell": "dumbbell",
    "barbell": "barbell",
    "kettlebell": "kettlebell",
    "band": "band",
    "bodyweight": "bodyweight",
}
_CATEGORY_TO_EQUIPMENT = {
    "machine": "machine",
    "multi": "machine",
    "cable": "cable",
    "cardio": "bodyweight",
    "accessory": "other",
    "bodyweight": "bodyweight",
}
_UNIVERSAL_TO_EQUIPMENT = {
    "bodyweight": "bodyweight",
    "dumbbell": "dumbbell",
    "barbell": "barbell",
    "kettlebell": "kettlebell",
    "band": "band",
    "pullup": "bodyweight",
    "dip": "bodyweight",
    "battle_rope": "other",
    "medicine_ball": "other",
    "sled": "other",
}

_LEG_MACHINE_SLUGS = {
    "hack_squat",
    "leg_press",
    "leg_press_45",
    "leg_press_horizontal",
    "squat_press",
    "v_squat",
    "belt_squat",
    "pendulum_squat",
}

_ROW_MACHINE_SLUGS = [
    "seated_row",
    "seated_row_low",
    "seated_row_high",
    "row_combo",
    "lat_pulldown",
    "lat_pulldown_iso",
    "leverage_row",
    "chest_supported_row",
]

_SYSTEM_PROMPT = """你是叫练的健身器械识别助手。你只判断图片中的固定器械类型，并从给定目录中选择。
规则：
1. 只能选择目录中存在的 equipment_slug；看不清或不是固定器械时用 unknown。
2. 图片里有多台器械时，选择占据画面主体、最靠近镜头的那一台。
3. 不要靠品牌或颜色猜；优先看结构：座椅、靠背、脚踏板、配重片、滑轮、把手、轨道、绳索。
4. 只输出一个 JSON 对象，不要解释。"""


def catalog_types(db: Session, recognition_only: bool = False) -> list[EquipmentType]:
    query = select(EquipmentType).where(EquipmentType.is_active.is_(True))
    if recognition_only:
        query = query.where(EquipmentType.recognition_class.is_not(None))
    return list(db.execute(query).scalars().all())


def prompt_catalog(db: Session) -> str:
    lines = []
    for item in sorted(
        catalog_types(db, recognition_only=True),
        key=lambda row: row.recognition_class if row.recognition_class is not None else 999,
    ):
        aliases = " / ".join((item.aliases or [])[:3])
        lines.append(
            f"- {item.slug}（{item.name_zh}）"
            + (f"，也叫 {aliases}" if aliases else "")
        )
    return "\n".join(lines)


def match_name(db: Session, name: str | None) -> EquipmentType | None:
    if not name:
        return None
    text = name.strip().lower()
    if not text:
        return None
    for item in catalog_types(db):
        if text in item.name_zh.lower() or text in (item.name_en or "").lower():
            return item
        for alias in item.aliases or []:
            if text in str(alias).lower():
                return item
    return None


def catalog_get(db: Session, slug: str | None) -> EquipmentType | None:
    if not slug:
        return None
    return db.execute(
        select(EquipmentType).where(EquipmentType.slug == slug)
    ).scalar_one_or_none()


def catalog_exercises(db: Session, item: EquipmentType) -> list[str]:
    return list(
        db.execute(
            select(EquipmentTypeExercise.exercise_slug).where(
                EquipmentTypeExercise.equipment_type_slug == item.slug
            )
        )
        .scalars()
        .all()
    )


def _user_prompt(db: Session, ocr_text: str = "") -> str:
    ocr_block = ""
    if ocr_text:
        hint = match_name(db, ocr_text)
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
    return f"""器械目录（79 类固定器械）：
{prompt_catalog(db)}
{ocr_block}
识别这张照片，严格输出 JSON：
{{
  "is_gym_equipment": true,
  "equipment_slug": "目录里的 slug 或 unknown",
  "equipment_name": "中文名",
  "confidence": 0.0,
  "equipment_candidates": [
    {{"slug": "最可能的目录 slug", "confidence": 0.0}},
    {{"slug": "第二可能的目录 slug", "confidence": 0.0}}
  ],
  "visible_features": ["看到的 2-4 个结构特征"],
  "description": "一句话说明"
}}
如果不是固定器械：equipment_slug 用 "unknown"，equipment_candidates 输出 []，description 如实说明。
不确定时输出两个最接近的候选。"""


def available_equipment_types(
    db: Session,
    user_id: str,
    profile_equipment: list[str] | None,
) -> list[str]:
    """Exercise-equipment categories the user can actually use.

    ``user_equipment`` stores the equipment-type category (machine/cable/multi/
    free_weight/...), while ``exercises.equipment`` uses the exercise category
    (machine/cable/dumbbell/barbell/...). This maps the former to the latter so
    plan validation and fallback use the same vocabulary.
    """
    rows = (
        db.execute(
            select(
                EquipmentLibraryItem.equipment_type,
                EquipmentLibraryItem.category,
                EquipmentLibraryItem.equipment,
            ).where(EquipmentLibraryItem.user_id == user_id)
        )
        .all()
    )
    types: set[str] = set()
    for type_slug, category, equipment in rows:
        mapped = _TYPE_TO_EQUIPMENT.get(str(type_slug or ""))
        if mapped is None:
            mapped = _CATEGORY_TO_EQUIPMENT.get(str(category or ""))
        if mapped is None and equipment:
            mapped = str(equipment)
        if mapped:
            types.add(mapped)

    universal = (
        db.execute(
            select(UserUniversalEquipment.equipment_slug).where(
                UserUniversalEquipment.user_id == user_id,
                UserUniversalEquipment.enabled.is_(True),
            )
        )
        .scalars()
        .all()
    )
    for slug in universal:
        mapped = _UNIVERSAL_TO_EQUIPMENT.get(str(slug))
        if mapped:
            types.add(mapped)

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


def _build_option(db: Session, item: EquipmentType, confidence: float) -> dict | None:
    slugs = catalog_exercises(db, item)
    rows = {
        e.slug: e
        for e in _active_exercises(db)
        if e.slug in set(slugs)
    }
    ordered = sorted(
        slugs,
        key=lambda s: (not rows[s].is_compound if s in rows else True, s),
    )

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
                "confidence": round(max(0.30, confidence - index * 0.05), 2),
                "video_url": exercise.video_url,
            }
        )
        if len(candidates) == 6:
            break

    if not candidates:
        return None
    return {
        "slug": item.slug,
        "name_zh": item.name_zh,
        "confidence": round(confidence, 2),
        "candidates": candidates,
    }


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
            _user_prompt(db, ocr_text),
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

    mapped = _map_result(db, result, filename, ocr_text=ocr_text)
    if _unique_ocr_match(db, ocr_text) is not None:
        return mapped
    return await _apply_row_gate(db, mapped, image_bytes, user_id=user_id)


def _normalize_match_text(value: str | None) -> str:
    return " ".join(str(value or "").strip().lower().split())


def _unique_ocr_match(db: Session, text: str | None) -> EquipmentType | None:
    """Return the one catalog type a printed label clearly names.

    OCR is only trusted when it contains a complete, specific machine name.
    Generic words such as "LEG PRESS" match several catalog entries and are
    deliberately ignored so OCR cannot override the visual model by itself.
    """
    normalized = _normalize_match_text(text)
    if len(normalized) < 4:
        return None

    matches: list[EquipmentType] = []
    for item in catalog_types(db):
        best = 0
        for value in [item.name_zh, item.name_en, *(item.aliases or [])]:
            candidate = _normalize_match_text(value)
            if not candidate:
                continue
            if candidate in normalized or normalized in candidate:
                best = max(best, len(candidate))
        # Specific labels only: "SEATED ROW" / "坐姿划船机", not "ROW"/"LEG PRESS".
        if best >= 5:
            matches.append(item)

    # A label that could mean several catalog types is not a specific label.
    if len(matches) != 1:
        return None
    return matches[0]


def _map_result(
    db: Session,
    result: dict,
    filename: str,
    ocr_text: str = "",
) -> dict:
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
            "description": description or "未识别到固定器械。",
            "equipment_slug": "unknown",
            "equipment_name": equipment_name,
            "confidence": confidence,
            "visible_features": features,
            "model": settings.vision_model_name,
            "image_name": filename,
            "status": "not_gym_equipment",
        }

    model_item = (
        catalog_get(db, equipment_slug)
        or match_name(db, equipment_name)
        or match_name(db, str(result.get("name") or ""))
    )
    # A printed machine label is a much stronger signal than the VLM's guess.
    # Only use it when it maps to exactly one specific catalog type.
    ocr_item = _unique_ocr_match(db, ocr_text)
    item = ocr_item or model_item
    if item is None:
        return {
            "scan_id": str(uuid.uuid4()),
            "candidates": [],
            "needs_confirmation": True,
            "not_in_library": True,
            "name": equipment_name or "未收录器械",
            "description": description
            or f"识别到「{equipment_name or '器械'}」，但当前目录未收录。",
            "equipment_slug": equipment_slug or "unknown",
            "equipment_name": equipment_name,
            "confidence": confidence,
            "visible_features": features,
            "model": settings.vision_model_name,
            "image_name": filename,
            "status": "unknown_equipment",
        }

    raw_options = result.get("equipment_candidates")
    if not isinstance(raw_options, list) or not raw_options:
        raw_options = [{"slug": equipment_slug, "confidence": confidence}]

    options: list[dict] = []
    seen: set[str] = set()

    # A specific printed label is the strongest signal. Without one, keep the
    # previous candidate-first order: the model's shortlist is noisy, but its
    # top-level slug is even more biased toward hack_squat on leg machines.
    if ocr_item is not None:
        primary_option = _build_option(db, ocr_item, 0.95)
        if primary_option is not None:
            options.append(primary_option)
            seen.add(ocr_item.slug)

    for raw in raw_options[:2]:
        if not isinstance(raw, dict):
            continue
        raw_slug = str(raw.get("slug") or "").strip().lower()
        raw_confidence = _clamp_confidence(raw.get("confidence", confidence))
        option_item = catalog_get(db, raw_slug)
        if option_item is None or option_item.slug in seen:
            continue
        seen.add(option_item.slug)
        option = _build_option(db, option_item, raw_confidence)
        if option is not None:
            options.append(option)

    # Keep the VLM's top-level answer as a manual alternative when it differs
    # from the candidate list. The app shows the candidates first (the old
    # behavior is safer for leg presses) but the user can switch in one tap.
    if model_item is not None and model_item.slug not in seen:
        model_option = _build_option(db, model_item, confidence)
        if model_option is not None:
            options.append(model_option)
            seen.add(model_item.slug)

    if len(options) > 1:
        top_confidence = options[0]["confidence"]
        if options[1]["confidence"] < max(0.35, top_confidence - 0.35):
            options = options[:1]

    if not options:
        return {
            "scan_id": str(uuid.uuid4()),
            "candidates": [],
            "equipment_candidates": [],
            "needs_confirmation": True,
            "not_in_library": True,
            "name": item.name_zh,
            "description": description
            or f"识别到「{item.name_zh}」，但动作库暂未收录其示范动作。",
            "equipment_slug": item.slug,
            "equipment_name": item.name_zh,
            "confidence": confidence,
            "visible_features": features,
            "model": settings.vision_model_name,
            "image_name": filename,
            "status": "no_actions",
        }

    top = options[0]
    needs_confirmation = len(options) > 1 or top["confidence"] < 0.6
    logger.info(
        "equipment scan model=%s ocr=%s primary=%s options=%s",
        equipment_slug or "-",
        bool(ocr_item),
        top["slug"],
        [option["slug"] for option in options[:3]],
    )

    return {
        "scan_id": str(uuid.uuid4()),
        "candidates": top["candidates"],
        "equipment_candidates": options,
        "needs_confirmation": needs_confirmation,
        "not_in_library": False,
        "name": top["name_zh"],
        "description": description or f"识别到「{top['name_zh']}」。",
        "equipment_slug": top["slug"],
        "equipment_name": top["name_zh"],
        "confidence": top["confidence"],
        "visible_features": features,
        "model": settings.vision_model_name,
        "image_name": filename,
        "status": "ok",
    }


async def _apply_row_gate(
    db: Session,
    result: dict,
    image_bytes: bytes,
    *,
    user_id: str | None = None,
) -> dict:
    """Second opinion for the row-vs-leg confusion.

    Qwen3-VL-Plus often returns hack_squat/leg_press for a seated row. The
    activated Doubao lite model answers the much simpler binary question
    reliably and quickly. Only run for ambiguous leg machines, and only when
    OCR did not already provide a specific machine name.
    """
    if not getattr(settings, "vision_gate_enabled", False):
        return result
    if result.get("status") != "ok":
        return result
    if result.get("equipment_slug") not in _LEG_MACHINE_SLUGS:
        return result
    if not (
        settings.vision_gate_base_url
        and settings.vision_gate_model
        and settings.vision_gate_api_key
    ):
        return result

    try:
        answer = await llm.complete_secondary_vision_text(
            "You are a precise gym equipment inspector. Answer with two words max.",
            (
                "Look at the machine. Is it a seated pulling machine with a "
                "chest pad and handles pulled toward the torso, or a leg "
                "press/hack squat with a foot plate and shoulder pads? "
                "Answer exactly: seated_pull or leg_press."
            ),
            base64.b64encode(image_bytes).decode(),
            base_url=settings.vision_gate_base_url,
            model=settings.vision_gate_model,
            api_key=settings.vision_gate_api_key,
            timeout=settings.vision_gate_timeout_seconds,
            db=db,
            user_id=user_id,
        )
    except Exception as exc:  # noqa: BLE001 - gate is best-effort
        logger.warning("equipment row gate failed: %s", exc)
        return result

    normalized = answer.lower()
    row_signal = (
        "seated_pull" in normalized
        or "seated pull" in normalized
        or ("seated" in normalized and "pull" in normalized)
    )
    if not row_signal:
        return result

    row_options: list[dict] = []
    seen: set[str] = set()
    for index, slug in enumerate(_ROW_MACHINE_SLUGS):
        item = catalog_get(db, slug)
        if item is None or item.slug in seen:
            continue
        option = _build_option(db, item, 0.9 if index == 0 else 0.6)
        if option is None:
            continue
        row_options.append(option)
        seen.add(item.slug)

    if not row_options:
        return result

    for option in result.get("equipment_candidates") or []:
        slug = str(option.get("slug") or "")
        if not slug or slug in seen:
            continue
        row_options.append(option)
        seen.add(slug)

    top = row_options[0]
    updated = dict(result)
    updated.update(
        {
            "candidates": top["candidates"],
            "equipment_candidates": row_options,
            "needs_confirmation": True,
            "not_in_library": False,
            "name": top["name_zh"],
            "equipment_slug": top["slug"],
            "equipment_name": top["name_zh"],
            "confidence": max(0.9, top["confidence"]),
            "description": (
                "豆包视觉复核判断更像坐姿划船机，已优先展示划船动作。"
            ),
            "warning": (
                "这类器械容易和腿举/哈克深蹲混淆；如果不对，"
                "可从器械库选择。"
            ),
            "status": "ok",
        }
    )
    logger.info(
        "equipment row gate switched %s -> %s",
        result.get("equipment_slug"),
        top["slug"],
    )
    return updated


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
