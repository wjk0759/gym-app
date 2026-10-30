"""30-round closed loop.

Each round runs the next ``size`` scenarios still in the active queue, keeps
passes in a regression pool, and re-runs a sample of that pool. The next round
only picks the still-failing scenarios, so the active queue shrinks as fixes
land. This is the machine behind the 3,000-scenario plan.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import random
import sys
import time
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.config import settings  # noqa: E402
from app.db import Base  # noqa: E402
from app.seed import seed_exercises  # noqa: E402
from app.services import agent as agent_service  # noqa: E402

from .runner import _run_scenario, _summarize  # noqa: E402

STATE_DIR = Path(__file__).resolve().parent / "state"
RESULTS_DIR = Path(__file__).resolve().parent / "results"
DEFAULT_BANK = Path(__file__).resolve().parent / "scenarios" / "bank_3000.jsonl"
PROVIDER_ERROR_MARKERS = (
    "insufficient_balance",
    "insufficient balance",
    "HTTP 402",
    "HTTP 401",
    "HTTP 429",
)


def _provider_down(result: dict) -> bool:
    error = str(result.get("error") or "").lower()
    return any(marker.lower() in error for marker in PROVIDER_ERROR_MARKERS)


def _load_bank(path: Path) -> list[dict]:
    items = []
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                items.append(json.loads(line))
    return items


def _load_state() -> dict:
    if (STATE_DIR / "round_state.json").exists():
        return json.loads((STATE_DIR / "round_state.json").read_text(encoding="utf-8"))
    return {"active": [], "passed": [], "round": 0}


def _save_state(state: dict) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    (STATE_DIR / "round_state.json").write_text(
        json.dumps(state, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


async def run_round(
    bank: list[dict],
    *,
    size: int,
    regression_size: int,
    seed: int,
) -> dict:
    state = _load_state()
    # Scenarios always come from the current bank, never from the state file,
    # so expectation fixes propagate into the next round.
    by_id = {item["id"]: item for item in bank}

    if not state["active"] and state["round"] == 0:
        state["active"] = [item["id"] for item in bank]

    active = [by_id[i] for i in state["active"] if i in by_id]
    passed_ids = set(state["passed"])
    todo = active[:size]
    state["round"] += 1
    round_no = state["round"]

    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    db = Session()
    seed_exercises(db)
    agent_service.schedule_memory_extraction = lambda *args, **kwargs: None

    results = []
    aborted = False
    abort_reason = None
    started = time.perf_counter()
    try:
        for index, scenario in enumerate(todo, 1):
            try:
                result = await _run_scenario(db, scenario)
            except Exception as exc:  # noqa: BLE001
                result = {
                    "id": scenario.get("id"),
                    "category": scenario.get("category"),
                    "pass": False,
                    "failures": [f"runner error: {exc}"],
                    "usage": {},
                    "cost_cny": 0,
                    "elapsed_ms": 0,
                }
            if _provider_down(result):
                aborted = True
                abort_reason = str(result.get("error") or "")[:300]
                break
            results.append(result)
            print(
                f"[{index}/{len(todo)}] {'PASS' if result.get('pass') else 'FAIL'} "
                f"{result.get('id')}",
                flush=True,
            )

        # Regression: re-run a sample of the previously passed pool.
        regression = []
        pool = [by_id[i] for i in state["passed"] if i in by_id]
        if not aborted and pool and regression_size > 0:
            random.Random(seed).shuffle(pool)
            for scenario in pool[:regression_size]:
                try:
                    result = await _run_scenario(db, scenario)
                except Exception as exc:  # noqa: BLE001
                    result = {
                        "id": scenario.get("id"),
                        "category": scenario.get("category"),
                        "pass": False,
                        "failures": [f"runner error: {exc}"],
                        "usage": {},
                        "cost_cny": 0,
                        "elapsed_ms": 0,
                    }
                if _provider_down(result):
                    aborted = True
                    abort_reason = str(result.get("error") or "")[:300]
                    break
                regression.append(result)
    finally:
        db.close()
        engine.dispose()

    new_passed = [r for r in results if r.get("pass")]
    reg_failed = [r for r in regression if not r.get("pass")]

    active_ids = [i for i in state["active"] if i in by_id]
    active_ids = [
        i
        for i in active_ids
        if i not in {r["id"] for r in new_passed}
    ]
    # Regressed failures return to the queue.
    for r in reg_failed:
        if r["id"] not in active_ids:
            active_ids.append(r["id"])
    state["active"] = active_ids
    state["passed"] = sorted(passed_ids | {r["id"] for r in new_passed})
    _save_state(state)

    summary = _summarize(results)
    summary["round"] = round_no
    summary["run_size"] = len(todo)
    summary["regression_size"] = len(regression)
    summary["regression_failed"] = len(reg_failed)
    summary["active_remaining"] = len(state["active"])
    summary["passed_total"] = len(state["passed"])
    summary["aborted"] = aborted
    if abort_reason:
        summary["abort_reason"] = abort_reason
    summary["elapsed_seconds"] = round(time.perf_counter() - started, 1)

    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    out = RESULTS_DIR / f"round-{round_no}.jsonl"
    with out.open("w", encoding="utf-8") as handle:
        for item in results:
            handle.write(json.dumps(item, ensure_ascii=False) + "\n")
    (RESULTS_DIR / f"round-{round_no}.summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return summary


async def main_async(args: argparse.Namespace) -> int:
    if settings.use_mock_llm:
        print("LLM is not configured; set LLM_API_KEY in backend/.env", file=sys.stderr)
        return 2
    bank = _load_bank(Path(args.bank))
    if not bank:
        print(f"empty bank: {args.bank}", file=sys.stderr)
        return 1
    summary = await run_round(
        bank,
        size=args.size,
        regression_size=args.regression,
        seed=args.seed,
    )
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description="Run one 30-round-loop round")
    parser.add_argument("--bank", default=str(DEFAULT_BANK))
    parser.add_argument("--size", type=int, default=100)
    parser.add_argument("--regression", type=int, default=10)
    parser.add_argument("--seed", type=int, default=7)
    args = parser.parse_args()
    raise SystemExit(asyncio.run(main_async(args)))


if __name__ == "__main__":
    main()
