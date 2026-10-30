"""Fail fast when the configured LLM key has no balance.

DeepSeek exposes /user/balance. If the endpoint is unavailable we let the run
continue; only a clear ``is_available: false`` blocks it.
"""

from __future__ import annotations

import httpx

from app.config import settings


async def check_balance() -> tuple[bool, str]:
    if settings.use_mock_llm:
        return False, "LLM is not configured"
    key = settings.llm_api_key
    base = settings.llm_base_url.rstrip("/")
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.get(
                f"{base}/user/balance",
                headers={"Authorization": f"Bearer {key}"},
            )
    except httpx.HTTPError as exc:
        return True, f"balance check unavailable: {str(exc)[:120]}"
    if response.status_code >= 400:
        return True, f"balance check HTTP {response.status_code}"
    try:
        data = response.json()
    except ValueError:
        return True, "balance check returned non-JSON"
    if data.get("is_available") is not False:
        return True, "balance available"
    balances = data.get("balance_infos") or []
    parts = [
        f"{item.get('currency', '?')} {item.get('total_balance', '?')}"
        for item in balances
        if isinstance(item, dict)
    ]
    detail = ", ".join(parts) or "unknown balance"
    return False, f"LLM balance unavailable: {detail}"
