"""A/B the coach with and without retrieved knowledge, using the real model.

This is deliberately narrow: one user question, one baseline answer, one answer
grounded by top-k records from the matching knowledge domain, then a blind
LLM-judge comparison. It answers "does the KB change the answer for the better?"
without conflating tool-selection or persona state.

Run from ``backend/``:

    $env:PYTHONPATH="$PWD"
    .\\.venv\\Scripts\\python.exe -m eval.knowledge_ab --limit 18

Results are written to ``eval/results/knowledge_ab.json`` (gitignored).
"""

from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import sys
import time
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.config import settings  # noqa: E402
from app.services import llm  # noqa: E402
from app.services.knowledge_search import knowledge_payload  # noqa: E402

CASES_PATH = Path(__file__).with_name("knowledge_ab_cases.json")
OUTPUT_PATH = BACKEND_ROOT / "eval" / "results" / "knowledge_ab.json"

SYSTEM_BASE = (
    "你是「叫练」AI 私人健身教练。回答用户问题：先给结论，再给 1–2 个具体建议；"
    "不确定就说明；不编造数据；疼痛、孕期、术后等情况先建议专业评估。"
    "列表最多 3 条，每条一句话。"
)

SYSTEM_WITH_KNOWLEDGE = (
    SYSTEM_BASE
    + "\n\n服务端检索到以下知识，仅使用与问题直接相关的 1–2 条；不要逐条复述，"
    "不要为了引用而引用；不要写“据知识库”超过一次；回答仍控制在 3 条以内。"
    "如果知识与用户当前情况冲突，以安全为先；没有把握就说明限制。"
)

JUDGE_SYSTEM = """你是严格、公正的健身教练评审。
比较回答 A 和回答 B，按以下维度打分：
1. 正确性：事实、数字、动作要点是否可靠，是否编造。
2. 具体性：是否给出可执行的重量、次数、动作、判断标准。
3. 安全性：疼痛/伤病/孕期等是否提示停止、减量或就医。
4. 直接性：是否回答了用户的问题，而不是泛泛而谈。
不要因为回答更长就给高分。
只输出一个 JSON 对象，不要 Markdown：
{"winner":"A"|"B"|"tie","scores":{"A":1,"B":1},"reason":"一句话"}
scores 是 1–5 的整数。"""


def _format_context(results: list[dict]) -> str:
    lines: list[str] = []
    for index, item in enumerate(results, start=1):
        text = str(item.get("text") or "")[:1200]
        source = str(item.get("source") or "未标注")
        lines.append(f"[{index}] {item.get('title')}\n{text}\n来源：{source}")
    return "\n\n".join(lines)


def _fact_hit(answer: str, expected: list[str]) -> bool:
    text = answer.lower()
    return any(keyword.lower() in text for keyword in expected)


def _judge_user(query: str, a: str, b: str) -> str:
    return (
        f"用户问题：{query}\n\n"
        f"回答 A：\n{a[:1800]}\n\n"
        f"回答 B：\n{b[:1800]}\n\n"
        "请比较 A 和 B。"
    )


async def _generate(system: str, query: str) -> str:
    last = ""
    for _ in range(3):
        last = await llm.complete_text(
            [
                {"role": "system", "content": system},
                {"role": "user", "content": query},
            ],
            temperature=0.2,
            max_tokens=600,
            reasoning_effort="low",
            kind="knowledge_ab",
        )
        if last.strip():
            return last
    return last


async def _judge(query: str, a: str, b: str) -> tuple[str | None, str]:
    try:
        result = await llm.complete_json(
            JUDGE_SYSTEM,
            _judge_user(query, a, b),
            kind="knowledge_ab_judge",
        )
    except llm.LLMError as exc:
        return None, str(exc)[:200]
    winner = str(result.get("winner") or "").strip().lower()
    reason = str(result.get("reason") or "")[:300]
    if winner not in {"a", "b", "tie"}:
        return None, reason
    return winner, reason


async def _run_case(case: dict, semaphore: asyncio.Semaphore) -> dict:
    async with semaphore:
        query = case["query"]
        domain = case["domain"]
        payload = knowledge_payload(query, domain=domain, limit=4)
        results = payload.get("results") or []
        context = _format_context(results)
        system_with = (
            SYSTEM_WITH_KNOWLEDGE + "\n\n" + context if context else SYSTEM_BASE
        )

        baseline, grounded = await asyncio.gather(
            _generate(SYSTEM_BASE, query),
            _generate(system_with, query),
        )

        # Randomize the visible order by case id so the judge cannot learn that
        # the grounded answer is always A or always B.
        flip = int(hashlib.md5(case["id"].encode()).hexdigest(), 16) % 2 == 0
        first, second = (grounded, baseline) if flip else (baseline, grounded)
        first_label = "kb" if flip else "baseline"
        second_label = "baseline" if flip else "kb"

        (judge_one, reason_one), (judge_two, reason_two) = await asyncio.gather(
            _judge(query, first, second),
            _judge(query, second, first),
        )

        def map_winner(winner: str | None, a_label: str, b_label: str) -> str | None:
            if winner is None or winner == "tie":
                return "tie" if winner == "tie" else None
            return a_label if winner == "a" else b_label

        winner_one = map_winner(judge_one, first_label, second_label)
        winner_two = map_winner(judge_two, second_label, first_label)
        winner = winner_one if winner_one == winner_two else "tie"

        expected = list(case.get("expected_any") or [])
        return {
            "id": case["id"],
            "domain": domain,
            "query": query,
            "retrieval_ok": bool(results),
            "retrieved": [item.get("title") for item in results],
            "baseline": {
                "answer": baseline,
                "fact_hit": _fact_hit(baseline, expected),
                "chars": len(baseline),
            },
            "kb": {
                "answer": grounded,
                "fact_hit": _fact_hit(grounded, expected),
                "chars": len(grounded),
            },
            "judge": {
                "winner": winner,
                "pass1": winner_one,
                "pass2": winner_two,
                "reason1": reason_one,
                "reason2": reason_two,
            },
        }


async def _safe_run_case(case: dict, semaphore: asyncio.Semaphore) -> dict:
    try:
        return await _run_case(case, semaphore)
    except llm.LLMError as exc:
        return {
            "id": case["id"],
            "domain": case["domain"],
            "query": case["query"],
            "error": str(exc)[:300],
        }


async def main_async(args: argparse.Namespace) -> int:
    cases = json.loads(CASES_PATH.read_text(encoding="utf-8"))
    if args.limit:
        cases = cases[: args.limit]
    semaphore = asyncio.Semaphore(args.concurrency)
    started = time.perf_counter()
    rows = await asyncio.gather(
        *(_safe_run_case(case, semaphore) for case in cases)
    )
    elapsed = time.perf_counter() - started

    usable = [row for row in rows if "error" not in row]
    total = len(usable)
    baseline_fact = sum(int(row["baseline"]["fact_hit"]) for row in usable)
    kb_fact = sum(int(row["kb"]["fact_hit"]) for row in usable)
    judge = [row["judge"]["winner"] for row in usable if row["judge"]["winner"]]
    kb_wins = judge.count("kb")
    baseline_wins = judge.count("baseline")
    ties = judge.count("tie")
    decided = kb_wins + baseline_wins

    by_domain: dict[str, dict] = {}
    for row in usable:
        bucket = by_domain.setdefault(
            row["domain"],
            {
                "cases": 0,
                "baseline_fact_hit": 0,
                "kb_fact_hit": 0,
                "kb_wins": 0,
                "baseline_wins": 0,
                "ties": 0,
            },
        )
        bucket["cases"] += 1
        bucket["baseline_fact_hit"] += int(row["baseline"]["fact_hit"])
        bucket["kb_fact_hit"] += int(row["kb"]["fact_hit"])
        winner = row["judge"]["winner"]
        if winner == "kb":
            bucket["kb_wins"] += 1
        elif winner == "baseline":
            bucket["baseline_wins"] += 1
        elif winner == "tie":
            bucket["ties"] += 1

    summary = {
        "model": settings.llm_model,
        "cases": len(cases),
        "usable": total,
        "errors": len(rows) - total,
        "elapsed_seconds": round(elapsed, 1),
        "baseline": {
            "fact_hit_rate": round(baseline_fact / total, 4) if total else 0,
            "avg_chars": round(
                sum(row["baseline"]["chars"] for row in usable) / total, 1
            )
            if total
            else 0,
        },
        "kb": {
            "fact_hit_rate": round(kb_fact / total, 4) if total else 0,
            "avg_chars": round(
                sum(row["kb"]["chars"] for row in usable) / total, 1
            )
            if total
            else 0,
        },
        "judge": {
            "kb_wins": kb_wins,
            "baseline_wins": baseline_wins,
            "ties": ties,
            "kb_win_rate_decided": round(kb_wins / decided, 4) if decided else 0,
        },
        "by_domain": {
            domain: {
                **bucket,
                "baseline_fact_hit_rate": round(
                    bucket["baseline_fact_hit"] / bucket["cases"], 4
                ),
                "kb_fact_hit_rate": round(
                    bucket["kb_fact_hit"] / bucket["cases"], 4
                ),
            }
            for domain, bucket in sorted(by_domain.items())
        },
        "results": rows,
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--concurrency", type=int, default=4)
    args = parser.parse_args()
    raise SystemExit(asyncio.run(main_async(args)))


if __name__ == "__main__":
    main()
