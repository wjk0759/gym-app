from __future__ import annotations

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import (
    EquipmentLibraryItem,
    Profile,
    User,
    UserEquipmentEntry,
    UserUniversalEquipment,
)
from app.services.equipment_inventory import (
    delete_library_entry,
    effective_equipment_types,
    replace_profile_equipment,
    replace_universal_entries,
    sync_library_entry,
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
    session.add(User(id="user-1", phone="13428104171", status="active"))
    session.add(Profile(user_id="user-1", equipment=["bodyweight"]))
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def test_profile_equipment_replaces_category_entries(db):
    replace_profile_equipment(db, "user-1", ["bodyweight", "dumbbell"])
    db.commit()
    types = effective_equipment_types(db, "user-1")
    assert types == ["bodyweight", "dumbbell"]

    replace_profile_equipment(db, "user-1", ["bodyweight", "band"])
    db.commit()
    types = effective_equipment_types(db, "user-1")
    assert types == ["bodyweight", "band"]
    rows = db.execute(select(UserEquipmentEntry)).scalars().all()
    assert {
        row.equipment_type
        for row in rows
        if row.enabled and row.deleted_at is None
    } == {"bodyweight", "band"}


def test_library_item_keeps_type_after_profile_removal(db):
    item = EquipmentLibraryItem(
        user_id="user-1",
        client_id="db-1",
        name="哑铃",
        equipment_type="dumbbell",
        equipment="dumbbell",
        category="free_weight",
        notes="",
    )
    db.add(item)
    db.flush()
    sync_library_entry(db, "user-1", item)
    replace_profile_equipment(db, "user-1", ["bodyweight", "dumbbell"])
    db.commit()

    replace_profile_equipment(db, "user-1", ["bodyweight"])
    db.commit()
    assert "dumbbell" in effective_equipment_types(db, "user-1")

    delete_library_entry(db, "user-1", "db-1")
    db.delete(item)
    db.commit()
    assert "dumbbell" not in effective_equipment_types(db, "user-1")


def test_universal_entries_are_synced(db):
    replace_universal_entries(db, "user-1", ["barbell", "band"])
    db.commit()
    types = effective_equipment_types(db, "user-1")
    assert "barbell" in types
    assert "band" in types

    replace_universal_entries(db, "user-1", ["band"])
    db.commit()
    types = effective_equipment_types(db, "user-1")
    assert "barbell" not in types
    assert "band" in types


def test_universal_checklist_clears_only_matching_profile_categories(db):
    replace_profile_equipment(
        db, "user-1", ["bodyweight", "dumbbell", "machine"]
    )
    db.commit()

    replace_universal_entries(db, "user-1", ["bodyweight"])
    db.commit()

    types = effective_equipment_types(db, "user-1")
    assert "dumbbell" not in types
    assert "bodyweight" in types
    # Machine was declared during onboarding, not via the universal checklist.
    assert "machine" in types


def test_profile_removal_clears_legacy_universal_checkbox(db):
    db.add(
        UserUniversalEquipment(
            user_id="user-1",
            equipment_slug="dumbbell",
            enabled=True,
        )
    )
    db.commit()
    assert "dumbbell" in effective_equipment_types(db, "user-1")

    replace_profile_equipment(db, "user-1", ["bodyweight"])
    db.commit()

    assert "dumbbell" not in effective_equipment_types(db, "user-1")
    legacy = db.execute(select(UserUniversalEquipment)).scalar_one()
    assert legacy.enabled is False


def test_legacy_profile_fallback_still_works(db):
    profile = db.get(Profile, "user-1")
    profile.equipment = ["bodyweight", "kettlebell"]
    db.commit()
    assert effective_equipment_types(db, "user-1") == [
        "bodyweight",
        "kettlebell",
    ]
