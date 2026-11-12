from datetime import date

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
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
from app.routers.plans import activate_plan, import_plan, update_day
from app.schemas import (
    PlanDayPatch,
    PlanExercisePatch,
    PlanImportDayIn,
    PlanImportExerciseIn,
    PlanImportIn,
)


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
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


@pytest.fixture()
def seeded(db):
    db.add(User(id="user-1"))
    db.add(
        Profile(
            user_id="user-1",
            nickname="同步测试",
            sex="male",
            birth_date=date(1996, 1, 1),
            height_cm=175,
            weight_kg=70,
            equipment=["bodyweight"],
            injuries=[],
            weekly_days=1,
            session_minutes=45,
        )
    )
    db.add_all(
        [
            Exercise(
                slug="pushup",
                name_zh="俯卧撑",
                muscle_group="chest",
                equipment="bodyweight",
                is_active=True,
                plan_eligible=True,
                contraindications=[],
            ),
            Exercise(
                slug="squat",
                name_zh="深蹲",
                muscle_group="legs",
                equipment="bodyweight",
                is_active=True,
                plan_eligible=True,
                contraindications=[],
            ),
            Exercise(
                slug="plank",
                name_zh="平板支撑",
                muscle_group="core",
                equipment="bodyweight",
                is_active=True,
                plan_eligible=True,
                contraindications=[],
            ),
        ]
    )
    db.add(
        Program(
            id="plan-server",
            user_id="user-1",
            title="服务端计划",
            goal_type="recomp",
            version=1,
            status="active",
            weeks=1,
            start_date=date.today(),
        )
    )
    db.add(
        ProgramDay(
            id="day-server",
            program_id="plan-server",
            week_index=1,
            weekday=1,
            title="全身",
            focus=["legs"],
        )
    )
    db.add_all(
        [
            PlanExercise(
                program_day_id="day-server",
                exercise_slug="pushup",
                order_index=1,
                sets=3,
                reps="10",
                rest_sec=60,
            ),
            PlanExercise(
                program_day_id="day-server",
                exercise_slug="squat",
                order_index=2,
                sets=3,
                reps="10",
                rest_sec=60,
            ),
            PlanExercise(
                program_day_id="day-server",
                exercise_slug="plank",
                order_index=3,
                sets=3,
                reps="30s",
                rest_sec=60,
            ),
        ]
    )
    db.commit()
    return db


def test_update_day_checks_and_bumps_content_version(db, seeded):
    payload = PlanDayPatch(
        expected_plan_version=1,
        exercises=[
            PlanExercisePatch(
                slug="squat",
                sets=4,
                reps="8-10",
                weight_kg=20,
                rest_sec=90,
                rpe=8,
            )
        ],
    )

    result = update_day(
        "plan-server",
        "day-server",
        payload,
        "user-1",
        db,
    )

    assert result["version"] == 2
    assert result["days"][0]["exercises"][0]["slug"] == "squat"
    assert result["days"][0]["exercises"][0]["sets"] == 4

    with pytest.raises(HTTPException) as exc:
        update_day(
            "plan-server",
            "day-server",
            PlanDayPatch(
                expected_plan_version=1,
                exercises=[PlanExercisePatch(slug="pushup")],
            ),
            "user-1",
            db,
        )
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "PLAN_VERSION_CONFLICT"


def test_update_day_rejects_duplicate_exercises(db, seeded):
    with pytest.raises(HTTPException) as exc:
        update_day(
            "plan-server",
            "day-server",
            PlanDayPatch(
                expected_plan_version=1,
                exercises=[
                    PlanExercisePatch(slug="pushup"),
                    PlanExercisePatch(slug="pushup"),
                ],
            ),
            "user-1",
            db,
        )
    assert exc.value.status_code == 422


def test_import_plan_preserves_local_ids_and_archives_old_plan(db, seeded):
    local_plan_id = "11111111-1111-1111-1111-111111111111"
    local_day_id = "22222222-2222-2222-2222-222222222222"
    payload = PlanImportIn(
        title="本地模板计划",
        weeks=1,
        generated_by="local",
        days=[
            PlanImportDayIn(
                id=local_day_id,
                week_index=1,
                weekday=1,
                title="全身",
                focus=["legs"],
                exercises=[
                    PlanImportExerciseIn(slug="pushup", sets=3, reps="10"),
                    PlanImportExerciseIn(slug="squat", sets=3, reps="12"),
                    PlanImportExerciseIn(slug="plank", sets=3, reps="30s"),
                ],
            )
        ],
    )

    result = import_plan(
        local_plan_id,
        payload,
        "user-1",
        db,
    )

    assert result["id"] == local_plan_id
    assert result["version"] == 1
    assert result["days"][0]["id"] == local_day_id
    old = db.get(Program, "plan-server")
    assert old.status == "archived"
    new = db.get(Program, local_plan_id)
    assert new.status == "active"
    assert len(new.days[0].exercises) == 3


def test_onboarding_preview_is_pending_until_activated(db, seeded):
    from app.services.serializers import save_plan

    plan_doc = {
        "title": "预览计划",
        "weeks": 1,
        "days": [
            {
                "week_index": 1,
                "weekday": 1,
                "title": "全身",
                "focus": ["legs"],
                "exercises": [
                    {
                        "slug": "pushup",
                        "order_index": 1,
                        "sets": 3,
                        "reps": "10",
                        "weight_kg": None,
                        "rest_sec": 60,
                        "rpe": 7,
                    },
                    {
                        "slug": "squat",
                        "order_index": 2,
                        "sets": 3,
                        "reps": "10",
                        "weight_kg": None,
                        "rest_sec": 60,
                        "rpe": 7,
                    },
                    {
                        "slug": "plank",
                        "order_index": 3,
                        "sets": 3,
                        "reps": "30s",
                        "weight_kg": None,
                        "rest_sec": 60,
                        "rpe": 7,
                    },
                ],
            }
        ],
    }
    pending = save_plan(
        db,
        "user-1",
        plan_doc,
        goal_type="recomp",
        generated_by="template",
        status="pending",
    )
    assert pending.status == "pending"

    active = activate_plan(pending.id, "user-1", db)

    assert active["status"] == "active"
    assert active["version"] == pending.version
    assert db.get(Program, pending.id).status == "active"


def test_import_plan_rejects_stale_version_for_existing_plan(db, seeded):
    payload = PlanImportIn(
        title="覆盖服务端计划",
        weeks=1,
        expected_plan_version=1,
        generated_by="manual",
        days=[
            PlanImportDayIn(
                week_index=1,
                weekday=1,
                title="全身",
                exercises=[
                    PlanImportExerciseIn(slug="pushup"),
                    PlanImportExerciseIn(slug="squat"),
                    PlanImportExerciseIn(slug="plank"),
                ],
            )
        ],
    )

    result = import_plan("plan-server", payload, "user-1", db)
    assert result["version"] == 2

    with pytest.raises(HTTPException) as exc:
        import_plan(
            "plan-server",
            payload,
            "user-1",
            db,
        )
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "PLAN_VERSION_CONFLICT"
