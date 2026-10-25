"""Lightweight query-count probe for the list endpoints.

Run from backend:
    .\\.venv\\Scripts\\python.exe scripts\\perf_probe.py

The probe uses a throwaway SQLite database and prints SQL statement counts, which
are more stable than wall-clock timings on a laptop. It is intentionally not a
pytest test because it seeds a realistic amount of related data.
"""

from __future__ import annotations

import os
import sys
import tempfile
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

DB_PATH = Path(tempfile.gettempdir()) / "fitai_perf_probe.db"
for suffix in ("", "-wal", "-shm"):
    Path(str(DB_PATH) + suffix).unlink(missing_ok=True)

os.environ["DATABASE_URL"] = f"sqlite:///{DB_PATH.as_posix()}"
os.environ["APP_ENV"] = "dev"
os.environ["LLM_PROVIDER"] = "mock"

from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import event, select  # noqa: E402

from app.db import SessionLocal, engine  # noqa: E402
from app.deps import DEMO_USER_ID  # noqa: E402
from app.main import app  # noqa: E402
from app.models import (  # noqa: E402
    ChatMessage,
    ChatSession,
    Exercise,
    PlanExercise,
    Profile,
    Program,
    ProgramDay,
    SetLog,
    WorkoutSession,
)

statements: list[str] = []


@event.listens_for(engine, "before_cursor_execute")
def _before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    statements.append(statement)


def seed() -> None:
    with SessionLocal() as db:
        profile = db.get(Profile, DEMO_USER_ID)
        if profile is None:
            db.add(
                Profile(
                    user_id=DEMO_USER_ID,
                    nickname="Perf probe",
                    height_cm=175,
                    weight_kg=72,
                    weekly_days=3,
                    session_minutes=60,
                )
            )

        slugs = [row[0] for row in db.execute(select(Exercise.slug).limit(5)).all()]
        program = Program(
            user_id=DEMO_USER_ID,
            title="Perf probe plan",
            goal_type="recomp",
            version=1,
            status="active",
            weeks=4,
            generated_by="probe",
        )
        for week in range(1, 5):
            for weekday in (1, 3, 5):
                day = ProgramDay(
                    week_index=week,
                    weekday=weekday,
                    title=f"Week {week}",
                    focus=["chest"],
                )
                for index, slug in enumerate(slugs, start=1):
                    day.exercises.append(
                        PlanExercise(
                            exercise_slug=slug,
                            order_index=index,
                            sets=4,
                            reps="10-12",
                            weight_kg=20,
                            rest_sec=60,
                            rpe=7,
                        )
                    )
                program.days.append(day)
        db.add(program)

        now = datetime.now(timezone.utc)
        for i in range(60):
            session = WorkoutSession(
                user_id=DEMO_USER_ID,
                started_at=now - timedelta(days=i),
                finished_at=now - timedelta(days=i) + timedelta(minutes=55),
                duration_min=55,
                feeling=4,
            )
            for index, slug in enumerate(slugs, start=1):
                session.sets.append(
                    SetLog(
                        exercise_slug=slug,
                        set_index=index,
                        weight_kg=20,
                        reps=10,
                        rpe=7,
                        completed=True,
                    )
                )
            db.add(session)

        for i in range(25):
            chat = ChatSession(user_id=DEMO_USER_ID, title=f"Chat {i}")
            for j in range(8):
                chat.messages.append(
                    ChatMessage(
                        role="user" if j % 2 == 0 else "assistant",
                        content=f"Message {i}-{j} " + ("training advice " * 20),
                        safety_flag=(
                            "medical_referral" if j == 3 and i % 5 == 0 else None
                        ),
                    )
                )
            db.add(chat)
        db.commit()


with TestClient(app) as client:
    seed()
    with SessionLocal() as db:
        plan_id = db.execute(select(Program.id)).scalars().first()
        workout_id = db.execute(select(WorkoutSession.id)).scalars().first()
        chat_id = db.execute(select(ChatSession.id)).scalars().first()

    user_headers = {"X-User-Id": DEMO_USER_ID}
    admin_headers = {"X-Admin-Token": "dev-admin-token"}
    endpoints = [
        ("workouts", "/api/v1/workouts?limit=50", user_headers),
        ("summary", "/api/v1/workouts/summary?weeks=8", user_headers),
        ("workout-detail", f"/api/v1/workouts/{workout_id}", user_headers),
        ("plan-current", "/api/v1/plans/current", user_headers),
        ("plan-detail", f"/api/v1/plans/{plan_id}", user_headers),
        ("admin-stats", "/api/v1/admin/stats", admin_headers),
        ("admin-workouts", "/api/v1/admin/workouts?limit=50", admin_headers),
        (
            "admin-workout-detail",
            f"/api/v1/admin/workouts/{workout_id}",
            admin_headers,
        ),
        ("admin-programs", "/api/v1/admin/programs?limit=50", admin_headers),
        (
            "admin-program-detail",
            f"/api/v1/admin/programs/{plan_id}",
            admin_headers,
        ),
        ("admin-chats", "/api/v1/admin/chats?limit=50", admin_headers),
        ("admin-chat-detail", f"/api/v1/admin/chats/{chat_id}", admin_headers),
        (
            "admin-user-detail",
            f"/api/v1/admin/users/{DEMO_USER_ID}",
            admin_headers,
        ),
    ]

    for name, path, headers in endpoints:
        client.get(path, headers=headers)  # warm up
        statements.clear()
        started = time.perf_counter()
        response = client.get(path, headers=headers)
        elapsed = (time.perf_counter() - started) * 1000
        print(
            f"{name:20s} status={response.status_code} "
            f"time={elapsed:7.1f}ms queries={len(statements):3d} "
            f"bytes={len(response.content)}"
        )

engine.dispose()
for suffix in ("", "-wal", "-shm"):
    Path(str(DB_PATH) + suffix).unlink(missing_ok=True)
