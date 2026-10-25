from __future__ import annotations

import json
import time

import httpx
from sqlalchemy.orm import Session

from ..config import settings
from ..models import AIJob


class LLMError(RuntimeError):
    pass


# 复用连接池，避免每次对话/计划生成都重新做 TLS 握手。
_client: httpx.AsyncClient | None = None


def _get_client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        _client = httpx.AsyncClient(
            timeout=httpx.Timeout(45.0, connect=10.0),
            limits=httpx.Limits(
                max_connections=40,
                max_keepalive_connections=20,
                keepalive_expiry=30.0,
            ),
        )
    return _client


async def close_client() -> None:
    global _client
    if _client is not None:
        await _client.aclose()
        _client = None


def _headers() -> dict[str, str]:
    return {
        "Authorization": f"Bearer {settings.llm_api_key}",
        "Content-Type": "application/json",
    }


def _endpoint() -> str:
    return settings.llm_base_url.rstrip("/") + "/chat/completions"


def _strip_fences(content: str) -> str:
    text = content.strip()
    if text.startswith("```"):
        lines = text.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        text = "\n".join(lines).strip()
    return text


async def complete_json(system: str, user: str) -> dict:
    if settings.use_mock_llm:
        raise LLMError("mock mode: no LLM key configured")

    payload = {
        "model": settings.llm_model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": 0.3,
        "response_format": {"type": "json_object"},
    }

    client = _get_client()
    response = await client.post(_endpoint(), headers=_headers(), json=payload)
    if response.status_code >= 400:
        # 部分兼容接口不支持 response_format，退化为普通请求
        payload.pop("response_format", None)
        response = await client.post(_endpoint(), headers=_headers(), json=payload)
    if response.status_code >= 400:
        raise LLMError(f"LLM HTTP {response.status_code}: {response.text[:300]}")

    data = response.json()
    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise LLMError("unexpected LLM response shape") from exc

    try:
        return json.loads(_strip_fences(content))
    except json.JSONDecodeError as exc:
        raise LLMError(f"LLM returned invalid JSON: {content[:200]}") from exc


async def complete_text(messages: list[dict], temperature: float = 0.5) -> str:
    if settings.use_mock_llm:
        raise LLMError("mock mode: no LLM key configured")

    payload = {
        "model": settings.llm_model,
        "messages": messages,
        "temperature": temperature,
    }
    response = await _get_client().post(
        _endpoint(), headers=_headers(), json=payload
    )
    if response.status_code >= 400:
        raise LLMError(f"LLM HTTP {response.status_code}: {response.text[:300]}")
    try:
        return response.json()["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise LLMError("unexpected LLM response shape") from exc


def record_job(
    db: Session,
    user_id: str | None,
    kind: str,
    status: str,
    model: str | None = None,
    latency_ms: int | None = None,
    error: str | None = None,
) -> None:
    db.add(
        AIJob(
            user_id=user_id,
            kind=kind,
            status=status,
            model=model,
            latency_ms=latency_ms,
            error=(error or "")[:1000] or None,
            prompt_version="v1",
        )
    )
    db.commit()


def timed() -> float:
    return time.perf_counter()
