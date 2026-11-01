from datetime import date

from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import User
from app.services.meal_plans import list_week, save_day_plan, week_start_for, week_summary


def _session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session = Session(engine)
    session.add(User(id="u1", phone="13800138000", status="active"))
    session.commit()
    return session


def test_save_day_plan_persists_week_metadata():
    db = _session()
    day = date(2026, 11, 2)
    plan = {
        "date": day.isoformat(),
        "targets": {
            "target_kcal": 2200,
            "protein_g": 160,
            "carb_g": 230,
            "fat_g": 70,
        },
        "meals": [{"meal": "breakfast", "kcal": 500}],
        "generated_by": "ai",
        "model": "deepseek-flash",
        "warning": "测试提示",
    }
    record = save_day_plan(
        db,
        "u1",
        day,
        plan,
        strategy="carb_cycle",
        generated_by="ai",
        model_name="deepseek-flash",
    )
    db.commit()

    assert record.week_start == week_start_for(day)
    assert record.strategy == "carb_cycle"
    assert record.generated_by == "ai"
    assert record.model_name == "deepseek-flash"
    assert record.target_kcal == 2200
    assert record.target_protein_g == 160

    rows = list_week(db, "u1", week_start_for(day))
    assert len(rows) == 1
    summary = week_summary(rows)
    assert summary == {
        "generated_by": "ai",
        "warning": "测试提示",
        "strategy": "carb_cycle",
        "model": "deepseek-flash",
    }


def test_save_day_plan_updates_existing_row():
    db = _session()
    day = date(2026, 11, 2)
    plan = {"targets": {"target_kcal": 2000}}
    save_day_plan(
        db, "u1", day, plan, strategy="balanced", generated_by="template"
    )
    db.commit()

    plan["targets"]["target_kcal"] = 2100
    save_day_plan(
        db, "u1", day, plan, strategy="high_protein", generated_by="ai"
    )
    db.commit()

    rows = list_week(db, "u1", week_start_for(day))
    assert len(rows) == 1
    assert rows[0].strategy == "high_protein"
    assert rows[0].target_kcal == 2100
