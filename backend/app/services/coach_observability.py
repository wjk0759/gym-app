"""Read-only quality/cost report for the AI coach.

Everything here comes from rows already written by the production paths:
``AIJob`` (latency, tokens, status, prompt version), ``AgentRun`` (steps,
duration, status, prompt version) and ``CoachFeedback`` (rating and reason).
The report never calls the model.
"""

from __future__ import annotations

from collections import Counter, defaultdict
from datetime import datetime, timedelta
from statistics import mean
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import (
    AgentRun,
    AIJob,
    CoachActionRecord,
    CoachFeedback,
    CoachPending,
    CoachTurn,
    DomainEvent,
    utcnow,
)

MAX_REPORT_DAYS = 90
MAX_ROWS = 20000
UNKNOWN_PROMPT = "(unknown)"


def _percentile(values: list[int], fraction: float) -> int | None:
    if not values:
        return None
    ordered = sorted(values)
    index = round((len(ordered) - 1) * fraction)
    return ordered[max(0, min(index, len(ordered) - 1))]


def _latency(values: list[int | None]) -> dict[str, int | None]:
    clean = [int(value) for value in values if value is not None and value >= 0]
    return {
        "samples": len(clean),
        "avg_ms": round(mean(clean)) if clean else None,
        "p95_ms": _percentile(clean, 0.95),
    }


def _rate(part: int, total: int) -> float | None:
    return round(part / total, 3) if total else None


def _prompt_key(value: str | None) -> str:
    return value or UNKNOWN_PROMPT


def _run_duration_ms(run: AgentRun) -> int | None:
    if run.created_at is None or run.completed_at is None:
        return None
    start, end = run.created_at, run.completed_at
    # MySQL returns aware datetimes; SQLite can mix aware and naive values.
    if (start.tzinfo is None) != (end.tzinfo is None):
        if start.tzinfo is None:
            end = end.replace(tzinfo=None)
        else:
            start = start.replace(tzinfo=None)
    return max(0, int((end - start).total_seconds() * 1000))


def _job_section(jobs: list[AIJob]) -> dict[str, Any]:
    by_kind: dict[str, list[AIJob]] = defaultdict(list)
    by_prompt: dict[str, list[AIJob]] = defaultdict(list)
    for job in jobs:
        by_kind[job.kind].append(job)
        by_prompt[_prompt_key(job.prompt_version)].append(job)

    def summarize(items: list[AIJob]) -> dict[str, Any]:
        statuses = Counter(item.status for item in items)
        failures = len(items) - statuses.get("ok", 0)
        latency = _latency([item.latency_ms for item in items])
        return {
            "total": len(items),
            "ok": statuses.get("ok", 0),
            "fallback": statuses.get("fallback", 0),
            "failed": statuses.get("failed", 0),
            "other_status": sum(
                count
                for status, count in statuses.items()
                if status not in {"ok", "fallback", "failed"}
            ),
            "non_ok_rate": _rate(failures, len(items)),
            "avg_latency_ms": latency["avg_ms"],
            "p95_latency_ms": latency["p95_ms"],
            "input_tokens": sum(item.input_tokens or 0 for item in items),
            "output_tokens": sum(item.output_tokens or 0 for item in items),
        }

    kinds = [
        {"kind": kind, **summarize(items)}
        for kind, items in sorted(by_kind.items())
    ]
    prompts = [
        {"prompt_version": prompt, **summarize(items)}
        for prompt, items in sorted(by_prompt.items())
    ]
    return {
        "total": len(jobs),
        "kinds": kinds,
        "prompts": prompts,
        "input_tokens": sum(item.input_tokens or 0 for item in jobs),
        "output_tokens": sum(item.output_tokens or 0 for item in jobs),
    }


def _run_section(runs: list[AgentRun]) -> dict[str, Any]:
    statuses = Counter(run.status for run in runs)
    durations = [
        duration
        for duration in (_run_duration_ms(run) for run in runs)
        if duration is not None
    ]
    by_prompt: dict[str, list[AgentRun]] = defaultdict(list)
    for run in runs:
        by_prompt[_prompt_key(run.prompt_version)].append(run)

    prompts = []
    for prompt, items in sorted(by_prompt.items()):
        prompt_statuses = Counter(item.status for item in items)
        prompts.append(
            {
                "prompt_version": prompt,
                "total": len(items),
                "completed": prompt_statuses.get("completed", 0),
                "failed": prompt_statuses.get("failed", 0),
                "avg_steps": round(
                    mean(item.step_count or 0 for item in items), 2
                ),
            }
        )

    return {
        "total": len(runs),
        "completed": statuses.get("completed", 0),
        "failed": statuses.get("failed", 0),
        "running": statuses.get("running", 0),
        "completion_rate": _rate(statuses.get("completed", 0), len(runs)),
        "avg_steps": (
            round(mean(run.step_count or 0 for run in runs), 2) if runs else None
        ),
        **_latency(durations),
        "prompts": prompts,
    }


def _feedback_section(items: list[CoachFeedback]) -> dict[str, Any]:
    ratings = Counter(item.rating for item in items)
    up = ratings.get("up", 0)
    down = ratings.get("down", 0)
    rated = up + down
    reasons = Counter(
        item.reason or "unspecified" for item in items if item.rating == "down"
    )
    by_prompt: dict[str, list[CoachFeedback]] = defaultdict(list)
    for item in items:
        by_prompt[_prompt_key(item.prompt_version)].append(item)

    prompts = []
    for prompt, rows in sorted(by_prompt.items()):
        prompt_up = sum(1 for item in rows if item.rating == "up")
        prompt_down = sum(1 for item in rows if item.rating == "down")
        prompts.append(
            {
                "prompt_version": prompt,
                "total": len(rows),
                "up": prompt_up,
                "down": prompt_down,
                "satisfaction": _rate(prompt_up, prompt_up + prompt_down),
            }
        )

    return {
        "total": len(items),
        "up": up,
        "down": down,
        "satisfaction": _rate(up, rated),
        "reasons": dict(sorted(reasons.items())),
        "unsafe_reports": reasons.get("unsafe", 0),
        "prompts": prompts,
    }


def _control_section(
    turns: list[CoachTurn],
    actions: list[CoachActionRecord],
    pending: list[CoachPending],
    events: list[DomainEvent],
) -> dict[str, Any]:
    turn_statuses = Counter(item.status for item in turns)
    intents = Counter(item.intent or UNKNOWN_PROMPT for item in turns)
    daily = Counter(
        item.created_at.date().isoformat() for item in turns if item.created_at
    )
    action_statuses = Counter(item.status for item in actions)
    pending_statuses = Counter(item.status for item in pending)
    client_events: Counter[str] = Counter()
    safety_flags: Counter[str] = Counter()
    for event in events:
        payload = event.payload or {}
        if event.type == "ClientEvent":
            client_events[str(payload.get("name") or "unknown")] += 1
        elif event.type == "SafetyBlocked":
            safety_flags[str(payload.get("flag") or "unknown")] += 1

    return {
        "turns": {
            "total": len(turns),
            "statuses": dict(sorted(turn_statuses.items())),
            "intents": dict(sorted(intents.items())),
            "daily": dict(sorted(daily.items())),
        },
        "actions": {
            "total": len(actions),
            "statuses": dict(sorted(action_statuses.items())),
        },
        "pending": {
            "total": len(pending),
            "statuses": dict(sorted(pending_statuses.items())),
        },
        "client_events": dict(sorted(client_events.items())),
        "safety_blocks": dict(sorted(safety_flags.items())),
    }


def build_report(
    db: Session,
    *,
    days: int = 7,
    now: datetime | None = None,
) -> dict[str, Any]:
    """Aggregate coach jobs, runs and feedback for a recent window."""
    window_days = max(1, min(MAX_REPORT_DAYS, int(days)))
    end = now or utcnow()
    start = end - timedelta(days=window_days)

    jobs = list(
        db.execute(
            select(AIJob)
            .where(AIJob.created_at >= start)
            .order_by(AIJob.created_at.desc())
            .limit(MAX_ROWS)
        ).scalars()
    )
    runs = list(
        db.execute(
            select(AgentRun)
            .where(AgentRun.created_at >= start)
            .order_by(AgentRun.created_at.desc())
            .limit(MAX_ROWS)
        ).scalars()
    )
    feedback = list(
        db.execute(
            select(CoachFeedback)
            .where(CoachFeedback.created_at >= start)
            .order_by(CoachFeedback.created_at.desc())
            .limit(MAX_ROWS)
        ).scalars()
    )
    turns = list(
        db.execute(
            select(CoachTurn)
            .where(CoachTurn.created_at >= start)
            .order_by(CoachTurn.created_at.desc())
            .limit(MAX_ROWS)
        ).scalars()
    )
    actions = list(
        db.execute(
            select(CoachActionRecord)
            .where(CoachActionRecord.created_at >= start)
            .order_by(CoachActionRecord.created_at.desc())
            .limit(MAX_ROWS)
        ).scalars()
    )
    pending = list(
        db.execute(
            select(CoachPending)
            .where(CoachPending.created_at >= start)
            .order_by(CoachPending.created_at.desc())
            .limit(MAX_ROWS)
        ).scalars()
    )
    events = list(
        db.execute(
            select(DomainEvent)
            .where(
                DomainEvent.occurred_at >= start,
                DomainEvent.type.in_(["ClientEvent", "SafetyBlocked"]),
            )
            .order_by(DomainEvent.occurred_at.desc())
            .limit(MAX_ROWS)
        ).scalars()
    )

    return {
        "window": {
            "days": window_days,
            "start": start.isoformat(),
            "end": end.isoformat(),
        },
        "jobs": _job_section(jobs),
        "runs": _run_section(runs),
        "feedback": _feedback_section(feedback),
        "control": _control_section(turns, actions, pending, events),
    }


def _fmt_rate(value: float | None) -> str:
    return "n/a" if value is None else f"{value * 100:.1f}%"


def _fmt_ms(value: int | None) -> str:
    return "-" if value is None else f"{value}"


def format_report(report: dict[str, Any]) -> str:
    """Human-readable terminal report."""
    window = report["window"]
    jobs = report["jobs"]
    runs = report["runs"]
    feedback = report["feedback"]
    lines = [
        f"Coach observability · last {window['days']} days",
        f"{window['start']}  ->  {window['end']}",
        "",
        "AI jobs",
        f"total {jobs['total']}  input_tokens {jobs['input_tokens']}  "
        f"output_tokens {jobs['output_tokens']}",
        f"{'kind':<22}{'n':>6}{'non-ok':>9}{'avg ms':>9}{'p95 ms':>9}"
        f"{'in tok':>10}{'out tok':>10}",
    ]
    lines.extend(
        f"{item['kind']:<22}{item['total']:>6}"
        f"{_fmt_rate(item['non_ok_rate']):>9}"
        f"{_fmt_ms(item['avg_latency_ms']):>9}"
        f"{_fmt_ms(item['p95_latency_ms']):>9}"
        f"{item['input_tokens']:>10}{item['output_tokens']:>10}"
        for item in jobs["kinds"]
    )
    lines.extend(
        f"  prompt {item['prompt_version']:<28} n={item['total']} "
        f"non-ok={_fmt_rate(item['non_ok_rate'])}"
        for item in jobs["prompts"]
    )

    lines += [
        "",
        "Agent runs",
        f"total {runs['total']}  completed {runs['completed']}  "
        f"failed {runs['failed']}  running {runs['running']}  "
        f"completion {_fmt_rate(runs['completion_rate'])}",
        f"avg steps {runs['avg_steps']}  avg duration ms "
        f"{_fmt_ms(runs['avg_ms'])}  p95 duration ms {_fmt_ms(runs['p95_ms'])}",
    ]
    for item in runs["prompts"]:
        lines.append(
            f"  prompt {item['prompt_version']:<28} n={item['total']} "
            f"completed={item['completed']} failed={item['failed']} "
            f"avg_steps={item['avg_steps']}"
        )

    lines += [
        "",
        "Feedback",
        f"total {feedback['total']}  up {feedback['up']}  down "
        f"{feedback['down']}  satisfaction {_fmt_rate(feedback['satisfaction'])}",
    ]
    if feedback["reasons"]:
        reasons = "  ".join(
            f"{reason}={count}"
            for reason, count in feedback["reasons"].items()
        )
        lines.append(f"down reasons: {reasons}")
    for item in feedback["prompts"]:
        lines.append(
            f"  prompt {item['prompt_version']:<28} n={item['total']} "
            f"up={item['up']} down={item['down']} "
            f"satisfaction={_fmt_rate(item['satisfaction'])}"
        )
    if feedback["unsafe_reports"]:
        lines.append(
            f"! {feedback['unsafe_reports']} unsafe report(s) need review this window"
        )

    control = report["control"]
    turns = control["turns"]
    actions = control["actions"]
    pending = control["pending"]
    lines += [
        "",
        "Control plane",
        f"turns {turns['total']}  statuses={turns['statuses']}",
        "intents "
        + "  ".join(f"{key}={value}" for key, value in turns["intents"].items()),
        f"actions {actions['total']}  statuses={actions['statuses']}",
        f"pending {pending['total']}  statuses={pending['statuses']}",
    ]
    if turns["daily"]:
        lines.append(
            "daily turns " + "  ".join(
                f"{key}={value}" for key, value in turns["daily"].items()
            )
        )
    lines.append("")
    lines.append("Client funnel")
    if control["client_events"]:
        lines.extend(
            f"  {name:<28}{count:>6}"
            for name, count in control["client_events"].items()
        )
    else:
        lines.append("  (no client events in this window)")
    if control["safety_blocks"]:
        lines.append(
            "safety blocks: "
            + "  ".join(
                f"{flag}={count}"
                for flag, count in control["safety_blocks"].items()
            )
        )
    return "\n".join(lines)
