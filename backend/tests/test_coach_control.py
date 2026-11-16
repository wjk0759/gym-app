from datetime import date, datetime, timedelta, timezone
from uuid import uuid4
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
    MealPlan,
    PlanDayState,
    PlanExercise,
    Profile,
    Program,
    ProgramDay,
    SetLog,
    User,
    WorkoutSession,
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


def test_cardio_card_accepts_a_new_duration(db):
    import asyncio

    first = asyncio.run(runtime.handle_turn(db, "user-1", "昨天跑了 30 分钟"))
    assert first["pending"]["payload"]["duration_minutes"] == 30
    second = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "改成 40 分钟",
            session_id=first["session"]["id"],
        )
    )
    assert second["pending"]["capability_id"] == "training.log_cardio"
    assert second["pending"]["payload"]["duration_minutes"] == 40
    active = db.execute(
        select(CoachPending).where(CoachPending.status == "pending")
    ).scalars().all()
    assert len(active) == 1


def test_goal_card_accepts_a_new_target(db):
    import asyncio

    first = asyncio.run(runtime.handle_turn(db, "user-1", "目标体重 68kg"))
    assert first["pending"]["payload"]["target_weight_kg"] == 68
    second = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "减到 70kg",
            session_id=first["session"]["id"],
        )
    )
    assert second["pending"]["capability_id"] == "profile.update_goal"
    assert second["pending"]["payload"]["target_weight_kg"] == 70
    active = db.execute(
        select(CoachPending).where(CoachPending.status == "pending")
    ).scalars().all()
    assert len(active) == 1


def test_weight_paraphrase_uses_scale_wording(db):
    import asyncio

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "我今天上秤73.5"))
    assert turn["intent"] == "body.log_weight"
    assert turn["pending"]["kind"] == "card"
    assert turn["pending"]["payload"]["weight_kg"] == 73.5


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


def test_body_metric_delete_only_clears_named_field_and_undo_restores(db):
    import asyncio

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "今天体重73kg，体脂22%")
    )
    runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    metric = db.execute(select(BodyMetric)).scalar_one()
    assert metric.weight_kg == 73
    assert metric.body_fat_pct == 22

    deleted = asyncio.run(
        runtime.handle_turn(db, "user-1", "删掉今天的体重记录")
    )
    assert deleted["intent"] == "body.delete_metric"
    assert deleted["pending"]["kind"] == "card"
    assert "体重 73" in deleted["pending"]["payload"]["summary"]

    confirmed = runtime.confirm_pending(
        db, "user-1", deleted["pending"]["id"]
    )
    metric = db.execute(select(BodyMetric)).scalar_one()
    assert metric.weight_kg is None
    assert metric.body_fat_pct == 22

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    metric = db.execute(select(BodyMetric)).scalar_one()
    assert metric.weight_kg == 73
    assert metric.body_fat_pct == 22


def test_body_metric_delete_whole_row_and_undo_recreates(db):
    import asyncio

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "今天体重73kg"))
    runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    metric_id = db.execute(select(BodyMetric)).scalar_one().id

    deleted = asyncio.run(
        runtime.handle_turn(db, "user-1", "删除今天的体重记录")
    )
    confirmed = runtime.confirm_pending(
        db, "user-1", deleted["pending"]["id"]
    )
    assert db.execute(select(BodyMetric)).scalars().all() == []

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    restored = db.execute(select(BodyMetric)).scalar_one()
    assert restored.id == metric_id
    assert restored.weight_kg == 73


def test_body_metric_delete_recent_picks_latest_record(db):
    import asyncio

    yesterday = asyncio.run(
        runtime.handle_turn(db, "user-1", "昨天体重72kg")
    )
    runtime.confirm_pending(db, "user-1", yesterday["pending"]["id"])
    today = asyncio.run(runtime.handle_turn(db, "user-1", "今天体重73kg"))
    runtime.confirm_pending(db, "user-1", today["pending"]["id"])

    deleted = asyncio.run(
        runtime.handle_turn(db, "user-1", "删除最近一条体重记录")
    )
    assert "体重 73" in deleted["pending"]["payload"]["summary"]
    runtime.confirm_pending(db, "user-1", deleted["pending"]["id"])
    remaining = db.execute(select(BodyMetric)).scalars().all()
    assert len(remaining) == 1
    assert remaining[0].weight_kg == 72
    profile = db.get(Profile, "user-1")
    assert profile is not None
    assert profile.weight_kg == 72


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
    assert set(confirmed["refresh_domains"]) == {"plan", "schedule", "diet"}
    state = db.execute(select(PlanDayState)).scalar_one()
    assert state.assigned_date == date(today.year, 11, 20)
    assert db.execute(select(DomainEvent)).scalar_one().type == "TrainingRescheduled"

    undone = runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert set(undone["refresh_domains"]) == {"plan", "schedule", "diet"}
    assert db.execute(select(PlanDayState)).scalars().all() == []


def test_training_reschedule_card_accepts_a_new_date(db):
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
    first = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "把今天的训练改到 11月20日",
            app_context=context,
        )
    )
    assert first["pending"]["payload"]["to_date"].endswith("-11-20")
    second = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "改到 11月22日",
            session_id=first["session"]["id"],
        )
    )
    assert second["pending"]["capability_id"] == "training.reschedule"
    assert second["pending"]["payload"]["to_date"].endswith("-11-22")
    active = db.execute(
        select(CoachPending).where(CoachPending.status == "pending")
    ).scalars().all()
    assert len(active) == 1


def test_batch_diet_and_reschedule_confirm_and_undo(db):
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
            "记午饭鸡胸肉200g，再把今天的训练改到11月20日",
            app_context=context,
        )
    )
    assert turn["pending"]["capability_id"] == "coach.batch"
    batch = turn["pending"]["payload"]["batch"]
    assert [item["capability_id"] for item in batch] == [
        "diet.log_food",
        "training.reschedule",
    ]

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert confirmed["status"] == "executed"
    assert len(db.execute(select(FoodLog)).scalars().all()) == 1
    assert db.execute(select(PlanDayState)).scalar_one().assigned_date == date(
        today.year, 11, 20
    )

    undone = runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert undone["restored"] is True
    assert db.execute(select(FoodLog)).scalars().all() == []
    assert db.execute(select(PlanDayState)).scalars().all() == []


def test_batch_food_delete_and_reschedule_confirm_and_undo(db):
    import asyncio

    first = asyncio.run(
        runtime.handle_turn(db, "user-1", "午餐吃了100g鸡胸肉")
    )
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    assert len(db.execute(select(FoodLog)).scalars().all()) == 1

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
            "删掉午餐鸡胸肉，再把今天的训练改到11月20日",
            app_context=context,
        )
    )
    assert turn["pending"]["capability_id"] == "coach.batch"
    assert [
        item["capability_id"] for item in turn["pending"]["payload"]["batch"]
    ] == ["diet.delete_log", "training.reschedule"]

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert db.execute(select(FoodLog)).scalars().all() == []
    assert db.execute(select(PlanDayState)).scalar_one().assigned_date == date(
        today.year, 11, 20
    )

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert len(db.execute(select(FoodLog)).scalars().all()) == 1
    assert db.execute(select(PlanDayState)).scalars().all() == []


def test_batch_exercise_swap_and_reschedule_confirm_and_undo(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    monday = today - timedelta(days=today.weekday())
    db.add_all(
        [
            Exercise(
                slug="barbell-bench-press",
                name_zh="杠铃卧推",
                name_en="barbell bench press",
                muscle_group="chest",
                equipment="barbell",
                is_compound=True,
                contraindications=[],
            ),
            Exercise(
                slug="dumbbell-bench-press",
                name_zh="哑铃卧推",
                name_en="dumbbell bench press",
                muscle_group="chest",
                equipment="dumbbell",
                is_compound=True,
                contraindications=[],
            ),
        ]
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
        focus=["chest"],
    )
    db.add(day)
    db.flush()
    db.add(
        PlanExercise(
            program_day_id=day.id,
            exercise_slug="barbell-bench-press",
            order_index=1,
            sets=3,
            reps="8-12",
            rest_sec=90,
        )
    )
    db.commit()

    context = {
        "plan": {
            "id": program.id,
            "version": program.version,
            "days": [
                {
                    "id": day.id,
                    "date": today.isoformat(),
                    "title": "胸",
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
            "把卧推换成哑铃卧推，再把今天的训练改到11月20日",
            app_context=context,
        )
    )
    assert turn["pending"]["capability_id"] == "coach.batch"
    assert [
        item["capability_id"] for item in turn["pending"]["payload"]["batch"]
    ] == ["training.edit_day_exercise", "training.reschedule"]

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    db.refresh(day)
    assert [item.exercise_slug for item in day.exercises] == [
        "dumbbell-bench-press"
    ]
    assert db.execute(select(PlanDayState)).scalar_one().assigned_date == date(
        today.year, 11, 20
    )

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    db.refresh(day)
    assert [item.exercise_slug for item in day.exercises] == [
        "barbell-bench-press"
    ]
    assert db.execute(select(PlanDayState)).scalars().all() == []


def test_batch_day_exercises_and_weight_confirm_and_undo(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    monday = today - timedelta(days=today.weekday())
    db.add_all(
        [
            Exercise(
                slug="barbell-bench-press",
                name_zh="杠铃卧推",
                name_en="barbell bench press",
                muscle_group="chest",
                equipment="barbell",
                is_compound=True,
                contraindications=[],
            ),
            Exercise(
                slug="incline-bench-press",
                name_zh="上斜卧推",
                name_en="incline bench press",
                muscle_group="chest",
                equipment="barbell",
                is_compound=True,
                contraindications=[],
            ),
        ]
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
        focus=["chest"],
    )
    db.add(day)
    db.flush()
    db.add(
        PlanExercise(
            program_day_id=day.id,
            exercise_slug="barbell-bench-press",
            order_index=1,
            sets=3,
            reps="8-12",
            rest_sec=90,
        )
    )
    db.commit()

    context = {
        "plan": {
            "id": program.id,
            "version": program.version,
            "days": [
                {
                    "id": day.id,
                    "date": today.isoformat(),
                    "title": "胸",
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
            "把今天的训练换成杠铃卧推、上斜卧推，再称体重73kg",
            app_context=context,
        )
    )
    assert turn["pending"]["capability_id"] == "coach.batch"
    assert [
        item["capability_id"] for item in turn["pending"]["payload"]["batch"]
    ] == ["training.edit_day_exercises", "body.log_weight"]

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    db.refresh(day)
    assert [item.exercise_slug for item in day.exercises] == [
        "barbell-bench-press",
        "incline-bench-press",
    ]
    assert db.execute(select(BodyMetric)).scalar_one().weight_kg == 73

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    db.refresh(day)
    assert [item.exercise_slug for item in day.exercises] == [
        "barbell-bench-press"
    ]
    assert db.execute(select(BodyMetric)).scalars().all() == []


def test_batch_workout_delete_and_weight_confirm_and_undo(db):
    import asyncio

    cardio = asyncio.run(runtime.handle_turn(db, "user-1", "昨天跑了 30 分钟"))
    runtime.confirm_pending(db, "user-1", cardio["pending"]["id"])
    assert len(db.execute(select(WorkoutSession)).scalars().all()) == 1

    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "删掉昨天那条跑步记录，再称体重73kg",
        )
    )
    assert turn["pending"]["capability_id"] == "coach.batch"
    assert [
        item["capability_id"] for item in turn["pending"]["payload"]["batch"]
    ] == ["training.delete_workout", "body.log_weight"]

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert db.execute(select(WorkoutSession)).scalars().all() == []
    assert db.execute(select(BodyMetric)).scalar_one().weight_kg == 73

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert len(db.execute(select(WorkoutSession)).scalars().all()) == 1
    assert db.execute(select(BodyMetric)).scalars().all() == []


def test_batch_strength_and_food_confirm_and_undo(db):
    import asyncio

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
        runtime.handle_turn(
            db,
            "user-1",
            "午餐吃了100g鸡胸肉，再记录卧推60kg 8次 3组",
        )
    )
    assert turn["pending"]["capability_id"] == "coach.batch"
    assert [
        item["capability_id"] for item in turn["pending"]["payload"]["batch"]
    ] == ["diet.log_food", "training.log_strength"]

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert len(db.execute(select(FoodLog)).scalars().all()) == 1
    assert len(db.execute(select(WorkoutSession)).scalars().all()) == 1

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.execute(select(FoodLog)).scalars().all() == []
    assert db.execute(select(WorkoutSession)).scalars().all() == []


def test_restore_archived_plan_confirm_and_undo(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    active = Program(
        user_id="user-1",
        title="当前计划",
        goal_type="build_muscle",
        version=1,
        status="active",
        start_date=today,
        weeks=4,
    )
    archived = Program(
        user_id="user-1",
        title="上一版计划",
        goal_type="build_muscle",
        version=2,
        status="archived",
        start_date=today,
        weeks=4,
    )
    db.add_all([active, archived])
    db.commit()

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "恢复上一版计划")
    )
    assert turn["intent"] == "training.restore_plan"
    assert turn["pending"]["kind"] == "proposal"
    assert turn["pending"]["payload"]["program_id"] == archived.id

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    db.refresh(active)
    db.refresh(archived)
    assert archived.status == "active"
    assert active.status == "archived"
    assert db.execute(select(DomainEvent)).scalars().all()[-1].type == (
        "TrainingPlanRestored"
    )

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    db.refresh(active)
    db.refresh(archived)
    assert active.status == "active"
    assert archived.status == "archived"


def test_restore_plan_can_pick_an_explicit_version(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    plans = [
        Program(
            user_id="user-1",
            title=f"计划 v{version}",
            goal_type="build_muscle",
            version=version,
            status="active" if version == 1 else "archived",
            start_date=today,
            weeks=4,
        )
        for version in (1, 2, 3)
    ]
    db.add_all(plans)
    db.commit()

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "恢复版本2")
    )
    assert turn["intent"] == "training.restore_plan"
    assert turn["pending"]["payload"]["program_id"] == plans[1].id


def test_batch_plan_restore_and_weight_confirm_and_undo(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    active = Program(
        user_id="user-1",
        title="当前计划",
        goal_type="build_muscle",
        version=1,
        status="active",
        start_date=today,
        weeks=4,
    )
    archived = Program(
        user_id="user-1",
        title="上一版计划",
        goal_type="build_muscle",
        version=2,
        status="archived",
        start_date=today,
        weeks=4,
    )
    db.add_all([active, archived])
    db.commit()

    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "恢复上一版计划，再称体重73kg",
        )
    )
    assert turn["pending"]["capability_id"] == "coach.batch"
    assert [
        item["capability_id"] for item in turn["pending"]["payload"]["batch"]
    ] == ["training.restore_plan", "body.log_weight"]

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    db.refresh(active)
    db.refresh(archived)
    assert archived.status == "active"
    assert active.status == "archived"
    assert db.execute(select(BodyMetric)).scalar_one().weight_kg == 73

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    db.refresh(active)
    db.refresh(archived)
    assert active.status == "active"
    assert archived.status == "archived"
    assert db.execute(select(BodyMetric)).scalars().all() == []


def test_batch_weight_and_goal_confirm_and_undo(db):
    import asyncio

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "今天体重73kg，目标改成70kg")
    )
    assert turn["pending"]["capability_id"] == "coach.batch"
    assert [
        item["capability_id"] for item in turn["pending"]["payload"]["batch"]
    ] == ["body.log_weight", "profile.update_goal"]

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    goals = db.execute(select(Goal)).scalars().all()
    assert goals[0].target_weight_kg == 70
    metrics = db.execute(select(BodyMetric)).scalars().all()
    assert metrics[0].weight_kg == 73

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.execute(select(Goal)).scalars().all() == []
    assert db.execute(select(BodyMetric)).scalars().all() == []


def test_batch_planned_meal_and_weight_confirm_and_undo(db):
    import asyncio

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
                }
            ]
        },
        strategy="balanced",
        generated_by="template",
    )
    db.commit()

    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "记录今天的计划午餐，再称体重73kg",
        )
    )
    assert turn["pending"]["capability_id"] == "coach.batch"
    assert [
        item["capability_id"] for item in turn["pending"]["payload"]["batch"]
    ] == ["diet.log_planned_meal", "body.log_weight"]

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert confirmed["status"] == "executed"
    assert db.execute(select(FoodLog)).scalar_one().plan_meal == "lunch"
    assert db.execute(select(BodyMetric)).scalar_one().weight_kg == 73

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.execute(select(FoodLog)).scalars().all() == []
    assert db.execute(select(BodyMetric)).scalars().all() == []


def test_batch_skip_and_add_day_confirm_and_undo(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    monday = today - timedelta(days=today.weekday())
    db.add(
        Exercise(
            slug="bench_press",
            name_zh="杠铃卧推",
            name_en="bench_press",
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
    source = ProgramDay(
        program_id=program.id,
        week_index=2,
        weekday=1,
        title="胸",
        focus=["chest"],
    )
    db.add(source)
    db.flush()
    db.add(
        PlanExercise(
            program_day_id=source.id,
            exercise_slug="bench_press",
            order_index=1,
            sets=3,
            reps="8-12",
            rest_sec=90,
        )
    )
    db.commit()

    context = {
        "plan": {
            "id": program.id,
            "version": program.version,
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
            "今天不练了，然后加一次练胸",
            app_context=context,
        )
    )
    assert turn["pending"]["capability_id"] == "coach.batch"
    assert [
        item["capability_id"] for item in turn["pending"]["payload"]["batch"]
    ] == ["training.skip", "training.add_plan_day"]

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert confirmed["status"] == "executed"
    skipped = db.execute(
        select(PlanDayState).where(PlanDayState.day_id == "day-1")
    ).scalar_one()
    assert skipped.skipped_at is not None
    created = db.execute(
        select(ProgramDay).where(ProgramDay.program_id == program.id)
    ).scalars().all()
    added = [day for day in created if day.title == "胸" and day.id != source.id]
    assert len(added) == 1
    assert [item.exercise_slug for item in added[0].exercises] == ["bench_press"]

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.get(ProgramDay, added[0].id) is None
    assert (
        db.execute(
            select(PlanDayState).where(PlanDayState.day_id == "day-1")
        ).scalar_one_or_none()
        is None
    )

    stale = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "今天不练了，然后加一次练胸",
            app_context=context,
        )
    )
    duplicate = ProgramDay(
        program_id=program.id,
        week_index=1,
        weekday=today.isoweekday(),
        title="腿",
        focus=["legs"],
    )
    db.add(duplicate)
    db.commit()
    with pytest.raises(ValueError):
        runtime.confirm_pending(db, "user-1", stale["pending"]["id"])
    assert (
        db.execute(
            select(PlanDayState).where(PlanDayState.day_id == "day-1")
        ).scalar_one_or_none()
        is None
    )


def test_batch_skips_two_planned_meals(db):
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
                {"meal": "lunch", "name": "鸡胸饭", "kcal": 600},
                {"meal": "dinner", "name": "牛肉饭", "kcal": 650},
            ]
        },
        strategy="balanced",
        generated_by="template",
    )
    db.commit()

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "跳过午餐，再跳过晚餐")
    )
    assert turn["pending"]["capability_id"] == "coach.batch"
    assert [
        item["capability_id"] for item in turn["pending"]["payload"]["batch"]
    ] == ["diet.skip_planned_meal", "diet.skip_planned_meal"]

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    record = db.execute(select(MealPlan)).scalar_one()
    assert sorted(record.plan.get("skipped_meals", [])) == ["dinner", "lunch"]

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    db.refresh(record)
    assert record.plan.get("skipped_meals", []) == []


def test_semantic_router_dispatches_add_plan_day(db, monkeypatch):
    import asyncio
    from types import SimpleNamespace

    from app.services.coach_control import router

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    monday = today - timedelta(days=today.weekday())
    db.add(
        Exercise(
            slug="bench_press",
            name_zh="杠铃卧推",
            name_en="bench_press",
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
    source = ProgramDay(
        program_id=program.id,
        week_index=2,
        weekday=1,
        title="胸",
        focus=["chest"],
    )
    db.add(source)
    db.flush()
    db.add(
        PlanExercise(
            program_day_id=source.id,
            exercise_slug="bench_press",
            order_index=1,
            sets=3,
            reps="8-12",
            rest_sec=90,
        )
    )
    db.commit()

    async def fake_router(system, user, **kwargs):
        return {
            "capability_id": "training.add_plan_day",
            "confidence": 0.9,
            "reason": "多安排一次训练",
        }

    monkeypatch.setattr(
        router,
        "settings",
        SimpleNamespace(use_mock_llm=False),
    )
    monkeypatch.setattr(router.llm, "complete_json", fake_router)

    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "帮我多安排一次胸部训练",
            app_context={
                "plan": {
                    "id": program.id,
                    "version": program.version,
                    "days": [],
                }
            },
        )
    )
    assert turn["intent"] == "training.add_plan_day"
    assert turn["pending"]["kind"] == "proposal"
    assert turn["pending"]["payload"]["focus"] == ["chest"]


def test_semantic_router_dispatches_a_paraphrased_food_log(db, monkeypatch):
    import asyncio
    from types import SimpleNamespace

    from app.services.coach_control import router

    async def fake_router(system, user, **kwargs):
        return {
            "capability_id": "diet.log_food",
            "confidence": 0.93,
            "reason": "记录烧烤",
        }

    monkeypatch.setattr(
        router,
        "settings",
        SimpleNamespace(use_mock_llm=False),
    )
    monkeypatch.setattr(router.llm, "complete_json", fake_router)

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "今晚那顿烧烤帮我算进去")
    )
    assert turn["intent"] == "diet.log_food"
    assert turn["pending"]["kind"] == "card"
    assert [item["name"] for item in turn["pending"]["payload"]["items"]] == [
        "烧烤"
    ]


def test_diet_correction_after_confirm_replaces_old_log(db):
    import asyncio

    first = asyncio.run(runtime.handle_turn(db, "user-1", "午餐吃了100g鸡胸肉"))
    confirmed = runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    logs = db.execute(select(FoodLog)).scalars().all()
    assert len(logs) == 1 and float(logs[0].grams) == 100

    corrected = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "记错了 午饭吃了150g鸡胸肉",
            session_id=first["session"]["id"],
        )
    )
    assert corrected["pending"]["kind"] == "card"
    assert corrected["pending"]["payload"]["replace_action_id"] == confirmed["action_id"]
    assert corrected["reply"].startswith("改好了，确认后会替换上一条记录。")
    # The old row stays until the replacement card is confirmed.
    assert len(db.execute(select(FoodLog)).scalars().all()) == 1

    replaced = runtime.confirm_pending(db, "user-1", corrected["pending"]["id"])
    logs = db.execute(select(FoodLog)).scalars().all()
    assert len(logs) == 1
    assert float(logs[0].grams) == 150
    assert logs[0].source_action_id != confirmed["action_id"]
    assert replaced["receipt"]["replaced_action_id"] == confirmed["action_id"]
    old_record = db.get(CoachActionRecord, confirmed["action_id"])
    assert old_record.status == "undone"


def test_multi_item_diet_correction_keeps_other_items(db):
    import asyncio

    first = asyncio.run(
        runtime.handle_turn(db, "user-1", "午餐吃了200g鸡胸肉，150g米饭")
    )
    payload = first["pending"]["payload"]
    assert [item["name"] for item in payload["items"]] == ["鸡胸肉", "米饭"]
    confirmed = runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    assert len(db.execute(select(FoodLog)).scalars().all()) == 2

    corrected = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "记错了，鸡胸肉是150g",
            session_id=first["session"]["id"],
        )
    )
    assert corrected["pending"]["kind"] == "card"
    corrected_items = corrected["pending"]["payload"]["items"]
    assert [(item["name"], item["grams"]) for item in corrected_items] == [
        ("鸡胸肉", 150),
        ("米饭", 150),
    ]
    # The old rows are untouched until confirmation.
    assert len(db.execute(select(FoodLog)).scalars().all()) == 2

    runtime.confirm_pending(db, "user-1", corrected["pending"]["id"])
    logs = db.execute(select(FoodLog)).scalars().all()
    assert sorted((log.food_name, float(log.grams)) for log in logs) == [
        ("米饭", 150.0),
        ("鸡胸肉", 150.0),
    ]
    assert {log.source_action_id for log in logs} != {confirmed["action_id"]}


def test_multi_meal_diet_correction_preserves_other_meals(db):
    import asyncio

    first = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "午餐吃了200g鸡胸肉，晚餐吃了150g牛肉",
        )
    )
    assert [
        (meal["meal"], [item["name"] for item in meal["items"]])
        for meal in first["pending"]["payload"]["meals"]
    ] == [("lunch", ["鸡胸肉"]), ("dinner", ["牛肉"])]
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    assert len(db.execute(select(FoodLog)).scalars().all()) == 2

    corrected = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "记错了，午餐鸡胸肉是150g",
            session_id=first["session"]["id"],
        )
    )
    meals = corrected["pending"]["payload"]["meals"]
    assert [
        (meal["meal"], [(item["name"], item["grams"]) for item in meal["items"]])
        for meal in meals
    ] == [
        ("lunch", [("鸡胸肉", 150)]),
        ("dinner", [("牛肉", 150)]),
    ]

    runtime.confirm_pending(db, "user-1", corrected["pending"]["id"])
    logs = db.execute(select(FoodLog)).scalars().all()
    assert sorted((log.meal, log.food_name, float(log.grams)) for log in logs) == [
        ("dinner", "牛肉", 150.0),
        ("lunch", "鸡胸肉", 150.0),
    ]


def test_multi_item_correction_can_replace_a_food(db):
    import asyncio

    first = asyncio.run(
        runtime.handle_turn(db, "user-1", "午餐吃了200g鸡胸肉，150g米饭")
    )
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])

    corrected = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "记错了，不是鸡胸肉，是150g牛肉",
            session_id=first["session"]["id"],
        )
    )
    items = corrected["pending"]["payload"]["items"]
    assert sorted((item["name"], item["grams"]) for item in items) == [
        ("牛肉", 150),
        ("米饭", 150),
    ]

    runtime.confirm_pending(db, "user-1", corrected["pending"]["id"])
    logs = db.execute(select(FoodLog)).scalars().all()
    assert sorted((log.food_name, float(log.grams)) for log in logs) == [
        ("牛肉", 150.0),
        ("米饭", 150.0),
    ]


def test_multi_meal_correction_asks_when_item_is_ambiguous(db):
    import asyncio

    first = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "午餐吃了200g鸡胸肉，晚餐吃了150g鸡胸肉",
        )
    )
    confirmed = runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    assert len(db.execute(select(FoodLog)).scalars().all()) == 2

    corrected = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "记错了，鸡胸肉是150g",
            session_id=first["session"]["id"],
        )
    )
    assert corrected["pending"]["kind"] == "draft"
    assert corrected["pending"]["payload"]["replace_action_id"] == confirmed["action_id"]
    assert "哪一餐" in corrected["reply"]
    assert len(db.execute(select(FoodLog)).scalars().all()) == 2

    follow = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "午餐",
            session_id=first["session"]["id"],
        )
    )
    assert follow["pending"]["kind"] == "card"
    assert follow["pending"]["payload"]["replace_action_id"] == confirmed["action_id"]
    runtime.confirm_pending(db, "user-1", follow["pending"]["id"])
    logs = db.execute(select(FoodLog)).scalars().all()
    assert sorted((log.meal, log.food_name, float(log.grams)) for log in logs) == [
        ("dinner", "鸡胸肉", 150.0),
        ("lunch", "鸡胸肉", 150.0),
    ]


def test_undo_diet_replacement_restores_previous_logs(db):
    import asyncio

    first = asyncio.run(
        runtime.handle_turn(db, "user-1", "午餐吃了200g鸡胸肉，150g米饭")
    )
    confirmed = runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    corrected = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "记错了，鸡胸肉是150g",
            session_id=first["session"]["id"],
        )
    )
    replaced = runtime.confirm_pending(
        db, "user-1", corrected["pending"]["id"]
    )

    runtime.undo_action(db, "user-1", replaced["action_id"])
    logs = db.execute(select(FoodLog)).scalars().all()
    assert sorted((log.food_name, float(log.grams)) for log in logs) == [
        ("米饭", 150.0),
        ("鸡胸肉", 200.0),
    ]
    old = db.get(CoachActionRecord, confirmed["action_id"])
    assert old.status == "executed"
    new = db.get(CoachActionRecord, replaced["action_id"])
    assert new.status == "undone"


def test_batch_diet_sub_action_can_be_corrected_in_place(db):
    import asyncio

    first = asyncio.run(
        runtime.handle_turn(db, "user-1", "记午饭鸡胸肉200g，再称体重73kg")
    )
    assert first["pending"]["capability_id"] == "coach.batch"
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    assert [
        (log.meal, log.food_name, float(log.grams))
        for log in db.execute(select(FoodLog)).scalars().all()
    ] == [("lunch", "鸡胸肉", 200.0)]

    corrected = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "记错了，鸡胸肉是150g",
            session_id=first["session"]["id"],
        )
    )
    assert corrected["pending"]["kind"] == "card"
    runtime.confirm_pending(db, "user-1", corrected["pending"]["id"])
    assert [
        (log.meal, log.food_name, float(log.grams))
        for log in db.execute(select(FoodLog)).scalars().all()
    ] == [("lunch", "鸡胸肉", 150.0)]
    assert db.execute(select(BodyMetric)).scalar_one().weight_kg == 73


def test_diet_correction_understands_explicit_old_value(db):
    import asyncio

    first = asyncio.run(
        runtime.handle_turn(db, "user-1", "午餐吃了200g鸡胸肉，150g米饭")
    )
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    corrected = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "记错了，鸡胸肉不是200g，是150g",
            session_id=first["session"]["id"],
        )
    )
    items = corrected["pending"]["payload"]["items"]
    assert sorted((item["name"], item["grams"]) for item in items) == [
        ("米饭", 150),
        ("鸡胸肉", 150),
    ]


def test_diet_correction_does_not_resurrect_deleted_log(db):
    import asyncio

    first = asyncio.run(
        runtime.handle_turn(db, "user-1", "午餐吃了200g鸡胸肉，150g米饭")
    )
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    rice = db.execute(
        select(FoodLog).where(FoodLog.food_name == "米饭")
    ).scalar_one()
    db.delete(rice)
    db.commit()

    corrected = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "记错了，鸡胸肉是150g",
            session_id=first["session"]["id"],
        )
    )
    runtime.confirm_pending(db, "user-1", corrected["pending"]["id"])
    logs = db.execute(select(FoodLog)).scalars().all()
    assert [
        (log.meal, log.food_name, float(log.grams)) for log in logs
    ] == [("lunch", "鸡胸肉", 150.0)]


def test_ambiguous_food_replacement_only_changes_the_named_meal(db):
    import asyncio

    first = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "午餐吃了200g鸡胸肉，晚餐吃了150g鸡胸肉",
        )
    )
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    corrected = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "记错了，不是鸡胸肉，是150g牛肉",
            session_id=first["session"]["id"],
        )
    )
    assert corrected["pending"]["kind"] == "draft"
    assert "哪一餐" in corrected["reply"]

    follow = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "午餐",
            session_id=first["session"]["id"],
        )
    )
    runtime.confirm_pending(db, "user-1", follow["pending"]["id"])
    logs = db.execute(select(FoodLog)).scalars().all()
    assert sorted(
        (log.meal, log.food_name, float(log.grams)) for log in logs
    ) == [
        ("dinner", "鸡胸肉", 150.0),
        ("lunch", "牛肉", 150.0),
    ]


def test_food_card_can_replace_an_item(db):
    import asyncio

    first = asyncio.run(runtime.handle_turn(db, "user-1", "午餐吃了100g鸡胸肉"))
    assert first["pending"]["payload"]["items"][0]["name"] == "鸡胸肉"
    second = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "不是鸡胸肉，是150g牛肉",
            session_id=first["session"]["id"],
        )
    )
    payload = second["pending"]["payload"]
    assert payload["meal"] == "lunch"
    assert [(item["name"], item["grams"]) for item in payload["items"]] == [
        ("牛肉", 150)
    ]


def test_dinner_reference_uses_prior_turns_and_full_history(db, monkeypatch):
    import asyncio
    import json
    from types import SimpleNamespace

    from app.models import CoachSession, CoachTurn
    from app.services import food_text

    session = CoachSession(user_id="user-1", status="active")
    db.add(session)
    db.flush()
    db.add_all(
        [
            CoachTurn(
                session_id=session.id,
                user_id="user-1",
                input_text="图片里的菜加250g米饭，热量是多少？",
                intent="coach.vision",
                status="completed",
                reply="干蒸牛肉约120g、腊肠约80g、米饭250g，合计约825kcal。",
            ),
            CoachTurn(
                session_id=session.id,
                user_id="user-1",
                input_text="菜是干蒸牛肉+腊肠",
                intent="coach.answer",
                status="completed",
                reply="按干蒸牛肉120g、腊肠80g重算，约825kcal。",
            ),
        ]
    )
    db.commit()

    captured: dict[str, str] = {}

    async def fake_complete_json(system, user, **kwargs):
        captured["payload"] = user
        return {
            "items": [
                {"name": "干蒸牛肉", "grams": 120, "kcal": 220, "protein_g": 25, "carbs_g": 0, "fat_g": 14},
                {"name": "腊肠", "grams": 80, "kcal": 330, "protein_g": 10, "carbs_g": 2, "fat_g": 28},
                {"name": "米饭", "grams": 250, "kcal": 275, "protein_g": 6, "carbs_g": 60, "fat_g": 1},
            ],
            "questions": [],
        }

    monkeypatch.setattr(
        food_text,
        "settings",
        SimpleNamespace(use_mock_llm=False),
    )
    monkeypatch.setattr(food_text.llm, "complete_json", fake_complete_json)

    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "这是我今天的晚饭，中午吃了300g燕麦+一杯冰美式",
            session_id=session.id,
        )
    )
    payload = turn["pending"]["payload"]
    names = [item["name"] for item in payload["items"]]
    prompt = json.loads(captured["payload"])

    assert "干蒸牛肉" in prompt["history"]
    assert "250g" in prompt["history"]
    assert "干蒸牛肉" in names
    assert "米饭" in names
    assert payload["meal"] == "lunch"
    assert "另外看到你提到晚饭" in turn["reply"]
    assert all("这是我今天的晚饭" not in q for q in payload.get("questions", []))


def test_multi_meal_turn_builds_one_card(db, monkeypatch):
    import asyncio
    import json
    from types import SimpleNamespace

    from app.services import food_text

    async def fake_complete_json(system, user, **kwargs):
        payload = json.loads(user)
        text = payload.get("text") or ""
        if "麦片" in text:
            return {
                "items": [
                    {
                        "name": "麦片",
                        "grams": 200,
                        "kcal": 760,
                        "protein_g": 26,
                        "carbs_g": 132,
                        "fat_g": 13,
                    }
                ],
                "questions": [],
            }
        if "炒米粉" in text:
            return {
                "items": [
                    {
                        "name": "炒米粉",
                        "grams": 250,
                        "kcal": 425,
                        "protein_g": 10,
                        "carbs_g": 55,
                        "fat_g": 13.8,
                    },
                    {
                        "name": "紫薯",
                        "grams": 60,
                        "kcal": 80,
                        "protein_g": 1,
                        "carbs_g": 18,
                        "fat_g": 0.1,
                    },
                    {
                        "name": "玉米肠",
                        "grams": 100,
                        "kcal": 240,
                        "protein_g": 12,
                        "carbs_g": 8,
                        "fat_g": 18,
                    },
                ],
                "questions": [],
            }
        return {"items": [], "questions": []}

    monkeypatch.setattr(
        food_text,
        "settings",
        SimpleNamespace(use_mock_llm=False),
    )
    monkeypatch.setattr(food_text.llm, "complete_json", fake_complete_json)

    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "我昨天早上吃了200g麦片、中午吃的是干蒸牛肉+腊肠+200g米饭、"
            "晚饭吃了250g炒米粉+60g紫薯+100g玉米肠",
        )
    )
    payload = turn["pending"]["payload"]
    meals = {item["meal"]: item for item in payload["meals"]}
    assert set(meals) == {"breakfast", "lunch", "dinner"}
    assert [item["name"] for item in meals["breakfast"]["items"]] == ["麦片"]
    assert {item["name"] for item in meals["lunch"]["items"]} == {
        "干蒸牛肉",
        "腊肠",
        "米饭",
    }
    assert {item["name"] for item in meals["dinner"]["items"]} == {
        "炒米粉",
        "紫薯",
        "玉米肠",
    }
    assert "一餐" not in turn["reply"]
    assert "一次写入" in turn["reply"]

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    logs = db.execute(
        select(FoodLog).where(FoodLog.user_id == "user-1")
    ).scalars().all()
    by_meal: dict[str, set[str]] = {}
    for log in logs:
        by_meal.setdefault(log.meal, set()).add(log.food_name)
    assert by_meal["breakfast"] == {"麦片"}
    assert by_meal["lunch"] == {"干蒸牛肉", "腊肠", "米饭"}
    assert by_meal["dinner"] == {"炒米粉", "紫薯", "玉米肠"}

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.execute(
        select(FoodLog).where(FoodLog.user_id == "user-1")
    ).scalars().all() == []


def test_weight_card_accepts_a_correction_without_losing_context(db):
    import asyncio

    first = asyncio.run(runtime.handle_turn(db, "user-1", "今天体重73kg"))
    assert first["pending"]["kind"] == "card"
    assert first["pending"]["payload"]["weight_kg"] == 73.0

    second = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "记错了 今天是74kg",
            session_id=first["session"]["id"],
        )
    )
    assert second["pending"]["capability_id"] == "body.log_weight"
    assert second["pending"]["kind"] == "card"
    assert second["pending"]["payload"]["weight_kg"] == 74.0
    active = db.execute(
        select(CoachPending).where(CoachPending.status == "pending")
    ).scalars().all()
    assert len(active) == 1
    assert active[0].id == first["pending"]["id"]


def test_food_card_merges_a_follow_up_item(db):
    import asyncio

    first = asyncio.run(runtime.handle_turn(db, "user-1", "午餐吃了100g鸡胸肉"))
    assert first["pending"]["kind"] == "card"
    assert first["pending"]["payload"]["meal"] == "lunch"

    second = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "还有一杯奶茶",
            session_id=first["session"]["id"],
        )
    )
    payload = second["pending"]["payload"]
    assert payload["meal"] == "lunch"
    assert {item["name"] for item in payload["items"]} == {"鸡胸肉", "奶茶"}
    active = db.execute(
        select(CoachPending).where(CoachPending.status == "pending")
    ).scalars().all()
    assert len(active) == 1


def test_food_card_merges_a_second_meal(db):
    import asyncio

    first = asyncio.run(runtime.handle_turn(db, "user-1", "午餐吃了100g鸡胸肉"))
    second = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "晚餐吃了100g米饭",
            session_id=first["session"]["id"],
        )
    )
    payload = second["pending"]["payload"]
    meals = {item["meal"]: item for item in payload["meals"]}
    assert set(meals) == {"lunch", "dinner"}
    assert [item["name"] for item in meals["lunch"]["items"]] == ["鸡胸肉"]
    assert [item["name"] for item in meals["dinner"]["items"]] == ["米饭"]
    assert "一次写入" in second["reply"]


def test_dinner_reference_only_uses_history_items(db, monkeypatch):
    import asyncio
    from types import SimpleNamespace

    from app.models import CoachSession, CoachTurn
    from app.services import food_text

    session = CoachSession(user_id="user-1", status="active")
    db.add(session)
    db.flush()
    db.add(
        CoachTurn(
            session_id=session.id,
            user_id="user-1",
            input_text="菜是干蒸牛肉+腊肠",
            intent="coach.answer",
            status="completed",
            reply="按干蒸牛肉120g、腊肠80g、米饭250g重算，约825kcal。",
        )
    )
    db.commit()

    async def fake_complete_json(system, user, **kwargs):
        return {
            "items": [
                {"name": "干蒸牛肉", "grams": 120, "kcal": 220, "protein_g": 25, "carbs_g": 0, "fat_g": 14},
                {"name": "腊肠", "grams": 80, "kcal": 330, "protein_g": 10, "carbs_g": 2, "fat_g": 28},
                {"name": "米饭", "grams": 250, "kcal": 275, "protein_g": 6, "carbs_g": 60, "fat_g": 1},
            ],
            "questions": [],
        }

    monkeypatch.setattr(
        food_text,
        "settings",
        SimpleNamespace(use_mock_llm=False),
    )
    monkeypatch.setattr(food_text.llm, "complete_json", fake_complete_json)

    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "这是我今天的晚饭",
            session_id=session.id,
        )
    )
    payload = turn["pending"]["payload"]
    names = [item["name"] for item in payload["items"]]

    assert payload["meal"] == "dinner"
    assert "干蒸牛肉" in names
    assert "米饭" in names
    assert not payload.get("questions")


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


def test_reschedule_tomorrow_to_today_before_first_week(db):
    import asyncio

    from app.models import utcnow
    from app.services.coach_control.context import with_plan_context

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    tomorrow = today + timedelta(days=1)
    program = Program(
        user_id="user-1",
        title="明天开始的计划",
        goal_type="recomp",
        version=1,
        status="active",
        start_date=today,
        weeks=4,
    )
    db.add(program)
    db.flush()
    day = ProgramDay(
        program_id=program.id,
        week_index=1,
        weekday=1,
        title="胸",
    )
    db.add(day)
    db.flush()
    db.add(
        PlanDayState(
            user_id="user-1",
            plan_id=program.id,
            day_id=day.id,
            assigned_date=tomorrow,
            client_updated_at=utcnow(),
        )
    )
    db.commit()

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "把明天的训练改到今天")
    )
    assert turn["intent"] == "training.reschedule", turn
    assert turn["pending"]["payload"]["to_date"] == today.isoformat()

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert confirmed["status"] == "executed"
    assert set(confirmed["refresh_domains"]) == {"plan", "schedule", "diet"}

    context = with_plan_context(db, "user-1", {})
    item = next(
        item for item in context["plan"]["days"] if item["id"] == day.id
    )
    assert item["date"] == today.isoformat()


def test_write_capabilities_declare_refresh_domains():
    from app.services.coach_control.registry import CAPABILITIES

    for capability in CAPABILITIES.values():
        if capability.kind == "write" and not capability.id.startswith("ui."):
            assert capability.refreshes, capability.id
    assert "diet" in CAPABILITIES["body.log_weight"].refreshes
    assert "review" in CAPABILITIES["diet.log_planned_meal"].refreshes
    assert "review" in CAPABILITIES["diet.skip_planned_meal"].refreshes
    assert "review" in CAPABILITIES["training.skip"].refreshes
    assert "review" in CAPABILITIES["training.add_plan_day"].refreshes


def test_unmatched_action_emits_a_coverage_gap_event(db, monkeypatch):
    import asyncio

    from app.config import settings

    monkeypatch.setattr(settings, "llm_provider", "mock")
    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "帮我导出训练数据")
    )
    assert turn["intent"] == "coach.answer"

    clarified = asyncio.run(
        runtime.handle_turn(db, "user-1", "把昵称改成小王")
    )
    assert clarified["intent"] == "clarification"

    events = db.execute(
        select(DomainEvent).where(DomainEvent.type == "CoachActionGap")
    ).scalars().all()
    assert len(events) == 2
    assert events[0].payload["message"] == "帮我导出训练数据"
    assert events[1].payload["message"] == "把昵称改成小王"


def test_every_capability_has_a_declarative_action_spec():
    from app.services.coach_control.manifest import ACTION_SPECS
    from app.services.coach_control.registry import CAPABILITIES

    assert set(ACTION_SPECS) == set(CAPABILITIES)
    for spec in ACTION_SPECS.values():
        assert spec.examples, spec.id
        assert all(example.strip() for example in spec.examples)
        assert spec.card


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


def test_edit_exercises_falls_back_to_the_next_focus_day(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    monday = today - timedelta(days=today.weekday())
    next_monday = monday + timedelta(days=7)
    for slug, name in [
        ("bench_press", "杠铃卧推"),
        ("vital-incline-barbell-bench-press", "上斜杠铃卧推"),
        ("old-chest-press", "哑铃卧推"),
    ]:
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
        week_index=2,
        weekday=1,
        title="胸",
    )
    db.add(day)
    db.flush()
    db.add(
        PlanExercise(
            program_day_id=day.id,
            exercise_slug="old-chest-press",
            order_index=1,
            sets=3,
            reps="8-12",
            rest_sec=90,
        )
    )
    db.commit()

    context = {
        "plan": {
            "id": program.id,
            "version": program.version,
            "days": [
                {
                    "id": day.id,
                    "date": next_monday.isoformat(),
                    "title": "胸",
                    "focus": ["chest"],
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
            "今天的练胸计划帮我改成：杠铃卧推、上斜杠铃卧推",
            app_context=context,
        )
    )
    assert turn["intent"] == "training.edit_day_exercises"
    assert turn["pending"]["payload"]["date"] == next_monday.isoformat()
    assert len(turn["pending"]["payload"]["exercises"]) == 2


def test_edit_single_exercise_swap_and_sets(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    monday = today - timedelta(days=today.weekday())
    for slug, name in [
        ("old-dumbbell-press", "哑铃卧推"),
        ("bench_press", "杠铃卧推"),
        ("vital-machine-pec-deck-fly", "蝴蝶机夹胸"),
    ]:
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

    sets_turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "哑铃卧推改成4组",
        )
    )
    assert sets_turn["intent"] == "training.edit_day_exercise"
    assert sets_turn["pending"]["kind"] == "proposal"
    sets_confirmed = runtime.confirm_pending(
        db,
        "user-1",
        sets_turn["pending"]["id"],
    )
    updated = db.get(ProgramDay, day.id)
    assert updated.exercises[0].sets == 4
    runtime.undo_action(db, "user-1", sets_confirmed["action_id"])
    assert db.get(ProgramDay, day.id).exercises[0].sets == 3

    swapped = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "把哑铃卧推换成杠铃卧推",
        )
    )
    assert swapped["intent"] == "training.edit_day_exercise"
    assert swapped["pending"]["kind"] == "proposal"
    confirmed = runtime.confirm_pending(db, "user-1", swapped["pending"]["id"])
    updated = db.get(ProgramDay, day.id)
    assert [item.exercise_slug for item in updated.exercises] == ["bench_press"]

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    restored = db.get(ProgramDay, day.id)
    assert [item.exercise_slug for item in restored.exercises] == [
        "old-dumbbell-press"
    ]

    added = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "给今天的练胸加一个蝴蝶机",
        )
    )
    assert added["intent"] == "training.edit_day_exercise"
    assert added["pending"]["kind"] == "proposal"
    added_confirmed = runtime.confirm_pending(
        db,
        "user-1",
        added["pending"]["id"],
    )
    assert [item.exercise_slug for item in db.get(ProgramDay, day.id).exercises] == [
        "old-dumbbell-press",
        "vital-machine-pec-deck-fly",
    ]
    runtime.undo_action(db, "user-1", added_confirmed["action_id"])
    assert [item.exercise_slug for item in db.get(ProgramDay, day.id).exercises] == [
        "old-dumbbell-press"
    ]


def test_diet_week_generation_confirm_and_undo(db, monkeypatch):
    import asyncio

    from app.config import settings

    monkeypatch.setattr(settings, "llm_provider", "mock")
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    next_monday = today - timedelta(days=today.weekday()) + timedelta(days=7)

    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "帮我排下周的碳循环饮食计划",
        )
    )
    assert turn["intent"] == "diet.generate_week"
    assert turn["pending"]["kind"] == "proposal"
    payload = turn["pending"]["payload"]
    assert payload["week_start"] == next_monday.isoformat()
    assert payload["strategy"] == "carb_cycle"
    assert len(payload["days"]) == 7

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert confirmed["status"] == "executed"
    saved = db.execute(select(MealPlan)).scalars().all()
    assert len(saved) == 7
    assert {item.strategy for item in saved} == {"carb_cycle"}

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.execute(select(MealPlan)).scalars().all() == []


def test_add_plan_day_copies_focus_template_and_undo(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    monday = today - timedelta(days=today.weekday())
    db.add(
        Exercise(
            slug="bench_press",
            name_zh="杠铃卧推",
            name_en="bench_press",
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
    source = ProgramDay(
        program_id=program.id,
        week_index=2,
        weekday=1,
        title="胸",
        focus=["chest"],
    )
    db.add(source)
    db.flush()
    db.add(
        PlanExercise(
            program_day_id=source.id,
            exercise_slug="bench_press",
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
            "今天加一次练胸",
            app_context={
                "plan": {
                    "id": program.id,
                    "version": program.version,
                    "days": [],
                }
            },
        )
    )
    assert turn["intent"] == "training.add_plan_day"
    assert turn["pending"]["kind"] == "proposal"
    payload = turn["pending"]["payload"]
    assert payload["date"] == today.isoformat()
    assert [item["slug"] for item in payload["exercises"]] == ["bench_press"]

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    day_id = confirmed["receipt"]["day_id"]
    created = db.get(ProgramDay, day_id)
    assert created is not None
    assert created.weekday == today.isoweekday()
    assert [item.exercise_slug for item in created.exercises] == ["bench_press"]
    state = db.execute(
        select(PlanDayState).where(PlanDayState.day_id == day_id)
    ).scalar_one()
    assert state.assigned_date == today

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.get(ProgramDay, day_id) is None
    assert (
        db.execute(
            select(PlanDayState).where(PlanDayState.day_id == day_id)
        ).scalar_one_or_none()
        is None
    )


def test_edit_multiple_exercise_params(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    monday = today - timedelta(days=today.weekday())
    for slug, name in [
        ("old-dumbbell-press", "哑铃卧推"),
        ("barbell-row", "杠铃划船"),
    ]:
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
        title="测试日",
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
        title="胸背",
    )
    db.add(day)
    db.flush()
    db.add_all(
        [
            PlanExercise(
                program_day_id=day.id,
                exercise_slug="old-dumbbell-press",
                order_index=1,
                sets=3,
                reps="8-12",
                rest_sec=90,
            ),
            PlanExercise(
                program_day_id=day.id,
                exercise_slug="barbell-row",
                order_index=2,
                sets=3,
                reps="10-12",
                rest_sec=90,
            ),
        ]
    )
    db.commit()

    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "哑铃卧推改成4组8次，杠铃划船改成3组12次",
        )
    )
    assert turn["intent"] == "training.edit_day_exercise"
    assert turn["pending"]["kind"] == "proposal"
    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    updated = db.get(ProgramDay, day.id)
    values = {
        item.exercise_slug: (item.sets, item.reps)
        for item in updated.exercises
    }
    assert values["old-dumbbell-press"] == (4, "8")
    assert values["barbell-row"] == (3, "12")

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    restored = {
        item.exercise_slug: (item.sets, item.reps)
        for item in db.get(ProgramDay, day.id).exercises
    }
    assert restored["old-dumbbell-press"] == (3, "8-12")
    assert restored["barbell-row"] == (3, "10-12")


def test_week_schedule_lists_next_week(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    next_monday = today - timedelta(days=today.weekday()) + timedelta(days=7)
    context = {
        "plan": {
            "id": "plan-1",
            "days": [
                {
                    "id": "day-1",
                    "date": next_monday.isoformat(),
                    "title": "胸",
                    "completed": False,
                    "skipped": False,
                },
                {
                    "id": "day-2",
                    "date": (next_monday + timedelta(days=2)).isoformat(),
                    "title": "背",
                    "completed": False,
                    "skipped": True,
                },
            ],
        }
    }
    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "下周练什么",
            app_context=context,
        )
    )
    assert turn["intent"] == "training.week_schedule"
    assert turn["pending"]["kind"] == "insight"
    assert "下周" in turn["reply"]
    assert any("胸" in item for item in turn["pending"]["payload"]["wins"])
    assert any("背" in item for item in turn["pending"]["payload"]["wins"])


def test_context_week_one_starts_next_monday_for_midweek_plan(db):
    from app.services.coach_control.context import with_plan_context

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    monday = today - timedelta(days=today.weekday())
    start = monday + timedelta(days=2)
    next_monday = monday + timedelta(days=7)
    program = Program(
        user_id="user-1",
        title="周三开始的计划",
        goal_type="recomp",
        version=1,
        status="active",
        start_date=start,
        weeks=4,
    )
    db.add(program)
    db.flush()
    db.add(
        ProgramDay(
            program_id=program.id,
            week_index=1,
            weekday=1,
            title="胸",
        )
    )
    db.commit()

    context = with_plan_context(db, "user-1", {})
    day = context["plan"]["days"][0]
    assert day["date"] == next_monday.isoformat()


def test_context_allows_workout_added_for_today_before_first_week(db):
    from app.models import utcnow
    from app.services.coach_control.context import with_plan_context

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    program = Program(
        user_id="user-1",
        title="明天开始的计划",
        goal_type="recomp",
        version=1,
        status="active",
        start_date=today + timedelta(days=1),
        weeks=4,
    )
    db.add(program)
    db.flush()
    day = ProgramDay(
        program_id=program.id,
        week_index=1,
        weekday=today.isoweekday(),
        title="背",
    )
    db.add(day)
    db.flush()
    db.add(
        PlanDayState(
            user_id="user-1",
            plan_id=program.id,
            day_id=day.id,
            assigned_date=today,
            client_updated_at=utcnow(),
        )
    )
    db.commit()

    context = with_plan_context(db, "user-1", {})
    item = next(item for item in context["plan"]["days"] if item["id"] == day.id)
    assert item["date"] == today.isoformat()
    assert item["skipped"] is False


def test_schedule_sync_drops_date_from_skipped_duplicate(db):
    from app.schemas import PlanDayStateIn, ScheduleSyncIn
    from app.services.schedule import sync_schedule

    now = datetime.now(timezone.utc)
    payload = ScheduleSyncIn(
        plan_id="plan-1",
        plan_version=1,
        days=[
            PlanDayStateIn(
                day_id="day-1",
                assigned_date=date(2026, 11, 23),
                client_updated_at=now,
            ),
            PlanDayStateIn(
                day_id="day-2",
                assigned_date=date(2026, 11, 23),
                skipped_at=now,
                client_updated_at=now,
            ),
        ],
    )

    result = sync_schedule(db, "user-1", payload)
    days = {item["day_id"]: item for item in result["days"]}
    assert days["day-1"]["assigned_date"] == "2026-11-23"
    assert days["day-2"]["assigned_date"] is None


def test_edit_single_day_diet_strategy_and_undo(db, monkeypatch):
    import asyncio

    from app.config import settings
    from app.services.meal_plans import save_day_plan

    monkeypatch.setattr(settings, "llm_provider", "mock")
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    target = today + timedelta(days=(2 - today.weekday()) % 7 or 7)
    save_day_plan(
        db,
        "user-1",
        target,
        {"marker": "old", "targets": {}, "meals": []},
        strategy="balanced",
        generated_by="template",
    )
    db.commit()

    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "把周三的餐单改成低碳",
        )
    )
    assert turn["intent"] == "diet.edit_day_strategy"
    assert turn["pending"]["kind"] == "proposal"
    assert turn["pending"]["payload"]["date"] == target.isoformat()
    assert turn["pending"]["payload"]["strategy"] == "low_carb"

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    record = db.execute(
        select(MealPlan).where(MealPlan.plan_date == target)
    ).scalar_one()
    assert record.strategy == "low_carb"
    assert record.plan.get("marker") != "old"

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    restored = db.execute(
        select(MealPlan).where(MealPlan.plan_date == target)
    ).scalar_one()
    assert restored.plan.get("marker") == "old"
    assert restored.strategy == "balanced"


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


def test_update_and_delete_food_log_via_control_plane(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    client_id = str(uuid4())
    db.add(
        FoodLog(
            user_id="user-1",
            client_id=client_id,
            logged_at=datetime.combine(
                today, datetime.min.time().replace(hour=12),
                tzinfo=ZoneInfo("Asia/Shanghai"),
            ).astimezone(timezone.utc),
            meal="lunch",
            food_name="鸡胸肉",
            grams=100,
            kcal=120,
            protein=20,
            carbs=2,
            fat=3,
            fiber=1,
            source="manual",
        )
    )
    db.commit()

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "把午饭的鸡胸肉改成150g")
    )
    assert turn["intent"] == "diet.update_log"
    assert turn["pending"]["kind"] == "card"
    payload = turn["pending"]["payload"]
    assert payload["grams"] == 150
    assert payload["kcal"] == 180

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert confirmed["status"] == "executed"
    log = db.execute(
        select(FoodLog).where(FoodLog.client_id == client_id)
    ).scalar_one()
    assert log.grams == 150
    assert log.kcal == 180

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    log = db.execute(
        select(FoodLog).where(FoodLog.client_id == client_id)
    ).scalar_one()
    assert log.grams == 100
    assert log.kcal == 120

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "删掉午饭的鸡胸肉")
    )
    assert turn["intent"] == "diet.delete_log"
    assert turn["pending"]["payload"]["food_name"] == "鸡胸肉"
    assert turn["pending"]["payload"]["meal"] == "lunch"
    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert (
        db.execute(
            select(FoodLog).where(FoodLog.client_id == client_id)
        ).scalar_one_or_none()
        is None
    )
    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert (
        db.execute(
            select(FoodLog).where(FoodLog.client_id == client_id)
        ).scalar_one_or_none()
        is not None
    )


def test_update_and_delete_workout_via_control_plane(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    started = datetime.combine(
        today, datetime.min.time().replace(hour=8),
        tzinfo=ZoneInfo("Asia/Shanghai"),
    ).astimezone(timezone.utc)
    session = WorkoutSession(
        user_id="user-1",
        source="phone",
        started_at=started,
        finished_at=started + timedelta(minutes=30),
        duration_min=30,
        notes="跑步",
        sets=[
            SetLog(
                exercise_slug="bench_press",
                set_index=1,
                weight_kg=40,
                reps=10,
                completed=True,
            )
        ],
    )
    db.add(session)
    db.commit()

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "把今天跑步改成40分钟")
    )
    assert turn["intent"] == "training.update_workout"
    assert turn["pending"]["payload"]["duration_minutes"] == 40
    assert turn["pending"]["payload"]["title"] == "跑步"

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    db.refresh(session)
    assert session.duration_min == 40
    runtime.undo_action(db, "user-1", confirmed["action_id"])
    db.refresh(session)
    assert session.duration_min == 30

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "删掉今天跑步记录")
    )
    assert turn["intent"] == "training.delete_workout"
    assert turn["pending"]["payload"]["title"] == "跑步"
    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert db.get(WorkoutSession, session.id) is None
    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.get(WorkoutSession, session.id) is not None


def test_reschedule_explains_a_day_without_training(db):
    from app.services.coach_control.capabilities.training import resolve

    result = resolve(
        db,
        "user-1",
        "把今天训练改到明天",
        {
            "plan": {
                "id": "plan-1",
                "days": [
                    {
                        "id": "day-1",
                        "date": (
                            datetime.now(ZoneInfo("Asia/Shanghai")).date()
                            + timedelta(days=1)
                        ).isoformat(),
                        "title": "胸",
                    }
                ],
            }
        },
    )
    assert result["ready"] is False
    assert "今天没有安排训练" in result["questions"][0]


def test_plan_adjust_recognizes_time_and_recovery_words():
    assert runtime._looks_like_plan_adjust("最近太忙，训练计划帮我调整一下")
    assert runtime._looks_like_plan_adjust("计划太满，坚持不下来")
    assert runtime._looks_like_plan_adjust("计划太累了，减量")
    assert runtime._looks_like_plan_adjust("这周计划太满")
    assert not runtime._looks_like_week_schedule("这周计划太满")


def test_configure_plan_parses_chinese_frequency_and_split():
    from app.services.coach_control.capabilities import plan_configure

    assert plan_configure._weekly_days("一周三练") == 3
    assert plan_configure._weekly_days("每周三练") == 3
    assert plan_configure._weekly_days("每周4练") == 4
    assert plan_configure._weekdays("一周三练，二四六") == [2, 4, 6]
    assert plan_configure._weekdays("每周三练") == []
    assert plan_configure._split("三分化") == "3分化"
    assert plan_configure._split("推拉腿") == "3分化"
    assert runtime._looks_like_plan_configure("一周三练，二四六，45分钟")


def test_configure_plan_parses_shape_and_activates(db, monkeypatch):
    import asyncio

    from app.services import access
    from app.services.coach_control.capabilities import plan_configure

    monkeypatch.setattr(access, "has_pro", lambda db, user_id: True)
    captured = {}

    def fake_build(db, profile, goal_type, **kwargs):
        captured.update(kwargs)
        return {
            "title": "测试配置计划",
            "weeks": 4,
            "days": [
                {
                    "week_index": 1,
                    "weekday": 2,
                    "title": "胸",
                    "focus": ["chest"],
                    "exercises": [
                        {
                            "slug": "bench_press",
                            "order_index": 1,
                            "sets": 3,
                            "reps": "8-10",
                            "rest_sec": 90,
                            "weight_kg": 20,
                            "rpe": 7,
                        }
                    ],
                }
            ],
        }

    monkeypatch.setattr(plan_configure, "build_template_plan", fake_build)

    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "把计划改成每周3练，二四六，45分钟，3分化",
        )
    )
    assert turn["intent"] == "training.configure_plan"
    assert turn["pending"]["kind"] == "proposal"
    assert captured["weekly_days"] == 3
    assert captured["weekdays"] == [2, 4, 6]
    assert captured["session_minutes"] == 45
    assert captured["split"] == "3分化"

    program_id = turn["pending"]["payload"]["program_id"]
    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert confirmed["status"] == "executed"
    program = db.get(Program, program_id)
    assert program.status == "active"
    profile = db.get(Profile, "user-1")
    assert profile.weekly_days == 3
    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.get(Program, program_id).status == "archived"
    db.refresh(profile)
    assert profile.weekly_days == 3


def test_configure_plan_undo_restores_profile_shape(db, monkeypatch):
    import asyncio

    from app.services import access
    from app.services.coach_control.capabilities import plan_configure

    monkeypatch.setattr(access, "has_pro", lambda db, user_id: True)

    def fake_build(db, profile, goal_type, **kwargs):
        return {
            "title": "四练计划",
            "weeks": 4,
            "days": [
                {
                    "week_index": 1,
                    "weekday": 2,
                    "title": "上肢",
                    "focus": ["chest", "back"],
                    "exercises": [
                        {
                            "slug": "bench_press",
                            "order_index": 1,
                            "sets": 3,
                            "reps": "8-10",
                            "rest_sec": 90,
                            "weight_kg": 20,
                            "rpe": 7,
                        }
                    ],
                }
            ],
        }

    monkeypatch.setattr(plan_configure, "build_template_plan", fake_build)

    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "每周4练，二四六日，60分钟",
        )
    )
    assert turn["intent"] == "training.configure_plan"
    profile = db.get(Profile, "user-1")
    assert profile.weekly_days == 3
    assert profile.session_minutes == 45
    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    profile = db.get(Profile, "user-1")
    assert profile.weekly_days == 4
    assert profile.session_minutes == 60

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    db.refresh(profile)
    assert profile.weekly_days == 3
    assert profile.session_minutes == 45


def test_start_training_can_target_a_specific_day(db):
    import asyncio

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    dates = [today, today + timedelta(days=2), today + timedelta(days=4)]
    context = {
        "plan": {
            "id": "plan-1",
            "days": [
                {
                    "id": f"day-{index}",
                    "date": value.isoformat(),
                    "title": title,
                    "completed": False,
                    "skipped": False,
                }
                for index, (value, title) in enumerate(
                    zip(dates, ["胸", "背", "腿"], strict=False),
                    start=1,
                )
            ],
        }
    }
    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "从后天的训练开始",
            app_context=context,
        )
    )
    assert turn["intent"] == "ui.start_training"
    assert turn["pending"]["payload"]["day_id"] == "day-2"
    assert turn["pending"]["payload"]["title"] == "背"

    context["plan"]["days"][1]["completed"] = True
    done = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "开始后天的训练",
            app_context=context,
        )
    )
    assert done["pending"] is None
    assert "完成" in done["reply"]


def test_start_training_and_open_screen_via_control_plane(db):
    import asyncio

    context = {
        "plan": {
            "id": "plan-1",
            "days": [
                {
                    "id": "day-1",
                    "date": "2026-11-16",
                    "title": "胸",
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
            "开始训练",
            app_context=context,
        )
    )
    assert turn["intent"] == "ui.start_training"
    assert turn["pending"]["kind"] == "card"
    assert turn["pending"]["payload"]["day_id"] == "day-1"

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert confirmed["status"] == "executed"
    assert confirmed["receipt"]["day_id"] == "day-1"

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "打开训练记录")
    )
    assert turn["intent"] == "ui.open_screen"
    assert turn["pending"]["payload"]["screen"] == "workout_history"
    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert confirmed["status"] == "executed"
    assert confirmed["receipt"]["screen"] == "workout_history"

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "分析一下我的体型"))
    assert turn["intent"] == "ui.open_screen"
    assert turn["pending"]["payload"]["screen"] == "body_analysis"

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "帮我识别这个器械"))
    assert turn["intent"] == "ui.open_screen"
    assert turn["pending"]["payload"]["screen"] == "equipment_scan"

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "打开身体打卡"))
    assert turn["intent"] == "ui.open_screen"
    assert turn["pending"]["payload"]["screen"] == "body_checkin"


def test_reminders_via_control_plane(db):
    import asyncio

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "把训练提醒改成早上8点")
    )
    assert turn["intent"] == "ui.configure_reminders"
    assert turn["pending"]["kind"] == "card"
    assert turn["pending"]["payload"]["enabled"] is True
    assert turn["pending"]["payload"]["hour"] == 8
    assert turn["pending"]["payload"]["minute"] == 0

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert confirmed["status"] == "executed"
    assert confirmed["receipt"]["enabled"] is True
    assert confirmed["receipt"]["hour"] == 8
    assert confirmed["receipt"]["minute"] == 0
    assert confirmed["receipt"]["deep_link"] == "fitai://settings"

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "关闭训练提醒"))
    assert turn["intent"] == "ui.configure_reminders"
    assert turn["pending"]["payload"]["enabled"] is False
    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert confirmed["status"] == "executed"
    assert confirmed["receipt"]["enabled"] is False

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "提醒改成晚上8点半"))
    assert turn["intent"] == "ui.configure_reminders"
    assert turn["pending"]["payload"]["hour"] == 20
    assert turn["pending"]["payload"]["minute"] == 30

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "训练提醒"))
    assert turn["intent"] == "coach.answer"


def test_reminder_resolution_variants():
    from app.services.coach_control.capabilities.ui_actions import (
        resolve_reminders,
    )

    assert resolve_reminders("每天20:30提醒我训练")["payload"] == {
        "enabled": True,
        "hour": 20,
        "minute": 30,
    }
    assert resolve_reminders("早上7点提醒")["payload"]["hour"] == 7
    assert resolve_reminders("下午3点提醒")["payload"]["hour"] == 15
    assert resolve_reminders("关闭提醒")["payload"] == {"enabled": False}
    missing = resolve_reminders("帮我设置训练提醒")
    assert missing["ready"] is False
    assert "几点" in missing["questions"][0]


def test_remember_preference_via_control_plane(db):
    import asyncio

    from app.models import AIMemory

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "记住我每周二四六练")
    )
    assert turn["intent"] == "memory.remember"
    assert turn["pending"]["kind"] == "card"
    assert turn["pending"]["payload"]["content"] == "我每周二四六练"

    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert confirmed["status"] == "executed"
    memory = db.execute(select(AIMemory)).scalar_one()
    assert memory.content == "我每周二四六练"
    assert memory.active is True

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    db.refresh(memory)
    assert memory.active is False


def test_remember_does_not_collide_with_the_general_memory(db):
    from app.models import AIMemory
    from app.services.coach_control.capabilities.memory import execute

    db.add(
        AIMemory(
            user_id="user-1",
            kind="preference",
            memory_key="general",
            content="喜欢早上训练",
            source="agent",
            confidence=1.0,
            active=True,
        )
    )
    db.commit()

    result = execute(db, "user-1", "action-2", {"content": "我每周二四六练"})
    item = db.get(AIMemory, result["memory_id"])
    assert item is not None
    assert item.memory_key.startswith("explicit:")
    assert item.content == "我每周二四六练"

    again = execute(db, "user-1", "action-3", {"content": "我每周二四六练"})
    assert again["memory_id"] == item.id


def test_memory_undo_handles_duplicate_content(db):
    from app.models import AIMemory
    from app.services.coach_control.capabilities.memory import undo

    content = "我每周二四六练"
    db.add_all(
        [
            AIMemory(
                user_id="user-1",
                kind="preference",
                memory_key="general",
                content=content,
                source="coach_control",
                confidence=1.0,
                active=True,
            ),
            AIMemory(
                user_id="user-1",
                kind="preference",
                memory_key="general",
                content=content,
                source="coach_control",
                confidence=1.0,
                active=True,
            ),
        ]
    )
    db.commit()

    result = undo(db, "user-1", "action-1", {"content": content})
    assert result["restored"] is True
    active = db.execute(
        select(AIMemory).where(
            AIMemory.user_id == "user-1",
            AIMemory.content == content,
            AIMemory.active.is_(True),
        )
    ).scalars().all()
    assert len(active) == 1


def test_food_rules_ignore_narrative_segments():
    from app.services.food_text import meal_analysis, parse_meal, resolve_food_rules

    result = resolve_food_rules("这是我今天的晚饭，中午吃了300g燕麦+一杯冰美式")
    questions = " ".join(result.questions)
    names = [item["name"] for item in result.items]
    analysis = meal_analysis("这是我今天的晚饭，中午吃了300g燕麦+一杯冰美式")

    assert "这是我今天的晚饭" not in questions
    assert "燕麦" in names
    assert "冰美式" in names
    assert parse_meal("这是我今天的晚饭，中午吃了300g燕麦") == "dinner"
    assert analysis["meal"] == "dinner"
    assert analysis["mentions"] == ["dinner", "lunch"]
    assert analysis["explicit"] == ["lunch"]


def test_food_resolution_receives_history_and_draft(db, monkeypatch):
    import asyncio
    import json
    from types import SimpleNamespace

    from app.services import food_text

    captured: dict[str, str] = {}

    async def fake_complete_json(system, user, **kwargs):
        captured["payload"] = user
        return {
            "items": [
                {
                    "name": "干蒸牛肉",
                    "grams": 120,
                    "kcal": 220,
                    "protein_g": 25,
                    "carbs_g": 0,
                    "fat_g": 14,
                    "confidence": 0.8,
                },
                {
                    "name": "腊肠",
                    "grams": 80,
                    "kcal": 330,
                    "protein_g": 10,
                    "carbs_g": 2,
                    "fat_g": 28,
                    "confidence": 0.8,
                },
                {
                    "name": "米饭",
                    "grams": 250,
                    "kcal": 275,
                    "protein_g": 6,
                    "carbs_g": 60,
                    "fat_g": 1,
                    "confidence": 0.9,
                },
            ],
            "questions": [],
        }

    monkeypatch.setattr(
        food_text,
        "settings",
        SimpleNamespace(use_mock_llm=False),
    )
    monkeypatch.setattr(food_text.llm, "complete_json", fake_complete_json)

    result = asyncio.run(
        food_text.resolve_food_text(
            db,
            "user-1",
            "这是我今天的晚饭，中午吃了300g燕麦+一杯冰美式",
            meal="dinner",
            history_context=(
                "17:55 用户：图片里的菜加250g米饭热量多少？\n"
                "17:55 教练：干蒸牛肉120g、腊肠80g、米饭250g。"
            ),
        )
    )

    payload = json.loads(captured["payload"])
    assert "干蒸牛肉" in payload["history"]
    assert "250g" in payload["history"]
    assert "不要把‘这是我今天的晚饭" in "\n".join(payload["rules"])
    assert any(item["name"] == "米饭" and item["grams"] == 250 for item in result["items"])
    assert all("这是我今天的晚饭" not in q for q in result["questions"])


def test_diet_review_does_not_swallow_photo_questions():
    assert not runtime._looks_like_diet_review(
        "图片里的菜加250g米饭热量是多少"
    )
    assert runtime._looks_like_diet_review("今天饮食还缺什么")


def test_kg_is_not_a_food_unit():
    assert runtime._looks_like_food("记错了 今天是74kg") is False
    assert runtime._looks_like_weight("记错了 体重是74kg") is True


def test_plan_edit_is_not_a_weight_correction():
    message = "今天的练胸计划帮我改成：杠铃卧推、上斜杠铃卧推、器械推胸、蝴蝶机"
    assert runtime._looks_like_correction(message) is False
    assert runtime._looks_like_exercise_edit(message) is True


def test_reference_resolution_inherits_dates_meals_and_metrics():
    from types import SimpleNamespace

    from app.services.coach_control.references import resolve_references

    turn = SimpleNamespace(
        input_text="今天练什么",
        reply="下一练是周二：推。",
        intent="training.preview_next",
    )
    refs = resolve_references("那明天呢", [turn])
    assert refs.intent == "training.preview_next"
    assert refs.date is not None

    refs = resolve_references("那体脂呢", [])
    assert refs.metric == "body_fat"

    refs = resolve_references("那午饭呢", [])
    assert refs.meal == "lunch"


def test_training_preview_uses_the_referenced_date(db):
    from app.services.coach_control.capabilities.training_preview import resolve

    tomorrow = (datetime.now(ZoneInfo("Asia/Shanghai")).date() + timedelta(days=1)).isoformat()
    result = resolve(
        db,
        "user-1",
        {
            "plan": {
                "days": [
                    {"id": "d1", "date": tomorrow, "title": "胸", "completed": False, "skipped": False},
                    {"id": "d2", "date": "2026-12-01", "title": "腿", "completed": False, "skipped": False},
                ]
            },
            "references": {"date": tomorrow},
        },
    )
    assert "胸" in result["payload"]["summary"]
    assert "明天" in result["payload"]["summary"]


def test_session_summary_is_written_and_excluded_from_the_memory_book(db, monkeypatch):
    import asyncio
    from types import SimpleNamespace

    from app.models import CoachSession, CoachTurn
    from app.services import memory

    session = CoachSession(user_id="user-1", status="active")
    db.add(session)
    db.flush()
    for index in range(3):
        db.add(
            CoachTurn(
                session_id=session.id,
                user_id="user-1",
                input_text=f"我想每周二四六练 {index}",
                intent="coach.answer",
                status="completed",
                reply="记住了。",
            )
        )
    db.commit()

    async def fake_complete_text(*args, **kwargs):
        return "用户想每周二四六训练；当前没有未完成事项。"

    monkeypatch.setattr(
        memory,
        "settings",
        SimpleNamespace(use_mock_llm=False),
    )
    monkeypatch.setattr(memory.llm, "complete_text", fake_complete_text)

    saved = asyncio.run(
        memory.summarize_session(db, "user-1", session.id)
    )
    assert saved is not None
    assert saved.kind == "session_summary"
    assert memory.latest_session_summary(db, "user-1", session.id) == saved.content

    from app.services.coach_control.conversation import build_memory_book

    assert saved.content not in build_memory_book(db, "user-1")


def test_keyword_memory_retrieval_finds_old_constraints(db):
    from app.models import AIMemory
    from app.services.memory import read_relevant_memories

    db.add(
        AIMemory(
            user_id="user-1",
            kind="constraint",
            memory_key="knee",
            content="膝盖不舒服，深蹲不要上大重量。",
            source="agent",
            confidence=0.9,
            active=True,
        )
    )
    db.commit()

    results = read_relevant_memories(db, "user-1", "最近膝盖疼深蹲怎么办")
    assert any("膝盖" in item for item in results)


def test_conversation_context_keeps_fifty_turns_and_memory(db):
    from app.models import AIMemory, CoachSession, CoachTurn
    from app.services.coach_control.conversation import (
        build_conversation_context,
        build_memory_book,
    )

    session = CoachSession(user_id="user-1", status="active")
    db.add(session)
    db.flush()
    for index in range(60):
        db.add(
            CoachTurn(
                session_id=session.id,
                user_id="user-1",
                input_text=f"turn-{index}",
                intent="coach.answer",
                status="completed",
                reply=f"reply-{index}",
            )
        )
    db.add(
        AIMemory(
            user_id="user-1",
            kind="preference",
            memory_key="explicit:test",
            content="我每周二四六练",
            source="coach_control",
            confidence=1.0,
            active=True,
        )
    )
    db.commit()

    context = build_conversation_context(
        db,
        "user-1",
        session.id,
        max_turns=50,
    )
    assert len(context.turns) == 50
    assert context.turns[0].input_text == "turn-10"
    assert context.turns[-1].input_text == "turn-59"
    assert "我每周二四六练" in build_memory_book(db, "user-1")
    assert len(context.history_items()) == 100


def test_fit_history_keeps_fifty_turns():
    from app.models import ChatMessage
    from app.services.coach import _fit_history

    history = [
        ChatMessage(role="user" if index % 2 == 0 else "assistant", content=f"m{index}")
        for index in range(120)
    ]
    fitted = _fit_history(history)
    assert len(fitted) == 100
    assert fitted[0].content == "m20"
    assert fitted[-1].content == "m119"


def test_vision_turn_is_recorded_in_the_control_plane(db, monkeypatch):
    import asyncio
    import io

    from fastapi import UploadFile

    from app.routers import coach_control
    from app.services import access, coach_vision

    async def fake_review(*args, **kwargs):
        return {
            "mode": "training",
            "is_training": True,
            "summary": "深蹲底部膝盖轻微内扣。",
            "observations": ["脚掌稳定", "下蹲深度可以"],
            "next_cue": "起身时把膝盖对准脚尖。",
            "safety_flag": None,
            "warning": None,
        }

    monkeypatch.setattr(coach_vision, "review", fake_review)
    monkeypatch.setattr(access, "require_feature", lambda *a, **k: None)

    upload = UploadFile(
        file=io.BytesIO(b"jpeg-bytes"),
        filename="squat.jpg",
        headers={"content-type": "image/jpeg"},
    )
    result = asyncio.run(
        coach_control.create_vision_turn(
            "user-1",
            db,
            upload,
            question="请判断图片内容并给出训练建议",
            caption="看看我的深蹲",
            session_id=None,
            idempotency_key=None,
        )
    )

    assert result["turn_id"]
    assert result["session_id"]
    turns = db.execute(select(CoachTurn)).scalars().all()
    assert len(turns) == 1
    turn = turns[0]
    assert turn.intent == "coach.vision"
    assert turn.status == "completed"
    assert turn.input_text.startswith("[图片]")
    assert "看看我的深蹲" in turn.input_text
    assert "请判断图片内容" not in turn.input_text
    assert "深蹲底部膝盖轻微内扣" in turn.reply
    assert turn.session_id == result["session_id"]


def test_vision_retry_with_the_same_key_reuses_the_turn(db, monkeypatch):
    import asyncio
    import io

    from fastapi import UploadFile

    from app.routers import coach_control
    from app.services import access, coach_vision

    async def fake_review(*args, **kwargs):
        return {
            "mode": "equipment",
            "is_training": False,
            "summary": "这是一台坐姿划船机。",
            "observations": ["有配重片和把手"],
            "next_cue": "",
            "safety_flag": None,
            "warning": None,
        }

    monkeypatch.setattr(coach_vision, "review", fake_review)
    monkeypatch.setattr(access, "require_feature", lambda *a, **k: None)

    def upload():
        return UploadFile(
            file=io.BytesIO(b"equipment-jpeg"),
            filename="row.jpg",
            headers={"content-type": "image/jpeg"},
        )

    first = asyncio.run(
        coach_control.create_vision_turn(
            "user-1",
            db,
            upload(),
            question="这是什么器械",
            caption="器械照片",
            session_id=None,
            idempotency_key="retry-key-1",
        )
    )
    second = asyncio.run(
        coach_control.create_vision_turn(
            "user-1",
            db,
            upload(),
            question="这是什么器械",
            caption="器械照片",
            session_id=None,
            idempotency_key="retry-key-1",
        )
    )

    assert second["turn_id"] == first["turn_id"]
    assert second["session_id"] == first["session_id"]
    turns = db.execute(select(CoachTurn)).scalars().all()
    assert len(turns) == 1


def test_second_vision_turn_gets_control_plane_context(db, monkeypatch):
    import asyncio
    import io
    from types import SimpleNamespace

    from fastapi import UploadFile

    from app.routers import coach_control
    from app.services import access, coach_vision

    seen_context: list[str] = []

    async def fake_review(*args, **kwargs):
        seen_context.append(kwargs.get("conversation_context") or "")
        return {
            "mode": "training",
            "is_training": True,
            "summary": "第二次看到膝盖还是有点内扣。",
            "observations": ["脚掌稳定"],
            "next_cue": "继续对准脚尖。",
            "safety_flag": None,
            "warning": None,
        }

    monkeypatch.setattr(coach_vision, "review", fake_review)
    monkeypatch.setattr(access, "require_feature", lambda *a, **k: None)
    monkeypatch.setattr(
        coach_control.generation,
        "begin_generation",
        lambda *a, **k: SimpleNamespace(
            feature_key="ai_vision", idempotency_key=None
        ),
    )
    monkeypatch.setattr(
        coach_control.generation, "complete_generation", lambda *a, **k: None
    )
    monkeypatch.setattr(
        coach_control.generation, "abort_generation", lambda *a, **k: None
    )

    def upload():
        return UploadFile(
            file=io.BytesIO(b"jpeg-bytes"),
            filename="squat.jpg",
            headers={"content-type": "image/jpeg"},
        )

    first = asyncio.run(
        coach_control.create_vision_turn(
            "user-1",
            db,
            upload(),
            question="看看我的深蹲",
            caption="",
            session_id=None,
            idempotency_key=None,
        )
    )
    asyncio.run(
        coach_control.create_vision_turn(
            "user-1",
            db,
            upload(),
            question="这次呢",
            caption="",
            session_id=first["session_id"],
            idempotency_key=None,
        )
    )

    assert "看看我的深蹲" in seen_context[0] or seen_context[0] == ""
    assert "看看我的深蹲" in seen_context[1]
    assert "第二次看到膝盖还是有点内扣" in seen_context[1]
    turns = db.execute(
        select(CoachTurn).order_by(CoachTurn.created_at)
    ).scalars().all()
    assert len(turns) == 2


def test_latest_session_returns_the_most_recent_one(db):
    from app.models import CoachSession

    older = CoachSession(
        user_id="user-1",
        status="active",
        updated_at=datetime.now(timezone.utc) - timedelta(hours=2),
    )
    newer = CoachSession(
        user_id="user-1",
        status="active",
        updated_at=datetime.now(timezone.utc) - timedelta(minutes=5),
    )
    db.add_all([older, newer])
    db.commit()

    from app.routers import coach_control

    payload = coach_control.latest_session("user-1", db)
    assert payload["session"]["id"] == newer.id
    assert payload["pending"] is None


def test_reset_sessions_closes_history_and_latest_stays_empty(db):
    from app.models import CoachSession

    first = CoachSession(user_id="user-1", status="active")
    second = CoachSession(user_id="user-1", status="waiting")
    db.add_all([first, second])
    db.commit()

    from app.routers import coach_control

    result = coach_control.reset_sessions("user-1", db)
    assert result["closed"] == 2
    db.refresh(first)
    db.refresh(second)
    assert first.status == "closed"
    assert second.status == "closed"
    assert coach_control.latest_session("user-1", db)["session"] is None

    import asyncio

    turn = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "今天练什么",
            session_id=first.id,
        )
    )
    assert turn["session"]["id"] != first.id
    assert turn["session"]["status"] != "closed"


def test_coach_turn_feedback_records_once(db):
    from app.models import CoachSession, CoachTurn
    from app.routers.coach_control import CoachTurnFeedbackIn, coach_turn_feedback

    session = CoachSession(user_id="user-1", status="active")
    db.add(session)
    db.flush()
    turn = CoachTurn(
        session_id=session.id,
        user_id="user-1",
        input_text="今天练什么",
        intent="coach.answer",
        status="completed",
        reply="今天练胸。",
    )
    db.add(turn)
    db.commit()

    first = coach_turn_feedback(
        turn.id,
        CoachTurnFeedbackIn(rating="up"),
        "user-1",
        db,
    )
    assert first["status"] == "recorded"
    events = db.execute(
        select(DomainEvent).where(
            DomainEvent.type == "CoachTurnFeedback",
            DomainEvent.entity_id == turn.id,
        )
    ).scalars().all()
    assert len(events) == 1
    assert events[0].payload["rating"] == "up"

    coach_turn_feedback(
        turn.id,
        CoachTurnFeedbackIn(rating="down", reason="inaccurate"),
        "user-1",
        db,
    )
    events = db.execute(
        select(DomainEvent).where(
            DomainEvent.type == "CoachTurnFeedback",
            DomainEvent.entity_id == turn.id,
        )
    ).scalars().all()
    assert len(events) == 1


def test_coach_answer_receives_body_and_equipment_context(db, monkeypatch):
    import asyncio

    from app.models import Profile
    from app.services.coach_control.capabilities import coach_answer

    captured: dict[str, str | None] = {}

    async def fake_reply(db, profile, program, history, message, **kwargs):
        captured["context"] = kwargs.get("context")
        return {"reply": "收到", "safety_flag": None, "citations": []}

    monkeypatch.setattr(coach_answer, "coach_reply", fake_reply)

    result = asyncio.run(
        coach_answer.resolve(
            db,
            db.get(Profile, "user-1"),
            None,
            [],
            "这个器械怎么练",
            app_context={
                "body_analysis_context": "重点放在背部和臀部。",
                "equipment_context": {
                    "name": "坐姿划船",
                    "description": "背部器械，主要练背阔肌。",
                },
            },
        )
    )

    assert result["reply"] == "收到"
    assert captured["context"] is not None
    assert "重点放在背部和臀部" in captured["context"]
    assert "坐姿划船" in captured["context"]
    assert "背阔肌" in captured["context"]
