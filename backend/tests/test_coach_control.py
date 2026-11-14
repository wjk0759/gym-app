from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import (
    BodyMetric,
    CoachActionRecord,
    CoachInbox,
    CoachPending,
    CoachSession,
    CoachTurn,
    DomainEvent,
    Exercise,
    FoodLog,
    Goal,
    PlanDayState,
    PlanExercise,
    Profile,
    Program,
    ProgramDay,
    User,
)
from app.services.coach_control import runtime


@pytest.fixture()
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    session = Session()
    session.add(User(id="user-1", phone="13428104171", status="active"))
    session.add(
        Profile(
            user_id="user-1",
            nickname="测试",
            sex="male",
            birth_date=date(1996, 1, 1),
            height_cm=178,
            weight_kg=72,
            weekly_days=3,
            session_minutes=45,
        )
    )
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def test_food_card_confirm_undo_and_event(db):
    import asyncio

    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "午餐吃了 100 克鸡胸肉",
        )
    )

    assert turn["intent"] == "diet.log_food"
    assert turn["pending"]["kind"] == "card"
    pending_id = turn["pending"]["id"]

    confirmed = runtime.confirm_pending(db, "user-1", pending_id)
    assert confirmed["status"] == "executed"
    assert confirmed["receipt"]["summary"] == "已写入饮食记录"
    assert db.execute(select(FoodLog)).scalars().all()

    event = db.execute(select(DomainEvent)).scalar_one()
    assert event.type == "FoodLogged"

    undone = runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert undone["status"] == "undone"
    assert db.execute(select(FoodLog)).scalars().all() == []
    record = db.execute(select(CoachActionRecord)).scalar_one()
    assert record.status == "undone"


def test_planned_meal_log_and_skip_loop(db):
    import asyncio

    from app.models import MealPlan
    from app.services.meal_plans import save_day_plan

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    save_day_plan(
        db,
        "user-1",
        today,
        {
            "meals": [
                {
                    "meal": "lunch",
                    "name": "鸡胸饭",
                    "kcal": 600,
                    "protein_g": 40,
                    "carb_g": 70,
                    "fat_g": 15,
                },
                {
                    "meal": "dinner",
                    "name": "牛肉饭",
                    "kcal": 650,
                    "protein_g": 35,
                    "carb_g": 80,
                    "fat_g": 18,
                },
            ]
        },
        strategy="balanced",
        generated_by="template",
    )
    db.commit()

    planned = asyncio.run(
        runtime.handle_turn(db, "user-1", "记录今天的计划午餐")
    )
    assert planned["intent"] == "diet.log_planned_meal"
    assert planned["pending"]["kind"] == "card"
    confirmed = runtime.confirm_pending(db, "user-1", planned["pending"]["id"])
    assert confirmed["status"] == "executed"
    assert db.execute(select(FoodLog)).scalar_one().plan_meal == "lunch"
    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.execute(select(FoodLog)).scalars().all() == []

    skipped = asyncio.run(runtime.handle_turn(db, "user-1", "跳过今天晚餐"))
    assert skipped["intent"] == "diet.skip_planned_meal"
    runtime.confirm_pending(db, "user-1", skipped["pending"]["id"])
    record = db.execute(select(MealPlan)).scalar_one()
    assert "dinner" in record.plan.get("skipped_meals", [])

    restored = asyncio.run(runtime.handle_turn(db, "user-1", "恢复今天晚餐"))
    assert restored["intent"] == "diet.restore_planned_meal"
    runtime.confirm_pending(db, "user-1", restored["pending"]["id"])
    db.refresh(record)
    assert "dinner" not in record.plan.get("skipped_meals", [])


def test_plan_generation_confirm_activates_program(db, monkeypatch):
    import asyncio

    from app.models import Exercise, Program
    from app.services import access
    from app.services.coach_control.capabilities import plan as plan_capability

    db.add(
        Exercise(
            slug="barbell-bench-press",
            name_zh="杠铃卧推",
            name_en="barbell bench press",
            muscle_group="chest",
            equipment="barbell",
            is_compound=True,
            contraindications=[],
        )
    )
    db.commit()

    async def fake_generate(db, profile, **kwargs):
        return {
            "plan": {
                "title": "测试四周计划",
                "weeks": 4,
                "days": [
                    {
                        "week_index": 1,
                        "weekday": 1,
                        "title": "上肢",
                        "focus": ["chest"],
                        "exercises": [
                            {
                                "slug": "barbell-bench-press",
                                "order_index": 1,
                                "sets": 3,
                                "reps": "8",
                                "weight_kg": 40,
                                "rest_sec": 60,
                                "rpe": 7,
                            }
                        ],
                    }
                ],
            },
            "generated_by": "ai",
            "model": "test",
            "warnings": [],
        }

    monkeypatch.setattr(plan_capability, "generate_plan", fake_generate)
    monkeypatch.setattr(access, "has_pro", lambda db, user_id: True)

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "帮我生成一个 4 周计划")
    )
    assert turn["intent"] == "training.generate_plan"
    assert turn["pending"]["kind"] == "proposal"
    program_id = turn["pending"]["payload"]["program_id"]

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert confirmed["status"] == "executed"
    assert confirmed["plan"]["title"] == "测试四周计划"
    program = db.get(Program, program_id)
    assert program.status == "active"

    adjusted = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "计划太累了，减量",
            session_id=turn["session"]["id"],
        )
    )
    assert adjusted["intent"] == "training.adjust_plan"
    assert adjusted["pending"]["kind"] == "proposal"
    adjusted_program_id = adjusted["pending"]["payload"]["program_id"]
    second = runtime.confirm_pending(db, "user-1", adjusted["pending"]["id"])
    assert db.get(Program, adjusted_program_id).status == "active"
    assert "减量" in db.get(Program, adjusted_program_id).title

    runtime.undo_action(db, "user-1", second["action_id"])
    assert db.get(Program, program_id).status == "active"
    assert db.get(Program, adjusted_program_id).status == "archived"


def test_strength_log_confirm_and_undo(db):
    import asyncio

    from app.models import WorkoutSession

    db.add(
        Exercise(
            slug="barbell-bench-press",
            name_zh="杠铃卧推",
            name_en="barbell bench press",
            muscle_group="chest",
            equipment="barbell",
            is_compound=True,
            contraindications=[],
        )
    )
    db.commit()

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "今天卧推 60kg 8次 3组")
    )
    assert turn["intent"] == "training.log_strength"
    assert turn["pending"]["kind"] == "card"
    assert len(turn["pending"]["payload"]["sets"]) == 3

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    session = db.execute(select(WorkoutSession)).scalar_one()
    assert session.sets[0].exercise_slug == "barbell-bench-press"
    assert session.sets[0].weight_kg == 60
    assert db.execute(select(DomainEvent)).scalar_one().type == "WorkoutLogged"
    inbox = db.execute(select(CoachInbox)).scalars().all()
    assert any(item.kind == "workout" for item in inbox)

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.execute(select(WorkoutSession)).scalars().all() == []


def test_safety_block_prevents_a_pending_strength_write(db):
    import asyncio

    from app.models import WorkoutSession

    db.add(
        Exercise(
            slug="barbell-bench-press",
            name_zh="杠铃卧推",
            name_en="barbell bench press",
            muscle_group="chest",
            equipment="barbell",
            is_compound=True,
            contraindications=[],
        )
    )
    db.commit()

    first = asyncio.run(
        runtime.handle_turn(db, "user-1", "今天卧推 60kg 8次 3组")
    )
    assert first["pending"]["kind"] == "card"

    blocked = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "膝盖疼，还能深蹲 100kg 5组吗",
            session_id=first["session"]["id"],
        )
    )
    assert blocked["intent"] == "safety"
    assert blocked["status"] == "blocked"
    assert blocked["pending"] is None
    assert "先停" in blocked["reply"]
    assert (
        db.execute(
            select(CoachPending).where(CoachPending.status == "pending")
        ).scalars().all()
        == []
    )
    assert db.execute(select(WorkoutSession)).scalars().all() == []
    event = db.execute(
        select(DomainEvent).where(DomainEvent.type == "SafetyBlocked")
    ).scalar_one()
    assert event.payload["flag"] == "injury_guard"


def test_safety_block_handles_crisis_language(db):
    import asyncio

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "我不想活了"))
    assert turn["intent"] == "safety"
    assert turn["status"] == "blocked"
    assert turn["pending"] is None
    assert "安全" in turn["reply"]


def test_cardio_log_confirm_and_undo(db):
    import asyncio

    from app.models import WorkoutSession

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "昨天跑了 30 分钟"))
    assert turn["intent"] == "training.log_cardio"
    assert turn["pending"]["kind"] == "card"
    assert turn["pending"]["payload"]["duration_minutes"] == 30

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    session = db.execute(select(WorkoutSession)).scalar_one()
    assert session.duration_min == 30
    assert db.execute(select(DomainEvent)).scalar_one().type == "WorkoutLogged"

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.execute(select(WorkoutSession)).scalars().all() == []


def test_correction_without_context_does_not_create_a_food_draft(db):
    import asyncio

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "记错了 今天是74kg"))
    assert turn["intent"] == "clarification"
    assert turn["pending"] is None
    assert "体重" in turn["reply"]


def test_weight_correction_after_undo_keeps_context(db):
    import asyncio

    first = asyncio.run(runtime.handle_turn(db, "user-1", "今天体重 73kg"))
    confirmed = runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    runtime.undo_action(db, "user-1", confirmed["action_id"])

    corrected = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "记错了 今天是74kg",
            session_id=first["session"]["id"],
        )
    )

    assert corrected["intent"] == "body.log_weight"
    assert corrected["pending"]["kind"] == "card"
    assert corrected["pending"]["payload"]["weight_kg"] == 74.0
    assert corrected["pending"]["capability_id"] == "body.log_weight"


def test_goal_update_confirm_and_undo(db):
    import asyncio

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "目标体重 68kg"))
    assert turn["intent"] == "profile.update_goal"
    assert turn["pending"]["kind"] == "card"
    assert turn["pending"]["payload"]["target_weight_kg"] == 68

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    goal = db.execute(select(Goal)).scalar_one()
    assert goal.target_weight_kg == 68
    assert db.execute(select(DomainEvent)).scalar_one().type == "GoalUpdated"

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.execute(select(Goal)).scalars().all() == []


def test_body_weight_confirm_and_undo(db):
    import asyncio

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "今天体重 72.5kg"))
    assert turn["intent"] == "body.log_weight"
    assert turn["pending"]["kind"] == "card"
    assert turn["pending"]["payload"]["weight_kg"] == 72.5

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    metric = db.execute(select(BodyMetric)).scalar_one()
    assert metric.weight_kg == 72.5
    assert db.execute(select(DomainEvent)).scalar_one().type == "BodyMetricLogged"

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.execute(select(BodyMetric)).scalars().all() == []


def test_inbox_unread_filter_and_read_all(db):
    from app.models import utcnow
    from app.services.coach_control.events import create_inbox_item, list_inbox

    first = create_inbox_item(
        db,
        "user-1",
        kind="workout",
        title="训练已记录",
        body="这次训练已保存。",
    )
    create_inbox_item(
        db,
        "user-1",
        kind="plan",
        title="训练计划已更新",
        body="新版本计划已经生效。",
    )
    db.commit()

    assert len(list_inbox(db, "user-1")) == 2
    assert len(list_inbox(db, "user-1", status="unread")) == 2

    first.status = "read"
    first.read_at = utcnow()
    db.commit()

    unread = list_inbox(db, "user-1", status="unread")
    assert [item["kind"] for item in unread] == ["plan"]
    read = list_inbox(db, "user-1", status="read")
    assert [item["kind"] for item in read] == ["workout"]


def test_skipped_meal_creates_an_actionable_inbox_item(db):
    from app.services.coach_control.consumers import consume_event
    from app.services.coach_control.events import emit_event

    event = emit_event(
        db,
        "user-1",
        "PlannedMealSkipped",
        entity_type="food_log",
        payload={},
    )
    consume_event(db, event)
    db.commit()

    item = db.execute(
        select(CoachInbox).where(CoachInbox.kind == "diet")
    ).scalar_one()
    assert item.payload["prompt"] == "今天饮食还缺什么？"


def test_safety_reply_bypasses_exhausted_free_quota(db):
    import asyncio

    from fastapi import HTTPException

    from app.routers.coach_control import CoachTurnIn, create_turn
    from app.services import access

    for _ in range(access.COACH_DAILY_LIMIT):
        assert access.reserve_coach_message(db, "user-1")

    with pytest.raises(HTTPException) as exc:
        asyncio.run(
            create_turn(CoachTurnIn(message="复盘本周"), "user-1", db)
        )
    assert exc.value.status_code == 429

    turn = asyncio.run(
        create_turn(CoachTurnIn(message="我不想活了"), "user-1", db)
    )
    assert turn["intent"] == "safety"
    assert turn["status"] == "blocked"


def test_unsupported_turn_releases_free_quota(db):
    import asyncio

    from app.models import User
    from app.routers.coach_control import CoachTurnIn, create_turn
    from app.services import access

    db.add(User(id="user-2", phone="13428104172", status="active"))
    db.commit()

    used, _, _ = access.coach_usage(db, "user-2")
    assert used == 0

    turn = asyncio.run(create_turn(CoachTurnIn(message="你好"), "user-2", db))
    assert turn["intent"] == "unsupported"

    used, _, _ = access.coach_usage(db, "user-2")
    assert used == 0


def test_client_events_are_ingested_and_excluded_from_context(db):
    from app.routers.telemetry import (
        ClientEventBatchIn,
        ClientEventIn,
        ingest_client_events,
    )
    from app.services.coach_control.context import build_control_context

    result = ingest_client_events(
        ClientEventBatchIn(
            events=[
                ClientEventIn(
                    name="app_open",
                    properties={"version": "0.1.0"},
                ),
                ClientEventIn(
                    name="paywall_shown",
                    properties={"feature": "coach"},
                ),
                ClientEventIn(
                    name="not_allowed_event",
                    properties={"junk": "x"},
                ),
            ]
        ),
        "user-1",
        db,
    )
    assert result == {"ok": True, "accepted": 2}

    events = db.execute(
        select(DomainEvent).where(DomainEvent.type == "ClientEvent")
    ).scalars().all()
    assert [event.payload["name"] for event in events] == [
        "app_open",
        "paywall_shown",
    ]

    context = build_control_context(db, "user-1")
    assert all(item["type"] != "ClientEvent" for item in context["recent_events"])


def test_client_diagnostic_is_audited(db):
    from app.routers.coach_control import ClientDiagnosticIn, upload_client_diagnostic

    result = upload_client_diagnostic(
        ClientDiagnosticIn(
            kind="metrickit",
            app_version="0.1.0",
            data_base64="eyJjcmFzaCI6MX0=",
        ),
        "user-1",
        db,
    )
    assert result["ok"] is True
    event = db.execute(
        select(DomainEvent).where(DomainEvent.type == "ClientDiagnostic")
    ).scalar_one()
    assert event.payload["app_version"] == "0.1.0"
    assert event.payload["data_base64"]


def test_stats_include_intents_pending_and_daily_counts(db):
    import asyncio

    from app.routers.coach_control import coach_stats

    asyncio.run(runtime.handle_turn(db, "user-1", "复盘本周"))
    stats = coach_stats("user-1", db)
    assert stats["intents"]["review.weekly"] == 1
    assert stats["pending"]["pending"] == 1
    assert stats["daily_turns"][-1]["count"] >= 1
    assert stats["inbox_unread"] == 0


def test_coach_history_paginates_with_cursor(db):
    from app.routers.coach_control import coach_history

    db.add(CoachSession(id="session-1", user_id="user-1"))
    base = datetime(2026, 1, 1, 8, 0, tzinfo=timezone.utc)
    for index in range(5):
        db.add(
            CoachTurn(
                id=f"00000000-0000-0000-0000-00000000000{index}",
                session_id="session-1",
                user_id="user-1",
                input_text=f"m{index}",
                reply=f"r{index}",
                created_at=base + timedelta(minutes=index),
            )
        )
    db.commit()

    latest = coach_history("session-1", "user-1", db, limit=2)
    assert [item["input_text"] for item in latest["items"]] == ["m3", "m4"]
    assert latest["has_more"] is True
    assert latest["next_before_id"] == "00000000-0000-0000-0000-000000000003"

    earlier = coach_history(
        "session-1",
        "user-1",
        db,
        limit=2,
        before_id=latest["next_before_id"],
    )
    assert [item["input_text"] for item in earlier["items"]] == ["m1", "m2"]
    assert earlier["has_more"] is True

    oldest = coach_history(
        "session-1",
        "user-1",
        db,
        limit=2,
        before_id=earlier["next_before_id"],
    )
    assert [item["input_text"] for item in oldest["items"]] == ["m0"]
    assert oldest["has_more"] is False
    assert oldest["next_before_id"] is None


def test_control_context_contains_recent_events_and_last_action(db):
    import asyncio

    from app.services.coach_control.context import build_control_context

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "今天体重 73kg"))
    runtime.confirm_pending(db, "user-1", turn["pending"]["id"])

    context = build_control_context(db, "user-1")
    assert context["version"] == "coach-control-v1"
    assert context["coach_context"]["today"]["date"]
    assert context["recent_events"][0]["type"] == "BodyMetricLogged"
    assert context["last_action"]["capability_id"] == "body.log_weight"


def test_weekly_review_is_an_insight_not_a_write(db):
    import asyncio

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "复盘本周"))
    assert turn["intent"] == "review.weekly"
    assert turn["pending"]["kind"] == "insight"
    assert turn["pending"]["payload"]["summary"]
    assert turn["reply"]

    cancelled = runtime.cancel(db, "user-1", turn["pending"]["id"])
    assert cancelled["ok"] is True
    assert db.execute(select(CoachPending)).scalar_one().status == "cancelled"


def test_training_skip_confirm_and_undo(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    context = {
        "plan": {
            "id": "plan-1",
            "version": 1,
            "days": [
                {
                    "id": "day-1",
                    "date": today.isoformat(),
                    "title": "下肢",
                    "completed": False,
                    "skipped": False,
                }
            ],
        }
    }
    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "今天不练了",
            app_context=context,
        )
    )
    assert turn["intent"] == "training.skip"
    assert turn["pending"]["kind"] == "card"

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    state = db.execute(select(PlanDayState)).scalar_one()
    assert state.skipped_at is not None
    assert db.execute(select(DomainEvent)).scalar_one().type == "TrainingSkipped"

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.execute(select(PlanDayState)).scalars().all() == []


def test_training_reschedule_confirm_and_undo(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    context = {
        "plan": {
            "id": "plan-1",
            "version": 3,
            "days": [
                {
                    "id": "day-1",
                    "date": today.isoformat(),
                    "title": "上肢",
                    "completed": False,
                    "skipped": False,
                }
            ],
        }
    }
    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "把今天的训练改到 11月20日",
            app_context=context,
        )
    )

    assert turn["intent"] == "training.reschedule"
    assert turn["pending"]["kind"] == "card"
    assert turn["pending"]["payload"]["to_date"].endswith("-11-20")

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert confirmed["status"] == "executed"
    state = db.execute(select(PlanDayState)).scalar_one()
    assert state.assigned_date == date(today.year, 11, 20)
    assert db.execute(select(DomainEvent)).scalar_one().type == "TrainingRescheduled"

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.execute(select(PlanDayState)).scalars().all() == []


def test_food_draft_can_be_completed_in_a_second_turn(db):
    import asyncio

    first = asyncio.run(
        runtime.handle_turn(db, "user-1", "午餐喝了奶茶")
    )
    assert first["pending"]["kind"] == "draft"
    assert first["pending"]["capability_id"] == "diet.log_food"

    second = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "250ml",
            session_id=first["session"]["id"],
        )
    )
    assert second["intent"] == "diet.log_food"
    assert second["pending"]["kind"] == "card"
    assert second["pending"]["payload"]["items"]

    pending = db.execute(select(CoachPending)).scalars().all()
    assert any(item.kind == "draft" and item.status == "cancelled" for item in pending)
    assert any(item.kind == "card" and item.status == "pending" for item in pending)


def test_draft_cannot_be_confirmed(db):
    import asyncio

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "午餐喝了奶茶"))
    with pytest.raises(ValueError):
        runtime.confirm_pending(db, "user-1", turn["pending"]["id"])


def test_cancel_clears_the_active_pending(db):
    import asyncio

    first = asyncio.run(runtime.handle_turn(db, "user-1", "午餐喝了奶茶"))
    assert first["pending"]["kind"] == "draft"

    second = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "算了",
            session_id=first["session"]["id"],
        )
    )
    assert second["pending"] is None
    assert "取消" in second["reply"]
    assert (
        db.execute(select(CoachPending)).scalar_one().status == "cancelled"
    )


def test_food_question_does_not_create_a_logging_draft(db, monkeypatch):
    import asyncio

    from app.config import settings

    monkeypatch.setattr(settings, "llm_provider", "mock")
    turn = asyncio.run(runtime.handle_turn(db, "user-1", "减脂怎么吃"))
    assert turn["intent"] == "coach.answer"
    assert turn["pending"] is None


def test_unrelated_message_cancels_a_stale_draft(db, monkeypatch):
    import asyncio

    from app.config import settings

    monkeypatch.setattr(settings, "llm_provider", "mock")
    first = asyncio.run(runtime.handle_turn(db, "user-1", "午餐喝了奶茶"))
    assert first["pending"]["kind"] == "draft"

    second = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "你好",
            session_id=first["session"]["id"],
        )
    )
    assert second["pending"] is None
    assert second["intent"] == "coach.answer"
    assert db.execute(select(CoachPending)).scalar_one().status == "cancelled"


def test_consumed_pending_cannot_be_confirmed_again(db):
    import asyncio

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "午餐吃了 100 克鸡胸肉"))
    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    runtime.undo_action(db, "user-1", confirmed["action_id"])
    with pytest.raises(ValueError):
        runtime.confirm_pending(db, "user-1", turn["pending"]["id"])


def test_card_and_draft_are_mutually_exclusive(db):
    import asyncio

    first = asyncio.run(
        runtime.handle_turn(db, "user-1", "午餐吃了 100 克鸡胸肉")
    )
    assert first["pending"]["kind"] == "card"

    second = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "晚餐吃了 100 克鸡胸肉",
            session_id=first["session"]["id"],
        )
    )
    assert second["pending"]["kind"] == "card"
    active = db.execute(
        select(CoachPending).where(CoachPending.status == "pending")
    ).scalars().all()
    assert len(active) == 1
    assert db.execute(select(CoachSession)).scalar_one().pending_id == active[0].id


def test_diet_day_review_is_deterministic_and_read_only(db):
    import asyncio

    from app.models import FoodLog

    noon = datetime.now(ZoneInfo("Asia/Shanghai")).replace(
        hour=12, minute=0, second=0, microsecond=0
    )
    db.add(
        FoodLog(
            user_id="user-1",
            client_id="log-1",
            logged_at=noon,
            meal="lunch",
            food_name="鸡胸肉",
            grams=150,
            kcal=250,
            protein=35,
            carbs=0,
            fat=5,
            fiber=0,
            source="manual",
        )
    )
    db.add(
        FoodLog(
            user_id="user-1",
            client_id="log-2",
            logged_at=noon,
            meal="lunch",
            food_name="米饭",
            grams=200,
            kcal=260,
            protein=5,
            carbs=58,
            fat=1,
            fiber=1,
            source="manual",
        )
    )
    db.commit()

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "今天饮食还缺什么？")
    )
    assert turn["intent"] == "diet.review_day"
    assert turn["pending"]["kind"] == "insight"
    assert turn["pending"]["capability_id"] == "diet.review_day"
    assert "kcal" in turn["reply"]
    assert "蛋白质" in turn["reply"]
    assert len(turn["pending"]["payload"]["wins"]) == 3
    assert db.execute(select(FoodLog)).scalars().all()

    empty = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "昨天饮食怎么样",
            session_id=turn["session"]["id"],
        )
    )
    assert empty["intent"] == "diet.review_day"
    assert "还没有饮食记录" in empty["reply"]


def test_diet_review_uses_the_plan_for_the_requested_day(db):
    from app.models import MealPlan
    from app.services.coach_control.capabilities import diet_review

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    db.add(
        MealPlan(
            user_id="user-1",
            plan_date=today,
            target_kcal=1800,
            target_protein_g=120,
            target_carb_g=180,
            target_fat_g=60,
            plan={},
        )
    )
    db.add(
        MealPlan(
            user_id="user-1",
            plan_date=today + timedelta(days=1),
            target_kcal=2500,
            target_protein_g=200,
            target_carb_g=250,
            target_fat_g=80,
            plan={},
        )
    )
    db.commit()
    db.add(
        FoodLog(
            user_id="user-1",
            client_id="review-log-1",
            logged_at=datetime.now(ZoneInfo("Asia/Shanghai")).replace(
                hour=12, minute=0, second=0, microsecond=0
            ),
            meal="lunch",
            food_name="鸡胸肉",
            grams=150,
            kcal=250,
            protein=35,
            carbs=0,
            fat=5,
            fiber=0,
            source="manual",
        )
    )
    db.commit()

    payload = diet_review.resolve(db, "user-1", "今天饮食怎么样")["payload"]
    assert "1800 kcal" in payload["summary"]
    assert "120 g" in payload["summary"]


def test_body_trend_review_uses_metrics_and_goal(db):
    import asyncio

    now = datetime.now(timezone.utc)
    db.add(
        BodyMetric(
            user_id="user-1",
            client_id="metric-1",
            measured_at=now - timedelta(weeks=8),
            weight_kg=74.5,
            body_fat_pct=24.0,
            waist_cm=86,
        )
    )
    db.add(
        BodyMetric(
            user_id="user-1",
            client_id="metric-2",
            measured_at=now - timedelta(days=1),
            weight_kg=73.2,
            body_fat_pct=23.0,
            waist_cm=84,
        )
    )
    db.add(
        Goal(
            user_id="user-1",
            type="lose_fat",
            target_weight_kg=70,
            status="active",
        )
    )
    db.commit()

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "最近体重怎么样")
    )
    assert turn["intent"] == "body.review_trend"
    assert turn["pending"]["kind"] == "insight"
    assert "74.5 kg" in turn["reply"]
    assert "73.2 kg" in turn["reply"]
    assert "70.0 kg" in turn["reply"]
    assert any("目标进度" in item for item in turn["pending"]["payload"]["wins"])


def test_training_preview_uses_the_client_schedule(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    context = {
        "plan": {
            "id": "plan-1",
            "days": [
                {
                    "id": "day-1",
                    "date": today.isoformat(),
                    "title": "上肢",
                    "completed": True,
                    "skipped": False,
                },
                {
                    "id": "day-2",
                    "date": (today + timedelta(days=1)).isoformat(),
                    "title": "下肢",
                    "completed": False,
                    "skipped": False,
                },
            ],
        }
    }
    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "明天练什么",
            app_context=context,
        )
    )
    assert turn["intent"] == "training.preview_next"
    assert turn["pending"]["kind"] == "insight"
    assert "明天" in turn["reply"]
    assert "下肢" in turn["reply"]


def test_free_chat_uses_the_control_session_and_history(db, monkeypatch):
    import asyncio

    from app.config import settings

    monkeypatch.setattr(settings, "llm_provider", "mock")
    first = asyncio.run(
        runtime.handle_turn(db, "user-1", "今天有点累，正常吗")
    )
    assert first["intent"] == "coach.answer"
    assert first["pending"] is None

    second = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "那我今天还练吗",
            session_id=first["session"]["id"],
        )
    )
    assert second["intent"] == "coach.answer"
    assert second["pending"] is None

    turns = db.execute(
        select(CoachTurn).where(CoachTurn.session_id == first["session"]["id"])
    ).scalars().all()
    assert [item.intent for item in turns] == ["coach.answer", "coach.answer"]


def test_negative_food_statement_does_not_create_a_draft(db, monkeypatch):
    import asyncio

    from app.config import settings

    monkeypatch.setattr(settings, "llm_provider", "mock")
    turn = asyncio.run(runtime.handle_turn(db, "user-1", "今天没吃晚饭"))
    assert turn["intent"] == "coach.answer"
    assert turn["pending"] is None


def test_body_composition_metrics_confirm_and_undo(db):
    import asyncio

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "体脂 22%，腰围 84cm")
    )
    assert turn["intent"] == "body.log_weight"
    assert turn["pending"]["kind"] == "card"
    payload = turn["pending"]["payload"]
    assert payload["body_fat_pct"] == 22.0
    assert payload["waist_cm"] == 84.0
    assert "weight_kg" not in payload

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    metric = db.execute(select(BodyMetric)).scalar_one()
    assert metric.body_fat_pct == 22.0
    assert metric.waist_cm == 84.0
    assert metric.weight_kg is None
    assert "体脂 22.0%" in confirmed["receipt"]["summary"]
    assert "腰围 84.0 cm" in confirmed["receipt"]["summary"]

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.execute(select(BodyMetric)).scalars().all() == []


def test_diet_plan_generation_confirm_and_undo(db, monkeypatch):
    import asyncio

    from app.config import settings
    from app.models import MealPlan
    from app.services.meal_plans import save_day_plan

    monkeypatch.setattr(settings, "llm_provider", "mock")
    tomorrow = datetime.now(ZoneInfo("Asia/Shanghai")).date() + timedelta(days=1)
    save_day_plan(
        db,
        "user-1",
        tomorrow,
        {"marker": "old", "targets": {}, "meals": []},
        strategy="balanced",
        generated_by="template",
    )
    db.commit()

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "帮我排明天的餐")
    )
    assert turn["intent"] == "diet.generate_day"
    assert turn["pending"]["kind"] == "proposal"
    payload = turn["pending"]["payload"]
    assert payload["date"] == tomorrow.isoformat()
    assert payload["diet_plan"]["meals"]

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert confirmed["status"] == "executed"
    assert "饮食计划" in confirmed["receipt"]["summary"]
    record = db.execute(select(MealPlan)).scalar_one()
    assert record.plan.get("marker") != "old"
    assert record.target_kcal
    assert db.execute(
        select(DomainEvent).where(DomainEvent.type == "DietPlanGenerated")
    ).scalar_one()

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    restored = db.execute(select(MealPlan)).scalar_one()
    assert restored.plan.get("marker") == "old"


def test_general_plan_edit_asks_for_specific_change(db):
    import asyncio

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "帮我改一下训练计划")
    )
    assert turn["intent"] == "training.edit_plan"
    assert turn["pending"] is None
    assert "改训练日" in turn["reply"]
    assert "换动作" in turn["reply"]
    assert "调强度" in turn["reply"]


def test_reschedule_uses_server_plan_dates_without_client_context(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    monday = today - timedelta(days=today.weekday())
    program = Program(
        user_id="user-1",
        title="测试计划",
        goal_type="recomp",
        version=1,
        status="active",
        start_date=monday,
        weeks=4,
    )
    db.add(program)
    db.flush()
    db.add(
        ProgramDay(
            program_id=program.id,
            week_index=1,
            weekday=today.isoweekday(),
            title="上肢",
        )
    )
    db.commit()

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "把今天的训练改到明天")
    )
    assert turn["intent"] == "training.reschedule"
    assert turn["pending"]["kind"] == "card"
    assert turn["pending"]["payload"]["to_date"] == (
        today + timedelta(days=1)
    ).isoformat()


def test_edit_day_exercises_confirm_and_undo(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    monday = today - timedelta(days=today.weekday())
    exercises = [
        ("bench_press", "杠铃卧推"),
        ("vital-incline-barbell-bench-press", "上斜杠铃卧推"),
        ("vital-seated-machine-chest-press", "器械推胸"),
        ("vital-machine-pec-deck-fly", "蝴蝶机夹胸"),
        ("old-dumbbell-press", "哑铃卧推"),
    ]
    for slug, name in exercises:
        db.add(
            Exercise(
                slug=slug,
                name_zh=name,
                name_en=slug,
                muscle_group="chest",
                equipment="barbell",
                is_compound=True,
                contraindications=[],
            )
        )
    db.commit()

    program = Program(
        user_id="user-1",
        title="测试胸计划",
        goal_type="build_muscle",
        version=1,
        status="active",
        start_date=monday,
        weeks=4,
    )
    db.add(program)
    db.flush()
    day = ProgramDay(
        program_id=program.id,
        week_index=1,
        weekday=today.isoweekday(),
        title="胸",
    )
    db.add(day)
    db.flush()
    db.add(
        PlanExercise(
            program_day_id=day.id,
            exercise_slug="old-dumbbell-press",
            order_index=1,
            sets=3,
            reps="8-12",
            rest_sec=90,
        )
    )
    db.commit()

    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "今天的练胸计划帮我改成："
            "杠铃卧推、上斜杠铃卧推、器械推胸、蝴蝶机",
        )
    )
    assert turn["intent"] == "training.edit_day_exercises"
    assert turn["pending"]["kind"] == "proposal"
    payload = turn["pending"]["payload"]
    assert [item["slug"] for item in payload["exercises"]] == [
        "bench_press",
        "vital-incline-barbell-bench-press",
        "vital-seated-machine-chest-press",
        "vital-machine-pec-deck-fly",
    ]
    assert any("蝴蝶机" in item for item in payload["watchouts"])

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    updated = db.get(ProgramDay, day.id)
    assert [item.exercise_slug for item in updated.exercises] == [
        "bench_press",
        "vital-incline-barbell-bench-press",
        "vital-seated-machine-chest-press",
        "vital-machine-pec-deck-fly",
    ]
    assert confirmed["plan"]["id"] == program.id

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    restored = db.get(ProgramDay, day.id)
    assert [item.exercise_slug for item in restored.exercises] == [
        "old-dumbbell-press"
    ]


def test_routing_eval_covers_deterministic_capabilities(db):
    """A small regression matrix for the intents the control plane owns.

    These utterances do not need the model: routing is decided by the
    deterministic parsers. Keep this table growing when a new capability or a
    common phrasing is added, so routing changes surface as test failures.
    """

    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    context = {
        "plan": {
            "id": "plan-1",
            "version": 1,
            "days": [
                {
                    "id": "day-1",
                    "date": today.isoformat(),
                    "title": "下肢",
                    "completed": False,
                    "skipped": False,
                },
                {
                    "id": "day-2",
                    "date": (today + timedelta(days=2)).isoformat(),
                    "title": "上肢",
                    "completed": False,
                    "skipped": False,
                },
            ],
        }
    }
    cases = [
        ("把今天的训练改到 11月20日", "training.reschedule"),
        ("帮我把周四的训练挪到周六", "training.reschedule"),
        ("今天不练了", "training.skip"),
        ("这周少练一次", "training.skip"),
        ("昨天跑了 30 分钟", "training.log_cardio"),
        ("今天骑车 45 分钟", "training.log_cardio"),
        ("今天卧推 60kg 8次 3组", "training.log_strength"),
        ("深蹲 100 公斤 5 组 5 次", "training.log_strength"),
        ("体重 73.5kg", "body.log_weight"),
        ("体脂 22%", "body.log_weight"),
        ("腰围 84cm", "body.log_weight"),
        ("帮我复盘本周", "review.weekly"),
        ("今天饮食还缺什么", "diet.review_day"),
        ("今天吃了什么", "diet.review_day"),
        ("蛋白质够吗", "diet.review_day"),
        ("最近体重怎么样", "body.review_trend"),
        ("目标进度", "body.review_trend"),
        ("今天练什么", "training.preview_next"),
        ("帮我生成一个 4 周计划", "training.generate_plan"),
        ("计划太累了，减量", "training.adjust_plan"),
        ("我想减脂，目标 72kg", "profile.update_goal"),
        ("按计划吃午餐", "diet.log_planned_meal"),
        ("跳过午餐", "diet.skip_planned_meal"),
        ("恢复晚餐", "diet.restore_planned_meal"),
        ("晚餐换一餐", "diet.swap_meal"),
    ]

    mismatches = []
    for index, (message, expected) in enumerate(cases):
        turn = asyncio.run(
            runtime.handle_turn(
                db,
                "user-1",
                message,
                session_id=f"eval-{index}",
                app_context=context,
            )
        )
        if turn["intent"] != expected:
            mismatches.append((message, expected, turn["intent"], turn["reply"]))

    assert not mismatches, mismatches
