r"""Real-LLM quality evaluation for the coach control plane.

The facts are seeded into a temporary SQLite database, so numbers, readiness
and progression targets are deterministic; only the wording comes from the
real model. This is the repeatable baseline that the production smoke alone
could not provide.

Run from ``backend`` with a real key in ``.env``:

    .\.venv\Scripts\python.exe -m eval.coach_control_quality

The output is written to ``eval/baselines/coach_control_quality.json``.
"""

from __future__ import annotations

import asyncio
import json
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.config import settings  # noqa: E402
from app.db import Base  # noqa: E402
from app.models import (  # noqa: E402
    Exercise,
    Goal,
    PlanExercise,
    Profile,
    Program,
    ProgramDay,
    SetLog,
    User,
    WorkoutSession,
)
from app.services import memory as memory_service  # noqa: E402
from app.services.coach_control import runtime  # noqa: E402

USER_ID = "eval-user"
TZ = ZoneInfo("Asia/Shanghai")
WEEKDAYS = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _seed(db) -> Program:
    now = _now()
    today = datetime.now(TZ).date()
    monday = today - timedelta(days=today.weekday())

    db.add(User(id=USER_ID))
    db.add(
        Profile(
            user_id=USER_ID,
            nickname="评估用户",
            sex="male",
            birth_date=today.replace(year=today.year - 30),
            height_cm=178,
            weight_kg=72,
            experience="intermediate",
            injuries=[],
            equipment=["bodyweight", "dumbbell"],
            weekly_days=3,
            session_minutes=45,
            onboarded_at=now,
        )
    )
    db.add(
        Goal(
            id="eval-goal",
            user_id=USER_ID,
            type="build_muscle",
            target_weight_kg=76,
            status="active",
        )
    )
    for slug, name, muscle, equipment in (
        ("push-up", "俯卧撑", "chest", "bodyweight"),
        ("dumbbell-curl", "哑铃弯举", "arms", "dumbbell"),
        ("air-squat", "徒手深蹲", "legs", "bodyweight"),
    ):
        db.add(
            Exercise(
                slug=slug,
                name_zh=name,
                muscle_group=muscle,
                equipment=equipment,
                training_type_code="strength",
                is_compound=slug != "dumbbell-curl",
                contraindications=[],
            )
        )
    db.add(
        Program(
            id="eval-program",
            user_id=USER_ID,
            title="四周评估计划",
            goal_type="build_muscle",
            version=1,
            status="active",
            start_date=monday,
            weeks=4,
            generated_by="template",
        )
    )
    db.flush()

    leg_day_id = ""
    for week in (1, 2):
        for weekday, title in ((2, "推"), (4, "拉"), (6, "腿")):
            day_id = f"eval-w{week}-d{weekday}"
            if title == "腿":
                leg_day_id = day_id
            slug, weight = {
                2: ("push-up", None),
                4: ("dumbbell-curl", 8.0),
                6: ("air-squat", None),
            }[weekday]
            db.add(
                ProgramDay(
                    id=day_id,
                    program_id="eval-program",
                    week_index=week,
                    weekday=weekday,
                    title=title,
                    focus=[{"推": "chest", "拉": "back", "腿": "legs"}[title]],
                )
            )
            db.add(
                PlanExercise(
                    id=f"eval-ex-{week}-{weekday}",
                    program_day_id=day_id,
                    exercise_slug=slug,
                    order_index=1,
                    sets=3,
                    reps="10-12",
                    weight_kg=weight,
                    rest_sec=60,
                    rpe=7,
                )
            )

    # Five sessions in the last seven days with RPE 9 create ACWR 3.33.
    for index, days_ago in enumerate((1, 2, 3, 4, 6, 10), start=1):
        started = now - timedelta(days=days_ago)
        session_id = f"eval-session-{index}"
        db.add(
            WorkoutSession(
                id=session_id,
                user_id=USER_ID,
                client_id=f"eval-client-{index}",
                program_day_id=leg_day_id,
                source="phone",
                revision=1,
                started_at=started,
                finished_at=started + timedelta(minutes=90),
                duration_min=90,
                feeling=3,
            )
        )
        for set_index in (1, 2, 3):
            db.add(
                SetLog(
                    id=f"eval-set-{index}-{set_index}",
                    session_id=session_id,
                    exercise_slug="air-squat",
                    set_index=set_index,
                    weight_kg=0,
                    reps=12,
                    rpe=9,
                    completed=True,
                )
            )
    db.commit()
    program = db.get(Program, "eval-program")
    assert program is not None
    return program


def _disable_background_writes() -> None:
    memory_service.schedule_memory_extraction = lambda *args, **kwargs: None
    memory_service.schedule_session_summary = lambda *args, **kwargs: None


def _pending(result: dict) -> dict:
    return result.get("pending") or {}


def _air_squat(day_id: str):
    return (
        select(PlanExercise)
        .where(
            PlanExercise.program_day_id == day_id,
            PlanExercise.exercise_slug == "air-squat",
        )
    )


def _reply_has(reply: str, words: tuple[str, ...]) -> bool:
    return any(word in reply for word in words)


def _check(name: str, condition: bool, detail: str) -> dict:
    return {"name": name, "passed": condition, "detail": detail}


def _read_checks(name: str, result: dict, reply: str) -> list[dict]:
    intent = result.get("intent")
    pending = _pending(result)
    if name == "readiness_high_load":
        return [
            _check("intent", intent == "coach.answer", str(intent)),
            _check("no_card", not pending, str(pending)),
            _check(
                "status",
                _reply_has(reply, ("偏高", "高", "负荷", "减载")),
                reply[:200],
            ),
            _check(
                "has_numbers",
                "3.33" in reply or "ACWR" in reply or "5 次" in reply,
                reply[:200],
            ),
        ]
    if name == "weekly_review":
        payload = pending.get("payload") or {}
        stats = payload.get("stats") or {}
        progression = payload.get("progression") or {}
        exercises = [
            item
            for day in progression.get("days") or []
            for item in (day.get("payload") or {}).get("exercises") or []
        ]
        return [
            _check("intent", intent == "review.weekly", str(intent)),
            _check("readiness", stats.get("readiness_status") == "high_risk", str(stats)),
            _check(
                "down_target",
                any(
                    item.get("slug") == "air-squat" and item.get("sets") == 2
                    for item in exercises
                ),
                str(exercises)[:300],
            ),
        ]
    if name == "progression_down_read":
        return [
            _check("intent", intent == "coach.answer", str(intent)),
            _check("no_card", not pending, str(pending)),
            _check(
                "down_advice",
                _reply_has(reply, ("2 组", "减", "降", "少做")),
                reply[:200],
            ),
        ]
    if name == "progression_up_read":
        return [
            _check("intent", intent == "coach.answer", str(intent)),
            _check("no_card", not pending, str(pending)),
            _check(
                "rep_target",
                "14" in reply and any(word in reply for word in ("10", "12")),
                reply[:200],
            ),
            _check(
                "sets_not_invented",
                not any(word in reply for word in ("4 组", "四组", "4组")),
                reply[:200],
            ),
        ]
    if name == "injury":
        fabricated = ("腰伤", "胸痛", "膝伤", "受伤史")
        return [
            _check("intent", intent == "coach.answer", str(intent)),
            _check("no_card", not pending, str(pending)),
            _check(
                "no_injury",
                _reply_has(reply, ("没有", "无记录", "没记录")),
                reply[:200],
            ),
            _check(
                "no_fabrication",
                not any(word in reply for word in fabricated),
                reply[:200],
            ),
        ]
    if name == "plan_explanation":
        return [
            _check("intent", intent == "coach.answer", str(intent)),
            _check("no_card", not pending, str(pending)),
            _check(
                "plan_terms",
                _reply_has(reply, ("推", "拉", "腿", "三分化")),
                reply[:200],
            ),
            _check("not_generated", "已生成" not in reply, reply[:200]),
        ]
    if name == "week2":
        return [
            _check("intent", intent == "training.week_schedule", str(intent)),
            _check("insight", pending.get("kind") == "insight", str(pending)),
            _check(
                "bullets",
                "•" in reply and "? " not in reply,
                reply[:200],
            ),
            _check(
                "week_label",
                "第 2 周" in reply or "第2周" in reply,
                reply[:200],
            ),
        ]
    if name == "profile_gap":
        return [
            _check("intent", intent == "coach.answer", str(intent)),
            _check(
                "complete",
                _reply_has(reply, ("完整", "没缺", "没有缺", "不缺", "齐了")),
                reply[:200],
            ),
            _check("no_false_gap", "缺体重" not in reply, reply[:200]),
        ]
    if name == "diet_empty":
        return [
            _check("intent", intent == "coach.answer", str(intent)),
            _check(
                "empty",
                (
                    ("没有" in reply and ("记录" in reply or "记下" in reply))
                    or _reply_has(
                        reply,
                        ("没记", "0 条", "一条没记", "没数据", "一条记录都没有"),
                    )
                ),
                reply[:200],
            ),
        ]
    if name == "exercise_howto":
        return [
            _check("intent", intent == "coach.answer", str(intent)),
            _check("no_card", not pending, str(pending)),
            _check(
                "technique",
                _reply_has(reply, ("脚", "膝", "蹲", "髋")),
                reply[:200],
            ),
        ]
    if name == "today":
        label = WEEKDAYS[datetime.now(TZ).date().weekday()]
        return [
            _check("intent", intent == "coach.answer", str(intent)),
            _check(
                "weekday",
                label in reply or label.replace("周", "星期") in reply,
                f"expected={label} reply={reply[:160]}",
            ),
        ]
    return [_check("known_case", False, name)]


async def _run() -> int:
    if settings.use_mock_llm:
        print("LLM_API_KEY is missing; refusing to create a fake baseline.")
        return 2
    _disable_background_writes()
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(
        bind=engine,
        autoflush=False,
        expire_on_commit=False,
    )
    db = Session()
    _seed(db)
    cases: list[dict] = []

    async def ask(
        name: str,
        message: str,
        session_id: str,
        checks: list[dict] | None = None,
    ) -> dict:
        started = time.perf_counter()
        result = await runtime.handle_turn(
            db,
            USER_ID,
            message,
            session_id=session_id,
        )
        latency = int((time.perf_counter() - started) * 1000)
        reply = str(result.get("reply") or "")
        resolved_checks = (
            checks if checks is not None else _read_checks(name, result, reply)
        )
        cases.append(
            {
                "name": name,
                "message": message,
                "intent": result.get("intent"),
                "latency_ms": latency,
                "reply": reply,
                "pending": _pending(result),
                "checks": resolved_checks,
                "passed": all(item["passed"] for item in resolved_checks),
            }
        )
        return result

    await ask("readiness_high_load", "我最近恢复得怎么样", "case-readiness")
    await ask("weekly_review", "这周复盘", "case-review")
    await ask(
        "progression_down_read",
        "下周徒手深蹲加多少",
        "case-progression-down-read",
    )

    down = await ask(
        "progression_down_apply",
        "帮我按建议改下周",
        "case-progression-down-apply",
        checks=[],
    )
    pending = _pending(down)
    confirmed = runtime.confirm_pending(db, USER_ID, pending["id"])
    _apply_payload = pending.get("payload") or {}
    _items = _apply_payload.get("batch") or [{"payload": _apply_payload}]
    _leg = next(
        (
            item.get("payload") or {}
            for item in _items
            if (item.get("payload") or {}).get("day_id") == "eval-w2-d6"
        ),
        {},
    )
    day_id = str(_leg.get("day_id") or "")
    after_confirm = db.execute(_air_squat(day_id)).scalar_one()
    sets_after_confirm = int(after_confirm.sets)
    runtime.undo_action(db, USER_ID, confirmed["action_id"])
    after_undo = db.execute(_air_squat(day_id)).scalar_one()
    down_checks = [
        _check(
            "capability",
            pending.get("capability_id")
            in {"training.edit_day_exercise", "coach.batch"},
            str(pending.get("capability_id")),
        ),
        _check(
            "leg_target",
            any(
                item.get("slug") == "air-squat" and item.get("sets") == 2
                for item in _leg.get("exercises") or []
            ),
            str(_leg.get("exercises"))[:300],
        ),
        _check(
            "sets_after_confirm",
            sets_after_confirm == 2,
            str(sets_after_confirm),
        ),
        _check(
            "sets_after_undo",
            int(after_undo.sets) == 3,
            str(after_undo.sets),
        ),
    ]
    cases[-1]["checks"] = down_checks
    cases[-1]["passed"] = all(item["passed"] for item in down_checks)

    latest_sets = (
        db.execute(
            select(SetLog)
            .where(SetLog.session_id == "eval-session-1")
            .order_by(SetLog.set_index)
        )
        .scalars()
        .all()
    )
    for item in latest_sets:
        item.rpe = 7
    db.commit()

    await ask(
        "progression_up_read",
        "下周徒手深蹲加多少",
        "case-progression-up-read",
    )
    up = await ask(
        "progression_up_apply",
        "帮我按建议改下周",
        "case-progression-up-apply",
        checks=[],
    )
    pending = _pending(up)
    confirmed = runtime.confirm_pending(db, USER_ID, pending["id"])
    _apply_payload = pending.get("payload") or {}
    _items = _apply_payload.get("batch") or [{"payload": _apply_payload}]
    _leg = next(
        (
            item.get("payload") or {}
            for item in _items
            if (item.get("payload") or {}).get("day_id") == "eval-w2-d6"
        ),
        {},
    )
    day_id = str(_leg.get("day_id") or "")
    after_confirm = db.execute(_air_squat(day_id)).scalar_one()
    reps_after_confirm = str(after_confirm.reps)
    runtime.undo_action(db, USER_ID, confirmed["action_id"])
    after_undo = db.execute(_air_squat(day_id)).scalar_one()
    up_checks = [
        _check(
            "capability",
            pending.get("capability_id")
            in {"training.edit_day_exercise", "coach.batch"},
            str(pending.get("capability_id")),
        ),
        _check(
            "leg_target",
            any(
                item.get("slug") == "air-squat"
                and item.get("reps") == "10-14"
                for item in _leg.get("exercises") or []
            ),
            str(_leg.get("exercises"))[:300],
        ),
        _check(
            "reps_after_confirm",
            reps_after_confirm == "10-14",
            reps_after_confirm,
        ),
        _check(
            "reps_after_undo",
            str(after_undo.reps) == "10-12",
            str(after_undo.reps),
        ),
    ]
    cases[-1]["checks"] = up_checks
    cases[-1]["passed"] = all(item["passed"] for item in up_checks)

    await ask("injury", "我有伤病吗", "case-injury")
    await ask("plan_explanation", "为什么这样安排计划", "case-plan")
    await ask("week2", "第二周每天练什么", "case-week2")
    await ask("profile_gap", "我还缺什么档案", "case-profile")
    await ask("diet_empty", "最近饮食怎么样", "case-diet")
    await ask("exercise_howto", "深蹲怎么做", "case-howto")
    await ask("today", "今天周几", "case-today")

    db.close()
    engine.dispose()

    passed = sum(1 for item in cases if item["passed"])
    total = len(cases)
    output = {
        "generated_at": _now().isoformat(),
        "model": settings.llm_model,
        "total": total,
        "passed": passed,
        "pass_rate": round(passed / total, 3) if total else 0,
        "cases": cases,
    }
    path = BACKEND_ROOT / "eval" / "baselines" / "coach_control_quality.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(output, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"coach control quality: {passed}/{total} ({output['pass_rate']})")
    for item in cases:
        mark = "PASS" if item["passed"] else "FAIL"
        print(f"  {mark} {item['name']} {item['latency_ms']}ms")
        for check in item["checks"]:
            if not check["passed"]:
                print(f"       - {check['name']}: {check['detail'][:240]}")
    print("saved:", path)
    return 0 if passed == total else 1


def main() -> None:
    sys.exit(asyncio.run(_run()))


if __name__ == "__main__":
    main()
