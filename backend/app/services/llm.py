from __future__ import annotations

import asyncio
import json
import logging
import time
from contextlib import suppress

import httpx
from sqlalchemy.orm import Session

from ..config import settings
from ..models import AIJob
from . import llm_budget

logger = logging.getLogger(__name__)


class LLMError(RuntimeError):
    pass


def _merge_usage(target: dict | None, usage: dict | None) -> None:
    """Accumulate provider usage into one JSON-safe dict.

    DeepSeek reports cache hits in ``prompt_cache_hit_tokens``; some compatible
    providers only expose ``prompt_tokens_details.cached_tokens``. Keep both so
    calibration can price input correctly.
    """
    if target is None or not isinstance(usage, dict):
        return
    target["calls"] = int(target.get("calls", 0)) + 1
    for key in (
        "prompt_tokens",
        "completion_tokens",
        "total_tokens",
        "prompt_cache_hit_tokens",
        "prompt_cache_miss_tokens",
    ):
        value = usage.get(key)
        if isinstance(value, (int, float)):
            target[key] = int(target.get(key, 0)) + int(value)

    details = usage.get("prompt_tokens_details")
    if isinstance(details, dict):
        cached = details.get("cached_tokens")
        if isinstance(cached, (int, float)):
            target["prompt_tokens_details"] = {
                "cached_tokens": int(
                    (target.get("prompt_tokens_details") or {}).get("cached_tokens", 0)
                )
                + int(cached)
            }


def _usage_tokens(usage: dict | None) -> tuple[int, int]:
    if not isinstance(usage, dict):
        return 0, 0
    input_tokens = usage.get("prompt_tokens")
    output_tokens = usage.get("completion_tokens")
    return (
        int(input_tokens) if isinstance(input_tokens, (int, float)) else 0,
        int(output_tokens) if isinstance(output_tokens, (int, float)) else 0,
    )


def _budget_guard(db: Session | None, user_id: str | None = None) -> None:
    if db is None:
        return
    try:
        llm_budget.ensure_ai_enabled(db, user_id)
        llm_budget.ensure_budget(db)
    except llm_budget.AIUnavailable as exc:
        logger.warning("AI runtime paused: %s", exc)
        raise LLMError(str(exc)) from exc
    except llm_budget.BudgetExceeded as exc:
        logger.error("LLM budget exhausted: %s", exc)
        raise LLMError(str(exc)) from exc


def _record_success(
    db: Session | None,
    user_id: str | None,
    kind: str | None,
    model: str | None,
    started: float,
    usage: dict | None,
) -> None:
    if db is None or not kind:
        return
    record_job(
        db,
        user_id,
        kind=kind,
        status="ok",
        model=model,
        latency_ms=int((time.perf_counter() - started) * 1000),
        usage=usage,
    )


# 复用连接池，避免每次对话/计划生成都重新做 TLS 握手。
_client: httpx.AsyncClient | None = None
_semaphore: asyncio.Semaphore | None = None


def _get_semaphore() -> asyncio.Semaphore:
    global _semaphore
    if _semaphore is None:
        _semaphore = asyncio.Semaphore(max(1, settings.llm_max_concurrency))
    return _semaphore


def _get_client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        _client = httpx.AsyncClient(
            timeout=httpx.Timeout(settings.llm_timeout_seconds, connect=10.0),
            limits=httpx.Limits(
                max_connections=max(20, settings.llm_max_concurrency * 2),
                max_keepalive_connections=max(10, settings.llm_max_concurrency),
                keepalive_expiry=30.0,
            ),
        )
    return _client


async def _post(payload: dict) -> httpx.Response:
    async with _get_semaphore():
        return await _get_client().post(
            _endpoint(), headers=_headers(), json=payload
        )


async def close_client() -> None:
    global _client, _semaphore
    if _client is not None:
        await _client.aclose()
        _client = None
    _semaphore = None


def _headers() -> dict[str, str]:
    return {
        "Authorization": f"Bearer {settings.llm_api_key}",
        "Content-Type": "application/json",
    }


def _endpoint() -> str:
    return settings.llm_base_url.rstrip("/") + "/chat/completions"


def _vision_headers() -> dict[str, str]:
    key = settings.vision_api_key or settings.llm_api_key
    return {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }


def _vision_endpoint() -> str:
    base = settings.vision_base_url or settings.llm_base_url
    return base.rstrip("/") + "/chat/completions"


async def complete_vision_json(
    system: str,
    user_text: str,
    image_base64: str | list[str],
    mime: str = "image/jpeg",
    usage: dict | None = None,
    db: Session | None = None,
    user_id: str | None = None,
    kind: str = "vision",
    temperature: float = 0.2,
) -> dict:
    """One or more images -> one JSON response using the vision model."""
    if settings.use_mock_vision:
        raise LLMError("mock vision: no vision model configured")
    _budget_guard(db, user_id)
    started = time.perf_counter()
    images = [image_base64] if isinstance(image_base64, str) else list(image_base64)
    if not images:
        raise LLMError("no images provided")

    messages = [
        {"role": "system", "content": system},
        {
            "role": "user",
            "content": [
                {"type": "text", "text": user_text},
                *[
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:{mime};base64,{encoded}"},
                    }
                    for encoded in images
                ],
            ],
        },
    ]
    payload = {
        "model": settings.vision_model_name,
        "messages": messages,
        "temperature": temperature,
        "response_format": {"type": "json_object"},
    }
    last_error: Exception | None = None
    for attempt in range(2):
        try:
            async with _get_semaphore():
                response = await _get_client().post(
                    _vision_endpoint(), headers=_vision_headers(), json=payload
                )
        except httpx.TransportError as exc:
            last_error = exc
            if attempt == 0:
                await asyncio.sleep(0.6)
                continue
            logger.warning("vision network error: %s", exc)
            raise LLMError("vision network error") from exc

        if response.status_code >= 400:
            if response.status_code == 400 and "response_format" in payload:
                payload.pop("response_format", None)
                try:
                    async with _get_semaphore():
                        response = await _get_client().post(
                            _vision_endpoint(), headers=_vision_headers(), json=payload
                        )
                except httpx.TransportError as exc:
                    last_error = exc
                    if attempt == 0:
                        await asyncio.sleep(0.6)
                        continue
                    logger.warning("vision network error: %s", exc)
                    raise LLMError("vision network error") from exc
            if response.status_code in {429, 500, 502, 503, 504} and attempt == 0:
                await asyncio.sleep(0.8)
                continue
            logger.warning(
                "vision HTTP %s: %s", response.status_code, response.text[:300]
            )
            raise LLMError(
                f"vision HTTP {response.status_code}: {response.text[:300]}"
            )

        try:
            data = response.json()
            _merge_usage(usage, data.get("usage"))
            content = data["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            last_error = exc
            if attempt == 0:
                await asyncio.sleep(0.4)
                continue
            raise LLMError("unexpected vision response shape") from exc

        try:
            parsed = _parse_json_object(content)
            _record_success(
                db, user_id, kind, settings.vision_model_name, started, usage
            )
            return parsed
        except LLMError as exc:
            last_error = exc
            if attempt == 0:
                await asyncio.sleep(0.3)
                continue
            raise

    logger.warning("vision JSON retry failed: %s", last_error)
    raise LLMError("vision JSON retry failed")


async def complete_secondary_vision_text(
    system: str,
    user_text: str,
    image_base64: str,
    *,
    base_url: str,
    model: str,
    api_key: str,
    timeout: float = 20.0,
    db: Session | None = None,
    user_id: str | None = None,
    kind: str = "equipment_gate",
) -> str:
    """Ask a second vision model a short, text-only question.

    Used for the row-vs-leg gate. Deliberately not JSON mode: a two-word
    answer is faster and more reliable on the Doubao lite model.
    """
    if not (base_url and model and api_key):
        raise LLMError("secondary vision is not configured")

    endpoint = base_url.rstrip("/") + "/chat/completions"
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": user_text},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": "data:image/jpeg;base64," + image_base64
                        },
                    },
                ],
            },
        ],
        "temperature": 0.0,
    }
    started = time.perf_counter()
    async with _get_semaphore():
        response = await _get_client().post(
            endpoint,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=timeout,
        )
    if response.status_code >= 400:
        raise LLMError(
            f"secondary vision HTTP {response.status_code}: {response.text[:200]}"
        )
    try:
        data = response.json()
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError, ValueError) as exc:
        raise LLMError("unexpected secondary vision response") from exc

    if db is not None:
        with suppress(Exception):
            _record_success(
                db,
                user_id,
                kind,
                model,
                started,
                data.get("usage"),
            )
    return str(content or "").strip()


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

    logger.warning("LLM returned invalid JSON: %s", content[:300])
    raise LLMError("LLM returned invalid JSON")


async def complete_json(
    system: str,
    user: str,
    *,
    reasoning_effort: str | None = None,
    usage: dict | None = None,
    db: Session | None = None,
    user_id: str | None = None,
    kind: str = "llm",
) -> dict:
    if settings.use_mock_llm:
        raise LLMError("mock mode: no LLM key configured")
    _budget_guard(db, user_id)
    started = time.perf_counter()

    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": user},
    ]
    requested_effort = reasoning_effort or settings.llm_reasoning_effort
    for attempt in range(3):
        payload = {
            "model": settings.llm_model,
            "messages": messages,
            "temperature": 0.0 if attempt >= 2 else 0.3,
            "reasoning_effort": "low" if attempt >= 2 else requested_effort,
            "response_format": {"type": "json_object"},
        }
        try:
            response = await _post(payload)
        except httpx.TransportError as exc:
            if attempt == 0:
                await asyncio.sleep(0.6)
                continue
            logger.warning("LLM network error: %s", exc)
            raise LLMError("LLM network error") from exc

        if response.status_code >= 400:
            # Some compatible endpoints do not support response_format.
            if response.status_code == 400 and "response_format" in payload:
                payload.pop("response_format", None)
                try:
                    response = await _post(payload)
                except httpx.TransportError as exc:
                    if attempt == 0:
                        await asyncio.sleep(0.6)
                        continue
                    logger.warning("LLM network error: %s", exc)
                    raise LLMError("LLM network error") from exc

            if response.status_code in {429, 500, 502, 503, 504} and attempt == 0:
                await asyncio.sleep(0.8)
                continue
            logger.warning(
                "LLM HTTP %s: %s", response.status_code, response.text[:300]
            )
            raise LLMError(f"LLM HTTP {response.status_code}")

        try:
            data = response.json()
            _merge_usage(usage, data.get("usage"))
            content = data["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            if attempt == 0:
                await asyncio.sleep(0.4)
                continue
            raise LLMError("unexpected LLM response shape") from exc

        try:
            parsed = _parse_json_object(content)
            _record_success(db, user_id, kind, settings.llm_model, started, usage)
            return parsed
        except LLMError:
            if attempt < 2:
                # Ask once for a single object; this handles models that emit
                # two tool decisions in one response. The final retry drops
                # temperature and reasoning effort because an empty or
                # truncated JSON object is usually a decoding/format failure.
                correction = (
                    "上一次输出不是单个合法 JSON 对象。"
                    "请只输出一个 JSON 对象，不要输出多个对象、Markdown 或解释。"
                    if attempt == 0
                    else "上次仍然没有返回合法 JSON。请只输出一个最短的 JSON 对象。"
                )
                messages = [
                    *messages,
                    {"role": "user", "content": correction},
                ]
                await asyncio.sleep(0.3)
                continue
            raise

    raise LLMError("LLM JSON retry failed")


async def complete_text(
    messages: list[dict],
    temperature: float = 0.5,
    usage: dict | None = None,
    db: Session | None = None,
    user_id: str | None = None,
    kind: str = "llm",
    max_tokens: int | None = None,
    reasoning_effort: str | None = None,
) -> str:
    if settings.use_mock_llm:
        raise LLMError("mock mode: no LLM key configured")
    _budget_guard(db, user_id)
    started = time.perf_counter()

    payload = {
        "model": settings.llm_model,
        "messages": messages,
        "temperature": temperature,
        "reasoning_effort": (
            reasoning_effort or settings.llm_reasoning_effort
        ),
    }
    if max_tokens is not None:
        payload["max_tokens"] = max(1, max_tokens)
    for attempt in range(2):
        try:
            response = await _post(payload)
        except httpx.TransportError as exc:
            if attempt == 0:
                await asyncio.sleep(0.6)
                continue
            logger.warning("LLM network error: %s", exc)
            raise LLMError("LLM network error") from exc

        if response.status_code in {429, 500, 502, 503, 504} and attempt == 0:
            await asyncio.sleep(0.8)
            continue
        if response.status_code >= 400:
            logger.warning(
                "LLM HTTP %s: %s", response.status_code, response.text[:300]
            )
            raise LLMError(f"LLM HTTP {response.status_code}")
        try:
            data = response.json()
            _merge_usage(usage, data.get("usage"))
            content = data["choices"][0]["message"]["content"]
            _record_success(db, user_id, kind, settings.llm_model, started, usage)
            return content
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            if attempt == 0:
                await asyncio.sleep(0.4)
                continue
            raise LLMError("unexpected LLM response shape") from exc

    raise LLMError("LLM text retry failed")


def record_job(
    db: Session,
    user_id: str | None,
    kind: str,
    status: str,
    model: str | None = None,
    latency_ms: int | None = None,
    error: str | None = None,
    usage: dict | None = None,
) -> None:
    input_tokens, output_tokens = _usage_tokens(usage)
    db.add(
        AIJob(
            user_id=user_id,
            kind=kind,
            status=status,
            model=model,
            latency_ms=latency_ms,
            input_tokens=input_tokens or None,
            output_tokens=output_tokens or None,
            error=(error or "")[:1000] or None,
            prompt_version="v1",
        )
    )
    db.commit()
