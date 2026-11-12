from datetime import date

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import Exercise, PlanExercise, Program, ProgramDay, User
from app.services.citations import build_reply_citations


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
    db.add_all(
        [
            Exercise(
                slug="goblet-squat",
                name_zh="高脚杯深蹲",
                name_en="goblet squat",
                muscle_group="legs",
                equipment="dumbbell",
                is_active=True,
            ),
            Exercise(
                slug="bench-press",
                name_zh="杠铃卧推",
                name_en="barbell bench press",
                muscle_group="chest",
                equipment="barbell",
                is_active=True,
            ),
        ]
    )
    db.add(
        Program(
            id="plan-1",
            user_id="user-1",
            title="测试计划",
            goal_type="build_muscle",
            version=1,
            weeks=1,
            start_date=date.today(),
        )
    )
    db.add(
        ProgramDay(
            id="day-1",
            program_id="plan-1",
            week_index=1,
            weekday=1,
            title="下肢",
        )
    )
    db.add(
        PlanExercise(
            id="pe-1",
            program_day_id="day-1",
            exercise_slug="goblet-squat",
            order_index=1,
            sets=3,
            reps="10",
            rest_sec=60,
        )
    )
    db.commit()


def test_citations_use_plan_and_rag_sources(db, seeded):
    program = db.get(Program, "plan-1")

    citations = build_reply_citations(
        db,
        "今天练高脚杯深蹲和杠铃卧推，注意动作稳定。",
        program=program,
    )

    by_name = {item["name_zh"]: item for item in citations}
    assert by_name["高脚杯深蹲"]["slug"] == "goblet-squat"
    assert by_name["高脚杯深蹲"]["source"] == "current_plan"
    assert by_name["杠铃卧推"]["slug"] == "bench-press"
    assert by_name["杠铃卧推"]["source"]


def test_citations_ignore_hallucinated_exercises(db, seeded):
    citations = build_reply_citations(
        db,
        "你可以练火星推举和月球深蹲。",
        program=None,
    )

    assert citations == []


def test_citations_prefer_specific_name_and_limit(db, seeded):
    citations = build_reply_citations(
        db,
        "高脚杯深蹲和杠铃卧推都很好。",
        program=db.get(Program, "plan-1"),
        limit=1,
    )

    assert len(citations) == 1
    assert citations[0]["name_zh"] == "高脚杯深蹲"
