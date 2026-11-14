from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import (
    Exercise,
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


def seed_chest_day(db, *, start_weekday=1):
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    monday = today - timedelta(days=today.weekday())
    for slug, name in [
        ("old-dumbbell-press", "哑铃卧推"),
        ("bench_press", "杠铃卧推"),
        ("vital-machine-pec-deck-fly", "蝴蝶机夹胸"),
        ("vital-cable-fly", "绳索夹胸"),
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
    context = {
        "plan": {
            "id": program.id,
            "version": program.version,
            "days": [
                {
                    "id": day.id,
                    "date": today.isoformat(),
                    "title": "胸",
                    "focus": ["chest"],
                    "completed": False,
                    "skipped": False,
                }
            ],
        }
    }
    return program, day, context


def turn(db, message, context):
    import asyncio

    return asyncio.run(
        runtime.handle_turn(db, "user-1", message, app_context=context)
    )


def test_swap_with_parameters_should_keep_new_exercise_and_sets(db):
    _, day, context = seed_chest_day(db)
    result = turn(db, "把哑铃卧推换成杠铃卧推 4组8次", context)
    assert result["intent"] == "training.edit_day_exercise"
    assert result["pending"] is not None, result
    payload = result["pending"]["payload"]
    assert payload["exercises"][0]["slug"] == "bench_press"
    assert payload["exercises"][0]["sets"] == 4
    assert payload["exercises"][0]["reps"] == "8"


def test_swap_with_comma_parameters_should_route_to_single_edit(db):
    _, day, context = seed_chest_day(db)
    result = turn(db, "把哑铃卧推换成杠铃卧推，4组8次", context)
    assert result["intent"] == "training.edit_day_exercise", result
    assert result["pending"] is not None, result


def test_add_with_sets_should_use_requested_sets(db):
    _, day, context = seed_chest_day(db)
    result = turn(db, "给今天的练胸加一个蝴蝶机夹胸 3组12次", context)
    assert result["intent"] == "training.edit_day_exercise", result
    assert result["pending"] is not None, result
    added = result["pending"]["payload"]["exercises"][-1]
    assert added["slug"] == "vital-machine-pec-deck-fly"
    assert added["sets"] == 3
    assert added["reps"] == "12"


def test_add_with_comma_parameters_should_route_to_single_edit(db):
    _, day, context = seed_chest_day(db)
    result = turn(db, "给今天的练胸加一个蝴蝶机夹胸，3组12次", context)
    assert result["intent"] == "training.edit_day_exercise", result
    assert result["pending"] is not None, result


def test_remove_last_exercise_must_not_create_empty_day(db):
    _, day, context = seed_chest_day(db)
    result = turn(db, "把哑铃卧推删掉", context)
    if result["pending"] is not None:
        runtime.confirm_pending(db, "user-1", result["pending"]["id"])
    remaining = db.get(ProgramDay, day.id).exercises
    assert len(remaining) >= 1, "确认后训练日不能变成 0 个动作"


def test_add_multiple_exercises_should_not_silently_drop_one(db):
    _, day, context = seed_chest_day(db)
    result = turn(
        db,
        "给今天的练胸加一个蝴蝶机夹胸和绳索夹胸",
        context,
    )
    assert result["pending"] is not None, result
    slugs = {item["slug"] for item in result["pending"]["payload"]["exercises"]}
    assert {"vital-machine-pec-deck-fly", "vital-cable-fly"} <= slugs


def test_add_duplicate_exercise_should_ask_instead_of_duplicate(db):
    _, day, context = seed_chest_day(db)
    result = turn(db, "给今天的练胸加一个哑铃卧推", context)
    assert result["pending"] is None
    assert "已经" in result["reply"]


def test_full_day_duplicate_exercise_should_not_write_duplicates(db):
    _, day, context = seed_chest_day(db)
    result = turn(
        db,
        "今天的练胸计划帮我改成：杠铃卧推、杠铃卧推",
        context,
    )
    assert result["pending"] is not None, result
    runtime.confirm_pending(db, "user-1", result["pending"]["id"])
    slugs = [item.exercise_slug for item in db.get(ProgramDay, day.id).exercises]
    assert len(slugs) == len(set(slugs)), slugs


def test_body_review_equal_target_should_not_say_below_target(db):
    from app.models import BodyMetric, Goal

    now = datetime.now(timezone.utc)
    db.add(
        BodyMetric(
            user_id="user-1",
            client_id="qa-weight-1",
            measured_at=now - timedelta(weeks=4),
            weight_kg=70,
        )
    )
    db.add(
        BodyMetric(
            user_id="user-1",
            client_id="qa-weight-2",
            measured_at=now,
            weight_kg=70,
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
    result = turn(db, "最近体重怎么样", {})
    assert "已低于目标 0.0 kg" not in result["reply"], result["reply"]


def test_body_review_above_gain_target_should_not_say_still_short(db):
    from app.models import BodyMetric, Goal

    now = datetime.now(timezone.utc)
    db.add(
        BodyMetric(
            user_id="user-1",
            client_id="qa-gain-1",
            measured_at=now - timedelta(weeks=4),
            weight_kg=70,
        )
    )
    db.add(
        BodyMetric(
            user_id="user-1",
            client_id="qa-gain-2",
            measured_at=now,
            weight_kg=82,
        )
    )
    db.add(
        Goal(
            user_id="user-1",
            type="build_muscle",
            target_weight_kg=80,
            status="active",
        )
    )
    db.commit()
    result = turn(db, "最近体重怎么样", {})
    assert "还差 2.0 kg" not in result["reply"], result["reply"]


def test_negative_food_statement_should_not_create_log(db):
    result = turn(db, "我今天没吃晚饭", {})
    assert result["pending"] is None, result
    assert result["intent"] != "diet.log_food", result


def test_what_did_i_eat_routes_to_daily_diet_review(db):
    result = turn(db, "今天吃了什么", {})
    assert result["intent"] == "diet.review_day", result


def test_non_painful_body_part_can_still_train(db):
    result = turn(db, "膝盖疼，今天还能练胸吗", {})
    assert result["intent"] != "safety", result
    assert result["status"] != "blocked", result


def test_chest_pain_must_block_training(db):
    result = turn(db, "胸痛，今天还能练吗", {})
    assert result["intent"] == "safety", result
    assert result["status"] == "blocked", result
