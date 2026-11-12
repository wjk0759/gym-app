from datetime import date, timedelta

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import (
    AgentPlanProposal,
    AgentRun,
    Exercise,
    Profile,
    User,
    utcnow,
)
from app.services.agent import apply_proposal
from app.services.plan_generator import validate_plan_for_user


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


def _plan(*extra_slugs: str) -> dict:
    exercises = [
        {"slug": "pushup", "sets": 3, "reps": "10", "rest_sec": 60},
        {"slug": "squat", "sets": 3, "reps": "12", "rest_sec": 60},
        {"slug": "plank", "sets": 3, "reps": "30s", "rest_sec": 45},
        *[
            {"slug": slug, "sets": 3, "reps": "10", "rest_sec": 60}
            for slug in extra_slugs
        ],
    ]
    return {
        "title": "安全校验计划",
        "weeks": 1,
        "days": [
            {
                "week_index": 1,
                "weekday": 1,
                "title": "全身",
                "focus": ["legs"],
                "exercises": exercises,
            }
        ],
    }


@pytest.fixture()
def seeded(db):
    db.add(User(id="user-1"))
    db.add(
        Profile(
            user_id="user-1",
            nickname="测试",
            sex="male",
            birth_date=date(date.today().year - 30, 1, 1),
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
            Exercise(
                slug="knee-extension",
                name_zh="坐姿腿屈伸",
                muscle_group="legs",
                equipment="bodyweight",
                is_active=True,
                plan_eligible=True,
                contraindications=["knee_pain"],
            ),
        ]
    )
    db.add(
        AgentRun(
            id="run-1",
            user_id="user-1",
            intent="coach_chat",
            status="completed",
            input_text="帮我排计划",
        )
    )
    db.commit()
    return db


def test_revalidation_flags_new_injury(db, seeded):
    plan = _plan("knee-extension")
    cleaned, warnings = validate_plan_for_user(db, "user-1", plan)
    assert warnings == []
    assert len(cleaned["days"][0]["exercises"]) == 4

    profile = db.get(Profile, "user-1")
    profile.injuries = ["膝盖疼"]
    db.commit()

    cleaned, warnings = validate_plan_for_user(db, "user-1", plan)
    assert any("伤病冲突" in warning for warning in warnings)
    assert all(
        item["slug"] != "knee-extension"
        for item in cleaned["days"][0]["exercises"]
    )


def test_apply_proposal_accepts_an_unchanged_plan(db, seeded):
    plan, warnings = validate_plan_for_user(db, "user-1", _plan())
    assert warnings == []
    proposal = AgentPlanProposal(
        id="proposal-ok",
        user_id="user-1",
        run_id="run-1",
        status="draft",
        title=plan["title"],
        plan_data=plan,
        diff_data={},
        validation_data={"warnings": [], "valid": True},
        expires_at=utcnow() + timedelta(minutes=30),
    )
    db.add(proposal)
    db.commit()

    program, applied = apply_proposal(db, "user-1", "proposal-ok")

    assert applied.status == "applied"
    assert program.title == plan["title"]
    assert len(program.days) == 1


def test_apply_proposal_rejects_a_plan_that_became_unsafe(db, seeded):
    plan, warnings = validate_plan_for_user(
        db,
        "user-1",
        _plan("knee-extension"),
    )
    assert warnings == []
    proposal = AgentPlanProposal(
        id="proposal-1",
        user_id="user-1",
        run_id="run-1",
        status="draft",
        title=plan["title"],
        plan_data=plan,
        diff_data={},
        validation_data={"warnings": [], "valid": True},
        expires_at=utcnow() + timedelta(minutes=30),
    )
    db.add(proposal)
    db.commit()

    profile = db.get(Profile, "user-1")
    profile.injuries = ["膝盖疼"]
    db.commit()

    with pytest.raises(ValueError, match="重新生成"):
        apply_proposal(db, "user-1", "proposal-1")

    db.refresh(proposal)
    assert proposal.status == "draft"
