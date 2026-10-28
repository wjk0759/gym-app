"""Stress test for POST /api/v1/body/analyze.

Vision is replaced with the local deterministic mock so this exercises the
HTTP route, multipart parsing, auth lookup, DB dependency and response
serialization without paying for real model calls.

Run from backend/:
    .venv/Scripts/python.exe scripts/stress_body_analysis.py
"""

from __future__ import annotations

import argparse
import asyncio
import base64
import sys
import time
from pathlib import Path

import httpx

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from app.deps import DEMO_USER_ID  # noqa: E402
from app.main import app  # noqa: E402
from app.routers import body as body_router  # noqa: E402
from app.services import body_analysis  # noqa: E402

PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
)


async def _fake_analyze(image_bytes: bytes, filename: str = "body.jpg") -> dict:
    # Keep the same shape as the real service, but do not call a paid vision model.
    return body_analysis._mock_analyze(image_bytes, filename)


async def run(requests: int, concurrency: int) -> int:
    body_router.analyze = _fake_analyze
    semaphore = asyncio.Semaphore(max(1, concurrency))
    latencies: list[float] = []
    failures: list[str] = []

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(
        transport=transport,
        base_url="http://stress.local",
        timeout=30,
    ) as client:
        async def one(index: int) -> None:
            async with semaphore:
                started = time.perf_counter()
                try:
                    response = await client.post(
                        "/api/v1/body/analyze",
                        headers={"X-User-Id": DEMO_USER_ID},
                        files={"file": ("body.jpg", PNG, "image/jpeg")},
                    )
                    elapsed = (time.perf_counter() - started) * 1000
                    latencies.append(elapsed)
                    if response.status_code != 200:
                        failures.append(f"#{index} HTTP {response.status_code}: {response.text[:160]}")
                    else:
                        payload = response.json()
                        if not payload.get("summary"):
                            failures.append(f"#{index} missing summary")
                except Exception as exc:  # noqa: BLE001 - collect and report all failures
                    failures.append(f"#{index} {type(exc).__name__}: {exc}")

        started = time.perf_counter()
        await asyncio.gather(*(one(i) for i in range(requests)))
        total = (time.perf_counter() - started) * 1000

    latencies.sort()

    def percentile(value: float) -> float:
        if not latencies:
            return 0.0
        index = min(len(latencies) - 1, round((len(latencies) - 1) * value))
        return latencies[index]

    print(
        f"requests={requests} concurrency={concurrency} "
        f"ok={len(latencies)} failed={len(failures)} "
        f"total={total:.0f}ms p50={percentile(0.50):.0f}ms "
        f"p95={percentile(0.95):.0f}ms max={(latencies[-1] if latencies else 0):.0f}ms"
    )
    if failures:
        for item in failures[:5]:
            print("FAIL", item)
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--requests", type=int, default=60)
    parser.add_argument("--concurrency", type=int, default=15)
    args = parser.parse_args()
    return asyncio.run(run(max(1, args.requests), max(1, args.concurrency)))


if __name__ == "__main__":
    raise SystemExit(main())
