"""Closed-loop API latency probe for a running backend.

Examples (development X-User-Id auth):
    python scripts/bench_api.py --user-id <uuid> --requests 200 --concurrency 20

Use this before/after a backend change. It intentionally measures complete
request round trips, including FastAPI, SQLAlchemy, JSON and gzip.
"""

from __future__ import annotations

import argparse
import asyncio
import statistics
import time

import httpx

READ_ENDPOINTS = [
    ("me", "/api/v1/me"),
    ("plans/current", "/api/v1/plans/current"),
    ("workouts", "/api/v1/workouts?limit=20"),
    ("workouts+sets", "/api/v1/workouts?limit=20&include_sets=true"),
    ("workout summary", "/api/v1/workouts/summary?weeks=4"),
    ("diet logs", "/api/v1/diet/logs"),
    ("body metrics", "/api/v1/body/metrics"),
]


async def one(client: httpx.AsyncClient, url: str, headers: dict) -> tuple[int, float]:
    started = time.perf_counter()
    response = await client.get(url, headers=headers)
    return response.status_code, (time.perf_counter() - started) * 1000


async def bench(
    client: httpx.AsyncClient,
    name: str,
    path: str,
    headers: dict,
    requests: int,
    concurrency: int,
) -> None:
    url = client.base_url.join(path.lstrip("/"))
    for _ in range(min(10, requests)):
        await one(client, str(url), headers)

    semaphore = asyncio.Semaphore(concurrency)

    async def limited():
        async with semaphore:
            return await one(client, str(url), headers)

    started = time.perf_counter()
    results = await asyncio.gather(*(limited() for _ in range(requests)))
    wall = time.perf_counter() - started
    latencies = sorted(item[1] for item in results)
    statuses = {}
    for status, _ in results:
        statuses[status] = statuses.get(status, 0) + 1
    print(
        f"{name:20s} p50={statistics.median(latencies):7.1f}ms "
        f"p95={latencies[int(len(latencies) * 0.95) - 1]:7.1f}ms "
        f"rps={requests / wall:7.1f} statuses={statuses}"
    )


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    parser.add_argument("--user-id", required=True)
    parser.add_argument("--requests", type=int, default=100)
    parser.add_argument("--concurrency", type=int, default=10)
    parser.add_argument("--admin-token", default="")
    args = parser.parse_args()

    headers = {"X-User-Id": args.user_id}
    admin_headers = (
        {"X-Admin-Token": args.admin_token} if args.admin_token else None
    )
    limits = httpx.Limits(
        max_connections=max(20, args.concurrency),
        max_keepalive_connections=max(20, args.concurrency),
    )
    async with httpx.AsyncClient(
        base_url=args.base_url,
        timeout=60,
        limits=limits,
    ) as client:
        for name, path in READ_ENDPOINTS:
            await bench(
                client,
                name,
                path,
                headers,
                args.requests,
                args.concurrency,
            )
        if admin_headers:
            await bench(
                client,
                "admin stats",
                "/api/v1/admin/stats",
                admin_headers,
                args.requests,
                args.concurrency,
            )


if __name__ == "__main__":
    asyncio.run(main())
