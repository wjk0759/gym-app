from datetime import date, datetime
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import (
    BodyMetric,
    CoachActionRecord,
    CoachPending,
    CoachSession,
    DomainEvent,
    Exercise,
    FoodLog,
    Goal,
    PlanDayState,
    Profile,
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

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert db.execute(select(WorkoutSession)).scalars().all() == []


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


def test_food_question_does_not_create_a_logging_draft(db):
    import asyncio

    turn = asyncio.run(runtime.handle_turn(db, "user-1", "减脂怎么吃"))
    assert turn["intent"] == "unsupported"
    assert turn["pending"] is None


def test_unrelated_message_cancels_a_stale_draft(db):
    import asyncio

    first = asyncio.run(runtime.handle_turn(db, "user-1", "午餐喝了奶茶"))
    assert first["pending"]["kind"] == "draft"

    second = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "今天练什么",
            session_id=first["session"]["id"],
        )
    )
    assert second["pending"] is None
    assert second["intent"] == "unsupported"
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
