import contextlib
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import (
    BodyMetric,
    Exercise,
    FoodLog,
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


def diet_turn(db, message, session_id=None):
    import asyncio

    return asyncio.run(
        runtime.handle_turn(db, "user-1", message, session_id=session_id)
    )


def coach_turn(db, message, session_id=None):
    return diet_turn(db, message, session_id=session_id)


def today_metric_time(hour=7):
    from datetime import datetime
    from zoneinfo import ZoneInfo

    return (
        datetime.now(ZoneInfo("Asia/Shanghai"))
        .replace(hour=hour, minute=0, second=0, microsecond=0)
        .astimezone(timezone.utc)
    )


def food_logs(db):
    return sorted(
        (
            log.meal,
            log.food_name,
            float(log.grams),
            log.logged_at.date().isoformat(),
        )
        for log in db.execute(select(FoodLog)).scalars().all()
    )


def shanghai_today():
    from datetime import datetime
    from zoneinfo import ZoneInfo

    return datetime.now(ZoneInfo("Asia/Shanghai")).date().isoformat()


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
    with contextlib.suppress(Exception):
        runtime.confirm_pending(db, "user-1", pending.id)
    logs = db.execute(select(FoodLog)).scalars().all()
    states = db.execute(select(PlanDayState)).scalars().all()
    assert logs == []
    assert states == []


def test_undo_replacement_restores_previous_food_logs(db):
    """Undoing a correction must not erase both the old and new records."""
    first = diet_turn(db, "午餐吃了200g鸡胸肉，150g米饭")
    confirmed = runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    corrected = diet_turn(
        db,
        "记错了，鸡胸肉是150g",
        session_id=first["session"]["id"],
    )
    assert corrected["pending"] is not None, corrected
    replaced = runtime.confirm_pending(
        db, "user-1", corrected["pending"]["id"]
    )
    runtime.undo_action(db, "user-1", replaced["action_id"])
    assert food_logs(db) == [
        ("lunch", "米饭", 150.0, shanghai_today()),
        ("lunch", "鸡胸肉", 200.0, shanghai_today()),
    ], food_logs(db)
    assert confirmed["action_id"] != replaced["action_id"]


def test_ambiguous_meal_correction_follow_up_stays_a_correction(db):
    """After asking which meal, a one-word answer must not start a new draft."""
    first = diet_turn(db, "午餐吃了200g鸡胸肉，晚餐吃了150g鸡胸肉")
    confirmed = runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    ambiguous = diet_turn(
        db,
        "记错了，鸡胸肉是150g",
        session_id=first["session"]["id"],
    )
    assert "哪一餐" in ambiguous["reply"], ambiguous

    follow = diet_turn(
        db,
        "午餐",
        session_id=first["session"]["id"],
    )
    assert follow["pending"] is not None, follow
    payload = follow["pending"]["payload"]
    assert payload.get("replace_action_id") == confirmed["action_id"], payload
    if follow["pending"]["kind"] == "card":
        runtime.confirm_pending(db, "user-1", follow["pending"]["id"])
        assert food_logs(db) == [
            ("dinner", "鸡胸肉", 150.0, shanghai_today()),
            ("lunch", "鸡胸肉", 150.0, shanghai_today()),
        ], food_logs(db)


def test_batch_food_correction_does_not_duplicate_or_move_meal(db):
    """A batch that logged lunch must still be correctable as lunch."""
    first = diet_turn(db, "记午饭鸡胸肉200g，再称体重73kg")
    assert first["pending"] is not None, first
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    assert food_logs(db) == [
        ("lunch", "鸡胸肉", 200.0, shanghai_today())
    ], food_logs(db)

    corrected = diet_turn(
        db,
        "记错了，鸡胸肉是150g",
        session_id=first["session"]["id"],
    )
    assert corrected["pending"] is not None, corrected
    if corrected["pending"]["kind"] == "card":
        runtime.confirm_pending(
            db, "user-1", corrected["pending"]["id"]
        )
    assert food_logs(db) == [
        ("lunch", "鸡胸肉", 150.0, shanghai_today())
    ], food_logs(db)


def test_food_correction_understands_explicit_old_value(db):
    """'不是200g，是150g' must update the named food's grams."""
    first = diet_turn(db, "午餐吃了200g鸡胸肉，150g米饭")
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    corrected = diet_turn(
        db,
        "记错了，鸡胸肉不是200g，是150g",
        session_id=first["session"]["id"],
    )
    assert corrected["pending"] is not None, corrected
    items = corrected["pending"]["payload"].get("items") or []
    assert sorted((item["name"], item["grams"]) for item in items) == [
        ("米饭", 150),
        ("鸡胸肉", 150),
    ], items


def test_food_correction_does_not_resurrect_deleted_item(db):
    """Replacing one food must not recreate another log deleted by the user."""
    first = diet_turn(db, "午餐吃了200g鸡胸肉，150g米饭")
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    rice = db.execute(
        select(FoodLog).where(FoodLog.food_name == "米饭")
    ).scalar_one()
    db.delete(rice)
    db.commit()

    corrected = diet_turn(
        db,
        "记错了，鸡胸肉是150g",
        session_id=first["session"]["id"],
    )
    assert corrected["pending"] is not None, corrected
    runtime.confirm_pending(db, "user-1", corrected["pending"]["id"])
    assert food_logs(db) == [
        ("lunch", "鸡胸肉", 150.0, shanghai_today())
    ], food_logs(db)


def test_cancel_food_replacement_keeps_previous_logs(db):
    first = diet_turn(db, "午餐吃了200g鸡胸肉，150g米饭")
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    corrected = diet_turn(
        db,
        "记错了，鸡胸肉是150g",
        session_id=first["session"]["id"],
    )
    runtime.cancel(db, "user-1", corrected["pending"]["id"])
    assert food_logs(db) == [
        ("lunch", "米饭", 150.0, shanghai_today()),
        ("lunch", "鸡胸肉", 200.0, shanghai_today()),
    ], food_logs(db)


def test_next_meal_after_diet_log_is_not_a_replacement(db):
    first = diet_turn(db, "午餐吃了200g鸡胸肉，150g米饭")
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    second = diet_turn(
        db,
        "晚餐吃了150g牛肉",
        session_id=first["session"]["id"],
    )
    assert second["pending"] is not None, second
    assert "replace_action_id" not in second["pending"]["payload"]
    runtime.confirm_pending(db, "user-1", second["pending"]["id"])
    assert food_logs(db) == [
        ("dinner", "牛肉", 150.0, shanghai_today()),
        ("lunch", "米饭", 150.0, shanghai_today()),
        ("lunch", "鸡胸肉", 200.0, shanghai_today()),
    ], food_logs(db)


def test_coach_weight_log_updates_profile_cache(db):
    """A coach weight log must feed the profile cache used by plan/nutrition."""
    turn = coach_turn(db, "今天体重73kg")
    runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    profile = db.get(Profile, "user-1")
    assert profile is not None
    assert profile.weight_kg == 73, profile.weight_kg


def test_coach_weight_undo_restores_previous_profile_cache(db):
    old = BodyMetric(
        user_id="user-1",
        client_id="old-weight",
        measured_at=today_metric_time() - timedelta(days=1),
        weight_kg=70,
    )
    db.add(old)
    profile = db.get(Profile, "user-1")
    profile.weight_kg = 70
    db.commit()

    turn = coach_turn(db, "今天体重73kg")
    confirmed = runtime.confirm_pending(
        db, "user-1", turn["pending"]["id"]
    )
    profile = db.get(Profile, "user-1")
    assert profile.weight_kg == 73, profile.weight_kg

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    profile = db.get(Profile, "user-1")
    assert profile.weight_kg == 70, profile.weight_kg


def test_delete_last_weight_clears_profile_cache(db):
    db.add(
        BodyMetric(
            user_id="user-1",
            client_id="today-weight-fat",
            measured_at=today_metric_time(),
            weight_kg=73,
            body_fat_pct=22,
        )
    )
    profile = db.get(Profile, "user-1")
    profile.weight_kg = 73
    profile.body_fat_pct = 22
    db.commit()

    turn = coach_turn(db, "删掉今天的体重记录")
    runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    metric = db.execute(select(BodyMetric)).scalar_one()
    assert metric.weight_kg is None
    assert metric.body_fat_pct == 22
    profile = db.get(Profile, "user-1")
    assert profile.weight_kg is None, profile.weight_kg
    assert profile.body_fat_pct == 22, profile.body_fat_pct


def test_delete_last_body_fat_clears_profile_cache(db):
    db.add(
        BodyMetric(
            user_id="user-1",
            client_id="today-fat",
            measured_at=today_metric_time(),
            body_fat_pct=22,
        )
    )
    profile = db.get(Profile, "user-1")
    profile.body_fat_pct = 22
    db.commit()

    turn = coach_turn(db, "删掉今天的体脂记录")
    runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert db.execute(select(BodyMetric)).scalars().all() == []
    profile = db.get(Profile, "user-1")
    assert profile.body_fat_pct is None, profile.body_fat_pct


def test_delete_whole_body_row_clears_profile_cache(db):
    db.add(
        BodyMetric(
            user_id="user-1",
            client_id="today-row",
            measured_at=today_metric_time(),
            weight_kg=73,
            body_fat_pct=22,
            waist_cm=82,
        )
    )
    profile = db.get(Profile, "user-1")
    profile.weight_kg = 73
    profile.body_fat_pct = 22
    profile.waist_cm = 82
    db.commit()

    turn = coach_turn(db, "删掉今天的身体记录")
    runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    assert db.execute(select(BodyMetric)).scalars().all() == []
    profile = db.get(Profile, "user-1")
    assert profile.weight_kg is None, profile.weight_kg
    assert profile.body_fat_pct is None, profile.body_fat_pct
    assert profile.waist_cm is None, profile.waist_cm


def test_food_correction_with_different_date_does_not_move_record(db):
    """Correcting with '昨天' must not silently move today's whole record."""
    first = diet_turn(db, "午餐吃了200g鸡胸肉，150g米饭")
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    corrected = diet_turn(
        db,
        "记错了，昨天午餐鸡胸肉是150g",
        session_id=first["session"]["id"],
    )
    if corrected["pending"] is not None:
        assert corrected["pending"]["kind"] == "card", corrected["pending"]
        runtime.confirm_pending(
            db, "user-1", corrected["pending"]["id"]
        )
    today_key = shanghai_today()
    current = food_logs(db)
    assert current in (
        [
            ("lunch", "米饭", 150.0, today_key),
            ("lunch", "鸡胸肉", 150.0, today_key),
        ],
        [
            ("lunch", "米饭", 150.0, today_key),
            ("lunch", "鸡胸肉", 200.0, today_key),
        ],
    ), current


def test_food_correction_without_food_name_asks(db):
    """'不是200g，是150g' does not identify which food; never claim success."""
    first = diet_turn(db, "午餐吃了200g鸡胸肉，150g米饭")
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    corrected = diet_turn(
        db,
        "记错了，不是200g，是150g",
        session_id=first["session"]["id"],
    )
    assert (
        corrected["pending"] is None
        or corrected["pending"]["kind"] == "draft"
    ), corrected["pending"]


def test_batch_food_update_and_reschedule_confirm_and_undo(db):
    first = diet_turn(db, "午餐吃了200g鸡胸肉，150g米饭")
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    target = today + timedelta(days=5)
    context = {
        "plan": {
            "id": "plan-batch-food-update",
            "version": 1,
            "days": [
                {
                    "id": "day-batch-food-update",
                    "date": today.isoformat(),
                    "title": "上肢",
                    "completed": False,
                    "skipped": False,
                }
            ],
        }
    }
    result = turn(
        db,
        f"把午餐鸡胸肉改成150g，再把今天的训练改到{target.month}月{target.day}日",
        context,
    )
    assert result["pending"] is not None, result
    assert result["pending"]["capability_id"] == "coach.batch", result
    assert [
        item["capability_id"] for item in result["pending"]["payload"]["batch"]
    ] == ["diet.update_log", "training.reschedule"], result
    confirmed = runtime.confirm_pending(
        db, "user-1", result["pending"]["id"]
    )
    assert food_logs(db) == [
        ("lunch", "米饭", 150.0, shanghai_today()),
        ("lunch", "鸡胸肉", 150.0, shanghai_today()),
    ], food_logs(db)
    state = db.execute(select(PlanDayState)).scalar_one()
    assert state.assigned_date == target
    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert food_logs(db) == [
        ("lunch", "米饭", 150.0, shanghai_today()),
        ("lunch", "鸡胸肉", 200.0, shanghai_today()),
    ], food_logs(db)
    assert db.execute(select(PlanDayState)).scalars().all() == []


def test_batch_food_delete_and_weight_confirm_and_undo(db):
    first = diet_turn(db, "午餐吃了200g鸡胸肉，150g米饭")
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    result = diet_turn(db, "删掉午餐鸡胸肉，再称体重73kg")
    assert result["pending"] is not None, result
    assert result["pending"]["capability_id"] == "coach.batch", result
    assert [
        item["capability_id"] for item in result["pending"]["payload"]["batch"]
    ] == ["diet.delete_log", "body.log_weight"], result
    confirmed = runtime.confirm_pending(
        db, "user-1", result["pending"]["id"]
    )
    assert food_logs(db) == [
        ("lunch", "米饭", 150.0, shanghai_today())
    ], food_logs(db)
    assert db.execute(select(BodyMetric)).scalar_one().weight_kg == 73
    runtime.undo_action(db, "user-1", confirmed["action_id"])
    assert food_logs(db) == [
        ("lunch", "米饭", 150.0, shanghai_today()),
        ("lunch", "鸡胸肉", 200.0, shanghai_today()),
    ], food_logs(db)
    assert db.execute(select(BodyMetric)).scalars().all() == []


def test_batch_two_food_updates_should_not_route_to_training(db):
    first = diet_turn(db, "午餐吃了200g鸡胸肉，150g米饭")
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    result = diet_turn(db, "把午餐鸡胸肉改成150g，再把午餐米饭改成100g")
    assert result["pending"] is not None, result
    assert result["pending"]["capability_id"] == "coach.batch", result
    assert [
        item["capability_id"] for item in result["pending"]["payload"]["batch"]
    ] == ["diet.update_log", "diet.update_log"], result
    runtime.confirm_pending(db, "user-1", result["pending"]["id"])
    assert food_logs(db) == [
        ("lunch", "米饭", 100.0, shanghai_today()),
        ("lunch", "鸡胸肉", 150.0, shanghai_today()),
    ], food_logs(db)


def test_batch_two_food_deletes_should_resolve_both(db):
    first = diet_turn(db, "午餐吃了200g鸡胸肉，150g米饭")
    runtime.confirm_pending(db, "user-1", first["pending"]["id"])
    result = diet_turn(db, "删掉午餐鸡胸肉，再删掉午餐米饭")
    assert result["pending"] is not None, result
    assert result["pending"]["capability_id"] == "coach.batch", result
    assert [
        item["capability_id"] for item in result["pending"]["payload"]["batch"]
    ] == ["diet.delete_log", "diet.delete_log"], result
    runtime.confirm_pending(db, "user-1", result["pending"]["id"])
    assert food_logs(db) == [], food_logs(db)


def test_two_single_exercise_edits_do_not_merge_wrong_exercises(db):
    """Two swaps in one sentence must be a batch or a clarification, never a
    single proposal that mixes the first target with the second source."""
    _, day, context = seed_chest_day(db)
    db.add(
        PlanExercise(
            program_day_id=day.id,
            exercise_slug="vital-machine-pec-deck-fly",
            order_index=2,
            sets=3,
            reps="8-12",
            rest_sec=90,
        )
    )
    db.commit()
    result = turn(
        db,
        "把哑铃卧推换成杠铃卧推，再把蝴蝶机夹胸换成绳索夹胸",
        context,
    )
    pending = result["pending"]
    assert pending is None or pending["capability_id"] == "coach.batch", pending
    if pending is not None:
        assert [
            item["capability_id"]
            for item in pending["payload"]["batch"]
        ] == [
            "training.edit_day_exercise",
            "training.edit_day_exercise",
        ], pending
        runtime.confirm_pending(db, "user-1", pending["id"])
        db.refresh(day)
        assert [item.exercise_slug for item in day.exercises] == [
            "bench_press",
            "vital-cable-fly",
        ]


def test_start_training_specific_day_beats_today_context(db):
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    tomorrow = today + timedelta(days=1)
    context = {
        "plan": {
            "id": "plan-start-specific",
            "days": [
                {
                    "id": "day-today",
                    "date": today.isoformat(),
                    "title": "胸",
                    "completed": False,
                    "skipped": False,
                },
                {
                    "id": "day-tomorrow",
                    "date": tomorrow.isoformat(),
                    "title": "背",
                    "completed": False,
                    "skipped": False,
                },
            ],
        },
        # The iOS app always sends today_day when today has a plan day.
        "today_day": {
            "id": "day-today",
            "title": "胸",
            "date": today.isoformat(),
            "completed": False,
        },
    }
    result = turn(db, "从明天的训练开始", context)
    assert result["intent"] == "ui.start_training", result
    assert result["pending"] is not None, result
    assert result["pending"]["payload"]["day_id"] == "day-tomorrow", result
    assert result["pending"]["payload"]["title"] == "背", result


def test_start_training_explicit_date_uses_that_day(db):
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    target = today + timedelta(days=3)
    context = {
        "plan": {
            "id": "plan-start-explicit",
            "days": [
                {
                    "id": "day-today",
                    "date": today.isoformat(),
                    "title": "胸",
                    "completed": False,
                    "skipped": False,
                },
                {
                    "id": "day-target",
                    "date": target.isoformat(),
                    "title": "腿",
                    "completed": False,
                    "skipped": False,
                },
            ],
        },
        "today_day": {
            "id": "day-today",
            "title": "胸",
            "date": today.isoformat(),
            "completed": False,
        },
    }
    result = turn(
        db,
        f"开始{target.month}月{target.day}日的训练",
        context,
    )
    assert result["intent"] == "ui.start_training", result
    assert result["pending"] is not None, result
    assert result["pending"]["payload"]["day_id"] == "day-target", result


def test_start_training_phrase_does_not_hijack_plan_management(db):
    """Plan-management wording must not become a today's-workout card."""
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    context = {
        "plan": {
            "id": "plan-start-new",
            "days": [
                {
                    "id": "day-today",
                    "date": today.isoformat(),
                    "title": "胸",
                    "completed": False,
                    "skipped": False,
                }
            ],
        },
        "today_day": {
            "id": "day-today",
            "title": "胸",
            "date": today.isoformat(),
            "completed": False,
        },
    }
    for message in ("开始新的训练计划", "开始调整训练计划"):
        result = turn(db, message, context)
        assert result["intent"] != "ui.start_training", (message, result)
