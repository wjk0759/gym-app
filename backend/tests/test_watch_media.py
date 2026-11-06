from types import SimpleNamespace

from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import ExerciseMediaAsset, Profile, User
from app.services.watch import media_for_day


def _session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    return Session(engine)


def _asset(slug: str, sex: str, version: int = 1) -> ExerciseMediaAsset:
    return ExerciseMediaAsset(
        exercise_slug=slug,
        sex=sex,
        source="test",
        phone_url=f"https://cdn/{slug}-{sex}-phone.mp4",
        watch_url=f"https://cdn/{slug}-{sex}-watch.mp4",
        poster_url=f"https://cdn/{slug}-{sex}.jpg",
        version=version,
        status="published",
    )


def test_media_prefers_exact_sex_then_unisex():
    db = _session()
    db.add_all(
        [
            User(id="female-user", status="active"),
            User(id="male-user", status="active"),
            Profile(user_id="female-user", sex="female"),
            Profile(user_id="male-user", sex="male"),
            _asset("bench", "male"),
            _asset("bench", "female"),
            _asset("bench", "unisex"),
            _asset("row", "male"),
        ]
    )
    db.commit()
    day = SimpleNamespace(
        exercises=[
            SimpleNamespace(exercise_slug="bench"),
            SimpleNamespace(exercise_slug="row"),
        ]
    )

    female = media_for_day(db, "female-user", day)
    male = media_for_day(db, "male-user", day)

    assert {item["exercise_slug"] for item in female} == {"bench", "row"}
    assert next(item for item in female if item["exercise_slug"] == "bench")["sex"] == "female"
    assert next(item for item in male if item["exercise_slug"] == "bench")["sex"] == "male"


def test_media_ignores_unpublished_rows():
    db = _session()
    draft = _asset("bench", "unisex")
    draft.status = "draft"
    db.add(draft)
    db.commit()
    day = SimpleNamespace(exercises=[SimpleNamespace(exercise_slug="bench")])

    assert media_for_day(db, "missing-profile", day) == []
