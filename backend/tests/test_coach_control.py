from datetime import date, datetime
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import (
    CoachActionRecord,
    CoachPending,
    CoachSession,
    DomainEvent,
    FoodLog,
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
