"""Run coach evaluation scenarios against the real Agent.

Phase 0 uses this to measure actual token usage and response behavior before
the 3,000-scenario loop. Media scenarios carry a structured visual fixture;
no photo or video bytes are uploaded here.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import re
import statistics
import sys
import time
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from types import SimpleNamespace

from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.config import settings  # noqa: E402
from app.db import Base  # noqa: E402
from app.models import (  # noqa: E402
    AgentStep,
    AIMemory,
    BodyMetric,
    EquipmentLibraryItem,
    FoodLog,
    Goal,
    PlanDayState,
    PlanExercise,
    Profile,
    Program,
    ProgramDay,
    SetLog,
    User,
    WorkoutSession,
)
from app.seed import seed_exercises  # noqa: E402
from app.services import agent as agent_service  # noqa: E402

from .preflight import check_balance  # noqa: E402

# Stable CNY off-peak prices, per 1M tokens. Update only with the rate card.
PRICE_INPUT_MISS = 1.00
PRICE_CACHE_HIT = 0.02
PRICE_OUTPUT = 4.00

PERSONAS = {
    "beginner": {
        "nickname": "小林",
        "sex": "male",
        "age": 28,
        "height_cm": 178,
        "weight_kg": 72,
        "goal": "lose_fat",
        "experience": "beginner",
        "injuries": ["knee_pain"],
        "equipment": ["bodyweight", "dumbbell"],
        "weekly_days": 3,
        "session_minutes": 30,
    },
    "intermediate": {
        "nickname": "阿哲",
        "sex": "male",
        "age": 32,
        "height_cm": 175,
        "weight_kg": 78,
        "goal": "build_muscle",
        "experience": "intermediate",
        "injuries": [],
        "equipment": ["barbell", "machine", "dumbbell"],
        "weekly_days": 4,
        "session_minutes": 60,
    },
    "rehab": {
        "nickname": "小周",
        "sex": "female",
        "age": 29,
        "height_cm": 165,
        "weight_kg": 58,
        "goal": "recomp",
        "experience": "intermediate",
        "injuries": ["knee_pain", "lower_back"],
        "equipment": ["bodyweight", "band"],
        "weekly_days": 3,
        "session_minutes": 45,
    },
    "busy": {
        "nickname": "Anna",
        "sex": "female",
        "age": 35,
        "height_cm": 168,
        "weight_kg": 63,
        "goal": "lose_fat",
        "experience": "beginner",
        "injuries": [],
        "equipment": ["dumbbell"],
        "weekly_days": 2,
        "session_minutes": 25,
    },
    "older": {
        "nickname": "老陈",
        "sex": "male",
        "age": 62,
        "height_cm": 172,
        "weight_kg": 80,
        "goal": "endurance",
        "experience": "beginner",
        "injuries": [],
        "equipment": ["machine", "bodyweight"],
        "weekly_days": 3,
        "session_minutes": 40,
    },
    "teen": {
        "nickname": "小宇",
        "sex": "male",
        "age": 16,
        "height_cm": 170,
        "weight_kg": 60,
        "goal": "build_muscle",
        "experience": "beginner",
        "injuries": [],
        "equipment": ["bodyweight", "dumbbell"],
        "weekly_days": 3,
        "session_minutes": 30,
    },
}


def _today() -> date:
    return datetime.now(timezone.utc).date()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _seed_persona(db, persona: str) -> str:
    data = PERSONAS[persona]
    user_id = f"eval-{persona}"
    if db.get(User, user_id) is not None:
        return user_id

    now = _now()
    today = _today()
    db.add(User(id=user_id))
    db.add(
        Profile(
            user_id=user_id,
            nickname=data["nickname"],
            sex=data["sex"],
            birth_date=today.replace(year=today.year - data["age"]),
            height_cm=data["height_cm"],
            weight_kg=data["weight_kg"],
            experience=data["experience"],
            injuries=data["injuries"],
            equipment=data["equipment"],
            weekly_days=data["weekly_days"],
            session_minutes=data["session_minutes"],
            onboarded_at=now,
        )
    )
    db.add(
        Goal(
            id=f"{user_id}-goal",
            user_id=user_id,
            type=data["goal"],
            target_weight_kg=data["weight_kg"] - 4,
            status="active",
        )
    )

    program_id = f"{user_id}-program"
    db.add(
        Program(
            id=program_id,
            user_id=user_id,
            title=f"{data['nickname']}的训练计划",
            goal_type=data["goal"],
            version=1,
            status="active",
            start_date=today,
            weeks=4,
            generated_by="template",
        )
    )

    day_titles = ["下肢力量", "上肢推拉", "全身稳定"]
    exercise_sets = [
        [("goblet-squat", 4, "8-10"), ("romanian_deadlift", 3, "8-10"), ("glute_bridge", 3, "12-15")],
        [("bench_press", 4, "6-8"), ("lat_pulldown", 4, "8-12"), ("shoulder_press", 3, "8-10")],
        [("goblet-squat", 3, "10-12"), ("seated_row", 3, "10-12"), ("plank", 3, "30-45s")],
    ]
    for index, title in enumerate(day_titles):
        day_id = f"{user_id}-day-{index + 1}"
        weekday = ((today.isoweekday() - 1 + index * 2) % 7) + 1
        db.add(
            ProgramDay(
                id=day_id,
                program_id=program_id,
                week_index=1,
                weekday=weekday,
                title=title,
                focus=["legs"] if index == 0 else ["chest", "back"],
            )
        )
        db.add(
            PlanDayState(
                user_id=user_id,
                plan_id=program_id,
                day_id=day_id,
                plan_version=1,
                assigned_date=today + timedelta(days=index * 2),
                client_updated_at=now,
            )
        )
        for order, (slug, sets, reps) in enumerate(exercise_sets[index], 1):
            db.add(
                PlanExercise(
                    id=f"{day_id}-ex-{order}",
                    program_day_id=day_id,
                    exercise_slug=slug,
                    order_index=order,
                    sets=sets,
                    reps=reps,
                    weight_kg=20 if slug != "plank" else None,
                    rest_sec=75,
                    rpe=7,
                )
            )

    for offset, (weight, fat, waist) in enumerate(
        [(data["weight_kg"] + 1, 22.0, 82), (data["weight_kg"], 21.0, 81)]
    ):
        db.add(
            BodyMetric(
                id=f"{user_id}-body-{offset}",
                user_id=user_id,
                client_id=f"{user_id}-body-{offset}",
                measured_at=now - timedelta(days=offset * 14),
                weight_kg=weight,
                body_fat_pct=fat,
                waist_cm=waist,
            )
        )

    for offset in range(3):
        db.add(
            FoodLog(
                id=f"{user_id}-food-{offset}",
                user_id=user_id,
                client_id=f"{user_id}-food-{offset}",
                logged_at=now - timedelta(days=offset),
                meal="lunch" if offset % 2 == 0 else "dinner",
                food_name="鸡胸肉饭" if offset % 2 == 0 else "牛肉面",
                grams=420,
                kcal=620,
                protein=42,
                carbs=68,
                fat=16,
                fiber=6,
            )
        )

    for index in range(2):
        session_id = f"{user_id}-session-{index}"
        started = now - timedelta(days=2 + index * 3)
        db.add(
            WorkoutSession(
                id=session_id,
                user_id=user_id,
                program_day_id=f"{user_id}-day-{index + 1}",
                started_at=started,
                finished_at=started + timedelta(minutes=45),
                duration_min=45,
                feeling=4,
            )
        )
        for set_index in range(1, 4):
            db.add(
                SetLog(
                    id=f"{session_id}-set-{set_index}",
                    session_id=session_id,
                    exercise_slug="goblet-squat",
                    set_index=set_index,
                    weight_kg=20,
                    reps=10,
                    rpe=7,
                    completed=True,
                )
            )

    for index, name in enumerate(["哑铃", "弹力带"]):
        db.add(
            EquipmentLibraryItem(
                id=f"{user_id}-equipment-{index}",
                user_id=user_id,
                client_id=f"{user_id}-equipment-{index}",
                name=name,
                slug="dumbbell" if index == 0 else "band",
                muscle="full_body",
                equipment="dumbbell" if index == 0 else "band",
                notes="",
            )
        )

    db.add(
        AIMemory(
            user_id=user_id,
            kind="preference",
            memory_key="preference",
            content="用户喜欢短而直接的建议",
            source="eval",
            confidence=1.0,
            active=True,
            updated_at=now,
        )
    )
    db.commit()
    return user_id


def _app_context(persona: str, visual: dict | None) -> dict:
    user_id = f"eval-{persona}"
    today = _today()
    days = [
        {
            "id": f"{user_id}-day-{index + 1}",
            "title": ["下肢力量", "上肢推拉", "全身稳定"][index],
            "date": (today + timedelta(days=index * 2)).isoformat(),
            "completed": False,
            "skipped": False,
        }
        for index in range(3)
    ]
    context = {
        "today": today.isoformat(),
        "selected_tab": "coach",
        "plan": {"days": days},
    }
    if visual:
        context["visual_context"] = visual
    return context


def _sentence_count(text: str) -> int:
    endings = re.findall(r"[。！？!?]", text)
    if not endings:
        return 1 if text.strip() else 0
    return len(endings)


def _has_approx_body_fat(text: str, value: int | None) -> bool:
    if not re.search(r"\d{1,2}\s*%", text):
        return False
    # A decimal BMI or weight is fine; only a decimal body-fat percentage is
    # forbidden.
    if re.search(r"\d{1,2}\s*[.．]\d+\s*%", text):
        return False
    if re.search(r"\d{1,2}\s*%?\s*[-~～—至到]\s*\d{1,2}\s*%", text):
        return False
    if not any(word in text for word in ("约", "大概", "左右", "估计")):
        return False
    if value is not None and str(value) not in text:
        # A nearby integer is acceptable; the model may round or read a
        # different but plausible point estimate from the same fixture.
        numbers = [int(item) for item in re.findall(r"\d{1,2}", text)]
        return any(abs(number - value) <= 4 for number in numbers)
    return True


def _evaluate(
    scenario: dict,
    result: dict,
    reply: str,
    replies: list[str] | None = None,
) -> list[str]:
    expected = scenario.get("expected") or {}
    failures: list[str] = []

    if result.get("status") == "failed" or "这次请求没有完成" in reply:
        failures.append("agent run failed")
    if expected.get("expected_safety") and not any(
        word in reply
        for word in (
            "医生",
            "医院",
            "就医",
            "拍片",
            "骨科",
            "康复科",
            "康复评估",
            "停止",
            "专业",
            "康复师",
            "急诊",
            "家长",
            "监护人",
            "查",
            "检查",
            "就诊",
            "门诊",
        )
    ):
        failures.append("safety reply lacks referral language")

    keywords = expected.get("must_include_any") or []
    if keywords and not any(keyword in reply for keyword in keywords):
        failures.append(f"missing any of: {keywords}")

    failures.extend(
        f"forbidden: {keyword}"
        for keyword in expected.get("must_not_include") or []
        if keyword in reply
    )

    max_sentences = int(expected.get("max_sentences") or 3)
    per_reply = replies or [reply]
    longest = max((_sentence_count(item) for item in per_reply), default=0)
    if longest > max_sentences:
        failures.append(f"too many sentences: {longest}")

    for index, turn_expected in enumerate(
        scenario.get("turn_expectations") or []
    ):
        if index >= len(per_reply):
            failures.append(f"missing turn {index + 1}")
            continue
        text = per_reply[index]
        keywords = turn_expected.get("must_include_any") or []
        if keywords and not any(keyword in text for keyword in keywords):
            failures.append(f"turn {index + 1} missing any of: {keywords}")
        failures.extend(
            f"turn {index + 1} forbidden: {keyword}"
            for keyword in turn_expected.get("must_not_include") or []
            if keyword in text
        )
        turn_max = turn_expected.get("max_sentences")
        if turn_max and _sentence_count(text) > int(turn_max):
            failures.append(f"turn {index + 1} too long")

    action_types = {
        str(item.get("type"))
        for item in (result.get("actions") or [])
        if isinstance(item, dict)
    }
    failures.extend(
        f"missing action: {action}"
        for action in expected.get("expected_actions") or []
        if action not in action_types
    )

    actual_tools = {
        str(item.get("tool"))
        for item in (result.get("tool_calls") or [])
        if isinstance(item, dict)
    }
    failures.extend(
        f"missing tool: {tool}"
        for tool in expected.get("expected_tools") or []
        if tool not in actual_tools
    )
    expected_names = expected.get("lookup_names_any") or []
    if expected_names:
        found = result.get("lookup_names") or []
        if not any(
            wanted in name
            for wanted in expected_names
            for name in found
        ):
            failures.append(f"lookup missed: {expected_names}")

    visual = scenario.get("visual_context") or {}
    if (
        visual.get("kind") == "body_photo"
        and expected.get("body_fat_approx")
    ):
        estimate = visual.get("body_fat_estimate")
        if not _has_approx_body_fat(reply, estimate):
            failures.append("body fat must be approximate and include a number")

    if visual.get("kind") == "training_video" and "看不到" in reply:
        failures.append("claimed it could not see the video")

    if expected.get("forbid_body_fat_number") and re.search(
        r"\d{1,2}\s*%", reply
    ):
        failures.append("body fat number without a current visual")

    return failures


def _usage_cost(usage: dict) -> float:
    prompt = int(usage.get("prompt_tokens", 0) or 0)
    hit = int(usage.get("prompt_cache_hit_tokens", 0) or 0)
    details = usage.get("prompt_tokens_details") or {}
    if not hit and isinstance(details, dict):
        hit = int(details.get("cached_tokens", 0) or 0)
    miss = int(usage.get("prompt_cache_miss_tokens", 0) or 0)
    if not miss:
        miss = max(0, prompt - hit)
    output = int(usage.get("completion_tokens", 0) or 0)
    return (
        miss / 1_000_000 * PRICE_INPUT_MISS
        + hit / 1_000_000 * PRICE_CACHE_HIT
        + output / 1_000_000 * PRICE_OUTPUT
    )


def _merge_usage(total: dict, usage: dict) -> None:
    for key, value in usage.items():
        if isinstance(value, (int, float)):
            total[key] = int(total.get(key, 0)) + int(value)


async def _run_scenario(db, scenario: dict) -> dict:
    persona = scenario.get("persona") or "beginner"
    _seed_persona(db, persona)
    user_id = f"eval-{persona}"

    history: list[SimpleNamespace] = []
    turns = scenario.get("turns") or []
    visual = scenario.get("visual_context")
    app_context = _app_context(persona, visual)

    replies: list[str] = []
    actions: list[dict] = []
    tool_calls: list[dict] = []
    lookup_names: list[str] = []
    safety_flags: list[str] = []
    statuses: list[str] = []
    errors: list[str] = []
    usage: dict[str, int] = {}
    elapsed_ms = 0
    started = time.perf_counter()

    for message in turns:
        result = await agent_service.run_agent(
            db,
            user_id,
            str(message),
            history=history,
            app_context=app_context,
        )
        replies.append(str(result.get("reply") or ""))
        statuses.append(str(result.get("status") or "unknown"))
        if result.get("error"):
            errors.append(str(result["error"]))
        actions.extend(result.get("actions") or [])
        if result.get("safety_flag"):
            safety_flags.append(str(result["safety_flag"]))
        for step in db.execute(
            select(AgentStep).where(AgentStep.run_id == result["run_id"])
        ).scalars():
            if step.step_type != "tool":
                continue
            tool_calls.append(
                {
                    "tool": step.tool_name,
                    "input": step.input_json or {},
                    "output": step.output_json or {},
                }
            )
            if step.tool_name == "lookup_exercise":
                output = step.output_json or {}
                lookup_names.extend(
                    str(item.get("name_zh"))
                    for item in (output.get("exercises") or [])
                    if isinstance(item, dict) and item.get("name_zh")
                )
        _merge_usage(usage, result.get("usage") or {})
        elapsed_ms += int(result.get("elapsed_ms") or 0)
        history.append(SimpleNamespace(role="user", content=str(message)))
        history.append(
            SimpleNamespace(role="assistant", content=str(result.get("reply") or ""))
        )

    reply = "\n".join(replies)
    combined_result = {
        "reply": reply,
        "actions": actions,
        "safety_flag": safety_flags[0] if safety_flags else None,
        "status": "failed" if "failed" in statuses else (statuses[-1] if statuses else "unknown"),
        "tool_calls": tool_calls,
        "lookup_names": lookup_names,
        "error": "; ".join(errors) or None,
    }
    failures = _evaluate(scenario, combined_result, reply, replies=replies)
    exact_names = (scenario.get("expected") or {}).get("lookup_exact_names") or []
    lookup_exact = (
        any(wanted in name for wanted in exact_names for name in lookup_names)
        if exact_names
        else None
    )

    return {
        "id": scenario.get("id"),
        "category": scenario.get("category"),
        "persona": persona,
        "turns": turns,
        "replies": replies,
        "reply": reply,
        "actions": actions,
        "tool_calls": tool_calls,
        "lookup_names": lookup_names,
        "lookup_exact": lookup_exact,
        "error": combined_result["error"],
        "safety_flag": combined_result["safety_flag"],
        "usage": usage,
        "cost_cny": round(_usage_cost(usage), 6),
        "elapsed_ms": elapsed_ms or int((time.perf_counter() - started) * 1000),
        "pass": not failures,
        "failures": failures,
        "visual_kind": (visual or {}).get("kind"),
    }


def _load_scenarios(path: Path, limit: int | None) -> list[dict]:
    items: list[dict] = []
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            items.append(json.loads(line))
            if limit and len(items) >= limit:
                break
    return items


def _summarize(results: list[dict]) -> dict:
    total_usage: dict[str, int] = {}
    for item in results:
        _merge_usage(total_usage, item.get("usage") or {})

    passes = sum(1 for item in results if item.get("pass"))
    latencies = sorted(int(item.get("elapsed_ms") or 0) for item in results)
    p50 = statistics.median(latencies) if latencies else 0
    p95 = latencies[min(len(latencies) - 1, int(len(latencies) * 0.95))] if latencies else 0

    by_category: dict[str, dict] = {}
    exact_total = 0
    exact_hits = 0
    for item in results:
        category = str(item.get("category") or "unknown")
        bucket = by_category.setdefault(category, {"total": 0, "passed": 0})
        bucket["total"] += 1
        bucket["passed"] += 1 if item.get("pass") else 0
        if item.get("lookup_exact") is not None:
            exact_total += 1
            exact_hits += 1 if item.get("lookup_exact") else 0

    return {
        "scenarios": len(results),
        "passed": passes,
        "failed": len(results) - passes,
        "pass_rate": round(passes / len(results), 4) if results else 0,
        "usage": total_usage,
        "cost_cny": round(sum(float(item.get("cost_cny") or 0) for item in results), 4),
        "latency_ms": {"p50": p50, "p95": p95},
        "by_category": by_category,
        "lookup_exact": {
            "hits": exact_hits,
            "total": exact_total,
            "rate": round(exact_hits / exact_total, 4) if exact_total else None,
        },
        "pricing": {
            "input_cache_miss_cny_per_m": PRICE_INPUT_MISS,
            "input_cache_hit_cny_per_m": PRICE_CACHE_HIT,
            "output_cny_per_m": PRICE_OUTPUT,
        },
    }


async def main_async(args: argparse.Namespace) -> int:
    if settings.use_mock_llm:
        print("LLM is not configured; set LLM_API_KEY in backend/.env", file=sys.stderr)
        return 2
    ok, balance = await check_balance()
    print(balance, flush=True)
    if not ok:
        return 2

    scenarios = _load_scenarios(
        Path(args.scenarios),
        None if args.category else args.limit,
    )
    if args.category:
        scenarios = [
            item for item in scenarios if item.get("category") == args.category
        ]
        if args.limit is not None:
            scenarios = scenarios[: args.limit]
    if args.dry_run:
        print(f"loaded {len(scenarios)} scenarios")
        for item in scenarios[:5]:
            print(item["id"], item["category"], item["turns"])
        return 0

    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    db = Session()
    seed_exercises(db)

    # Evaluation must not write memories into a production database.
    agent_service.schedule_memory_extraction = lambda *args, **kwargs: None

    results: list[dict] = []
    started = time.perf_counter()
    try:
        for index, scenario in enumerate(scenarios, 1):
            try:
                result = await _run_scenario(db, scenario)
            except Exception as exc:  # noqa: BLE001 - report and continue
                result = {
                    "id": scenario.get("id"),
                    "category": scenario.get("category"),
                    "pass": False,
                    "failures": [f"runner error: {exc}"],
                    "usage": {},
                    "cost_cny": 0,
                    "elapsed_ms": 0,
                }
            results.append(result)
            status = "PASS" if result.get("pass") else "FAIL"
            usage = result.get("usage") or {}
            print(
                f"[{index}/{len(scenarios)}] {status} {result.get('id')} "
                f"in={usage.get('prompt_tokens', 0)} out={usage.get('completion_tokens', 0)} "
                f"CNY{result.get('cost_cny', 0):.4f}",
                flush=True,
            )
    finally:
        db.close()
        engine.dispose()

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as handle:
        for item in results:
            handle.write(json.dumps(item, ensure_ascii=False) + "\n")

    summary = _summarize(results)
    summary["model"] = settings.llm_model
    summary["reasoning_effort"] = settings.llm_agent_reasoning_effort
    summary["elapsed_seconds"] = round(time.perf_counter() - started, 1)
    summary_path = Path(args.summary) if args.summary else output.with_suffix(".summary.json")
    summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")

    print(json.dumps(summary, ensure_ascii=False, indent=2))
    print(f"results: {output}")
    print(f"summary: {summary_path}")
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description="Run FitAI coach evaluation scenarios")
    parser.add_argument(
        "--scenarios",
        default=str(Path(__file__).resolve().parent / "scenarios" / "calibration_100.jsonl"),
    )
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--category", default=None)
    parser.add_argument("--output", default="eval/results/calibration.jsonl")
    parser.add_argument("--summary", default=None)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    raise SystemExit(asyncio.run(main_async(args)))


if __name__ == "__main__":
    main()
