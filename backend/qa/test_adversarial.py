from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import (
    Exercise,
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
    _, _day, context = seed_chest_day(db)
    result = turn(db, "把哑铃卧推换成杠铃卧推 4组8次", context)
    assert result["intent"] == "training.edit_day_exercise"
    assert result["pending"] is not None, result
    payload = result["pending"]["payload"]
    assert payload["exercises"][0]["slug"] == "bench_press"
    assert payload["exercises"][0]["sets"] == 4
    assert payload["exercises"][0]["reps"] == "8"


def test_swap_with_comma_parameters_should_route_to_single_edit(db):
    _, _day, context = seed_chest_day(db)
    result = turn(db, "把哑铃卧推换成杠铃卧推，4组8次", context)
    assert result["intent"] == "training.edit_day_exercise", result
    assert result["pending"] is not None, result


def test_add_with_sets_should_use_requested_sets(db):
    _, _day, context = seed_chest_day(db)
    result = turn(db, "给今天的练胸加一个蝴蝶机夹胸 3组12次", context)
    assert result["intent"] == "training.edit_day_exercise", result
    assert result["pending"] is not None, result
    added = result["pending"]["payload"]["exercises"][-1]
    assert added["slug"] == "vital-machine-pec-deck-fly"
    assert added["sets"] == 3
    assert added["reps"] == "12"


def test_add_with_comma_parameters_should_route_to_single_edit(db):
    _, _day, context = seed_chest_day(db)
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
    _, _day, context = seed_chest_day(db)
    result = turn(
        db,
        "给今天的练胸加一个蝴蝶机夹胸和绳索夹胸",
        context,
    )
    assert result["pending"] is not None, result
    slugs = {item["slug"] for item in result["pending"]["payload"]["exercises"]}
    assert {"vital-machine-pec-deck-fly", "vital-cable-fly"} <= slugs


def test_add_duplicate_exercise_should_ask_instead_of_duplicate(db):
    _, _day, context = seed_chest_day(db)
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


def test_week_schedule_understands_next_next_week(db):
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    this_monday = today - timedelta(days=today.weekday())
    days = [
        {
            "id": f"qa-week-{offset}",
            "date": (this_monday + timedelta(days=offset)).isoformat(),
            "title": f"第{offset // 7 + 1}周训练",
            "completed": False,
            "skipped": False,
        }
        for offset in (0, 7, 14)
    ]
    context = {"plan": {"id": "plan-qa", "days": days}}
    result = turn(db, "下下周训练安排", context)
    assert result["intent"] == "training.week_schedule", result
    expected = (this_monday + timedelta(days=14)).isoformat()
    assert expected[5:] in result["reply"] or "第3周训练" in result["reply"], result["reply"]


def test_plan_day_state_ids_are_case_insensitive(db):
    from app.models import PlanDayState, Program, ProgramDay
    from app.services.coach_control.context import with_plan_context

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    program = Program(
        id="qa-plan-case",
        user_id="user-1",
        title="大小写测试",
        goal_type="recomp",
        version=1,
        status="active",
        start_date=today - timedelta(days=1),
        weeks=4,
    )
    day = ProgramDay(
        id="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        program_id=program.id,
        week_index=1,
        weekday=1,
        title="胸",
        focus=["chest"],
    )
    db.add(program)
    db.add(day)
    db.add(
        PlanDayState(
            user_id="user-1",
            plan_id=program.id,
            day_id=day.id.upper(),
            assigned_date=today + timedelta(days=5),
            client_updated_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
    )
    db.commit()
    context = with_plan_context(db, "user-1", None)
    actual = context.get("plan", {}).get("days", [{}])[0].get("date")
    assert actual == (today + timedelta(days=5)).isoformat(), actual


def test_sync_repeated_snapshots_are_idempotent(db):
    from app.schemas import CustomFoodSyncIn, ExerciseDislikeSyncIn, FavoriteFoodSyncIn, SyncIn
    from app.services.user_sync import apply_sync

    foods = [
        CustomFoodSyncIn(client_id=f"stress-food-{i}", name=f"压力食物{i}", kcal=100 + i)
        for i in range(100)
    ]
    favorites = [
        FavoriteFoodSyncIn(food_key=f"custom:stress-food-{i}", name=f"压力食物{i}")
        for i in range(100)
    ]
    dislikes = [ExerciseDislikeSyncIn(slug=f"stress-slug-{i}") for i in range(100)]
    payload = SyncIn(custom_foods=foods, favorites=favorites, disliked_exercises=dislikes)
    for _ in range(20):
        result = apply_sync(db, "user-1", payload)
    assert len(result["custom_foods"]) == 100
    assert len(result["favorites"]) == 100
    assert len(result["disliked_exercises"]) == 100
    assert len({item["client_id"] for item in result["custom_foods"]}) == 100


def test_sync_duplicate_items_in_one_snapshot_do_not_crash(db):
    from app.schemas import CustomFoodSyncIn, ExerciseDislikeSyncIn, FavoriteFoodSyncIn, SyncIn
    from app.services.user_sync import apply_sync

    result = apply_sync(
        db,
        "user-1",
        SyncIn(
            custom_foods=[
                CustomFoodSyncIn(client_id="dup-food", name="第一份", kcal=100),
                CustomFoodSyncIn(client_id="dup-food", name="第二份", kcal=200),
            ],
            favorites=[
                FavoriteFoodSyncIn(food_key="dup-key", name="第一份"),
                FavoriteFoodSyncIn(food_key="dup-key", name="第二份"),
            ],
            disliked_exercises=[
                ExerciseDislikeSyncIn(slug="dup-slug"),
                ExerciseDislikeSyncIn(slug="dup-slug"),
            ],
        ),
    )
    assert len(result["custom_foods"]) == 1
    assert len(result["favorites"]) == 1
    assert len(result["disliked_exercises"]) == 1


def test_sync_tombstone_can_be_revived(db):
    from app.schemas import CustomFoodSyncIn, SyncIn
    from app.services.user_sync import apply_sync

    apply_sync(db, "user-1", SyncIn(custom_foods=[CustomFoodSyncIn(client_id="revive-food", name="旧", kcal=100)]))
    apply_sync(db, "user-1", SyncIn(custom_foods=[CustomFoodSyncIn(client_id="revive-food", name="旧", deleted=True)]))
    result = apply_sync(db, "user-1", SyncIn(custom_foods=[CustomFoodSyncIn(client_id="revive-food", name="新", kcal=120)]))
    assert len(result["custom_foods"]) == 1
    assert result["custom_foods"][0]["name"] == "新"


def test_workout_draft_rapid_updates_keep_one_row(db):
    from datetime import datetime, timedelta, timezone
    from app.schemas import WorkoutDraftIn
    from app.services.workout_draft import get_draft, upsert_draft

    now = datetime.now(timezone.utc)
    for index in range(200):
        accepted, _ = upsert_draft(
            db,
            "user-1",
            WorkoutDraftIn(
                day_id="day-rapid",
                updated_at=now + timedelta(seconds=index),
                payload={"currentIndex": index},
            ),
        )
        assert accepted is True
    item = get_draft(db, "user-1")
    assert item is not None
    assert item.payload["currentIndex"] == 199
    assert item.day_id == "day-rapid"


def test_cycle_sync_round_trips_valid_snapshot(db):
    from datetime import date
    from app.schemas import CycleSyncIn, SyncIn
    from app.services.user_sync import apply_sync

    result = apply_sync(
        db,
        "user-1",
        SyncIn(
            cycle=CycleSyncIn(
                range_start=date(2026, 11, 1),
                range_end=date(2026, 11, 5),
                dates=["2026-11-01", "2026-11-02", "2026-11-03"],
                training_mode="light",
            )
        ),
    )
    cycle = result.get("cycle") or {}
    assert cycle.get("training_mode") == "light"
    assert cycle.get("dates") == ["2026-11-01", "2026-11-02", "2026-11-03"]


def test_batch_confirm_rolls_back_when_second_action_fails(db):
    from app.models import CoachPending, FoodLog
    from sqlalchemy import select

    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    context = {
        "plan": {
            "id": "plan-qa-batch",
            "version": 1,
            "days": [
                {
                    "id": "day-qa-batch",
                    "date": today.isoformat(),
                    "title": "上肢",
                    "completed": False,
                    "skipped": False,
                }
            ],
        }
    }
    result = turn(db, "记午饭鸡胸肉200g，再把今天的训练改到11月20日", context)
    assert result["pending"] is not None, result
    pending = db.get(CoachPending, result["pending"]["id"])
    assert pending is not None
    batch = pending.payload.get("batch")
    assert isinstance(batch, list) and len(batch) >= 2
    # Break the second item. The first food write must be rolled back.
    batch[1]["payload"]["day_id"] = "missing-day"
    batch[1]["payload"]["plan_id"] = "missing-plan"
    try:
        runtime.confirm_pending(db, "user-1", pending.id)
    except Exception:
        pass
    logs = db.execute(select(FoodLog)).scalars().all()
    states = db.execute(select(PlanDayState)).scalars().all()
    assert logs == []
    assert states == []
