"""Semantic fallback router for coach capabilities.

Deterministic resolvers stay the fast path. This module is only called when
the fast path falls through to free chat but the message still looks like an
action request. The model chooses from the registered capability manifest; it
never writes data and never builds payloads.
"""

from __future__ import annotations

import json

from ...config import settings
from .. import llm
from ..prompt_registry import prompt_version
from . import capabilities  # noqa: F401 - registers capabilities
from .manifest import spec_for
from .registry import CAPABILITIES

_SYSTEM_PROMPT = (
    "你是叫练 App 的 AI 教练意图路由器。"
    "用户会用中文口语、错别字、不同标点或空格描述一个动作请求。"
    "请从能力清单中选择最匹配的一个能力。"
    "只负责选择能力，不执行、不写数据库、不生成参数。"
    "如果只是普通知识问答、闲聊、情绪表达，capability_id 返回 null。"
    "如果一句话有多个动作，只选最主要的一个；后续系统会处理组合。"
    "信息不完整也要返回最接近的能力，后续能力会追问。"
    "只输出 JSON："
    '{"capability_id": "diet.log_food" 或 null, "confidence": 0.0, "reason": "短句"}。'
)
_PROMPT_VERSION = prompt_version("coach_intent_router", _SYSTEM_PROMPT)


def _capability_catalog() -> list[dict]:
    items = []
    for capability in CAPABILITIES.values():
        if capability.id == "coach.answer":
            continue
        spec = spec_for(capability.id)
        items.append(
            {
                "id": capability.id,
                "domain": capability.domain,
                "kind": capability.kind,
                "title": capability.title,
                "description": capability.description,
                "examples": list(spec.examples) if spec else [],
                "slots": list(spec.slots) if spec else [],
            }
        )
    return items


async def route_intent(
    db,
    user_id: str,
    message: str,
    *,
    history_context: str | None = None,
) -> str | None:
    """Return a capability id, or None when the message is not an action."""
    if settings.use_mock_llm:
        return None
    catalog = _capability_catalog()
    payload = json.dumps(
        {
            "message": message[:1000],
            "history": (history_context or "")[:2000],
            "capabilities": catalog,
        },
        ensure_ascii=False,
    )
    try:
        raw = await llm.complete_json(
            _SYSTEM_PROMPT,
            payload,
            reasoning_effort="low",
            db=db,
            user_id=user_id,
            kind="coach_intent_router",
            prompt_version=_PROMPT_VERSION,
        )
    except Exception:  # noqa: BLE001 - router failure must fall back to chat
        return None
    if not isinstance(raw, dict):
        return None
    capability_id = str(raw.get("capability_id") or "").strip()
    if not capability_id or capability_id not in CAPABILITIES:
        return None
    if capability_id == "coach.answer":
        return None
    try:
        confidence = float(raw.get("confidence") or 0)
    except (TypeError, ValueError):
        confidence = 0.0
    if confidence < 0.55:
        return None
    return capability_id
