from __future__ import annotations

import asyncio
import json
import logging
import time

import httpx
from sqlalchemy.orm import Session

from ..config import settings
from ..models import AIJob


logger = logging.getLogger(__name__)


class LLMError(RuntimeError):
    pass


# 复用连接池，避免每次对话/计划生成都重新做 TLS 握手。
_client: httpx.AsyncClient | None = None


def _get_client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        _client = httpx.AsyncClient(
            timeout=httpx.Timeout(90.0, connect=10.0),
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


def _parse_json_object(content: str) -> dict:
    """Parse one JSON object even if the model emits several concatenated objects.

    DeepSeek occasionally returns ``{...}\\n{...}`` despite JSON mode. The last
    complete object is the most recent tool decision, so use it and keep the
    Agent loop alive instead of turning a formatting mistake into a 500.
    """
    text = _strip_fences(content)
    start = text.find("{")
    if start > 0:
        text = text[start:]

    try:
        parsed = json.loads(text)
        if isinstance(parsed, dict):
            return parsed
    except json.JSONDecodeError:
        pass

    decoder = json.JSONDecoder()
    objects: list[dict] = []
    index = 0
    while index < len(text):
        while index < len(text) and text[index] in " \r\n\t,":
            index += 1
        if index >= len(text) or text[index] != "{":
            break
        try:
            value, end = decoder.raw_decode(text, index)
        except json.JSONDecodeError:
            break
        if isinstance(value, dict):
            objects.append(value)
        index = end

    if objects:
        logger.warning("LLM returned %d JSON objects; using the last one", len(objects))
        return objects[-1]

    raise LLMError(f"LLM returned invalid JSON: {content[:200]}")


async def complete_json(system: str, user: str) -> dict:
    if settings.use_mock_llm:
        raise LLMError("mock mode: no LLM key configured")

    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": user},
    ]
    last_error: Exception | None = None
    for attempt in range(2):
        payload = {
            "model": settings.llm_model,
            "messages": messages,
            "temperature": 0.3,
            "reasoning_effort": settings.llm_reasoning_effort,
            "response_format": {"type": "json_object"},
        }
        try:
            response = await _get_client().post(
                _endpoint(), headers=_headers(), json=payload
            )
        except httpx.TransportError as exc:
            last_error = exc
            if attempt == 0:
                await asyncio.sleep(0.6)
                continue
            raise LLMError(f"LLM network error: {str(exc)[:300]}") from exc

        if response.status_code >= 400:
            # Some compatible endpoints do not support response_format.
            if response.status_code == 400 and "response_format" in payload:
                payload.pop("response_format", None)
                try:
                    response = await _get_client().post(
                        _endpoint(), headers=_headers(), json=payload
                    )
                except httpx.TransportError as exc:
                    last_error = exc
                    if attempt == 0:
                        await asyncio.sleep(0.6)
                        continue
                    raise LLMError(f"LLM network error: {str(exc)[:300]}") from exc

            if response.status_code in {429, 500, 502, 503, 504} and attempt == 0:
                await asyncio.sleep(0.8)
                continue
            raise LLMError(
                f"LLM HTTP {response.status_code}: {response.text[:300]}"
            )

        try:
            data = response.json()
            content = data["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            last_error = exc
            if attempt == 0:
                await asyncio.sleep(0.4)
                continue
            raise LLMError("unexpected LLM response shape") from exc

        try:
            return _parse_json_object(content)
        except LLMError as exc:
            last_error = exc
            if attempt == 0:
                # Ask once for a single object; this handles models that emit
                # two tool decisions in one response.
                messages = messages + [
                    {
                        "role": "user",
                        "content": (
                            "上一次输出不是单个合法 JSON 对象。"
                            "请只输出一个 JSON 对象，不要输出多个对象、Markdown 或解释。"
                        ),
                    }
                ]
                await asyncio.sleep(0.3)
                continue
            raise

    raise LLMError(f"LLM JSON retry failed: {last_error}")


async def complete_text(messages: list[dict], temperature: float = 0.5) -> str:
    if settings.use_mock_llm:
        raise LLMError("mock mode: no LLM key configured")

    payload = {
        "model": settings.llm_model,
        "messages": messages,
        "temperature": temperature,
        "reasoning_effort": settings.llm_reasoning_effort,
    }
    last_error: Exception | None = None
    for attempt in range(2):
        try:
            response = await _get_client().post(
                _endpoint(), headers=_headers(), json=payload
            )
        except httpx.TransportError as exc:
            last_error = exc
            if attempt == 0:
                await asyncio.sleep(0.6)
                continue
            raise LLMError(f"LLM network error: {str(exc)[:300]}") from exc

        if response.status_code in {429, 500, 502, 503, 504} and attempt == 0:
            await asyncio.sleep(0.8)
            continue
        if response.status_code >= 400:
            raise LLMError(
                f"LLM HTTP {response.status_code}: {response.text[:300]}"
            )
        try:
            return response.json()["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            last_error = exc
            if attempt == 0:
                await asyncio.sleep(0.4)
                continue
            raise LLMError("unexpected LLM response shape") from exc

    raise LLMError(f"LLM text retry failed: {last_error}")


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
