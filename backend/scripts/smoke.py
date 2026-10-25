"""端到端冒烟测试：不依赖 Postgres，使用临时 SQLite。

运行：
    .\\.venv\\Scripts\\python.exe scripts\\smoke.py
"""

import base64
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB_PATH = ROOT / "smoke.db"
if DB_PATH.exists():
    DB_PATH.unlink()

os.environ["DATABASE_URL"] = f"sqlite:///{DB_PATH}"
os.environ["LLM_PROVIDER"] = "mock"

sys.path.insert(0, str(ROOT))

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402

PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
)


def main() -> None:
    with TestClient(app) as client:
        health = client.get("/health")
        assert health.status_code == 200, health.text
        print("health:", health.json())

        login = client.post("/api/v1/auth/dev-login", json={"nickname": "小林"})
        assert login.status_code == 200, login.text
        user_id = login.json()["user_id"]
        headers = {"X-User-Id": user_id}
        print("login:", user_id)

        profile = {
            "nickname": "小林",
            "sex": "male",
            "birth_date": "1998-03-12",
            "height_cm": 175,
            "weight_kg": 72.5,
            "body_fat_pct": 19.5,
            "chest_cm": 96,
            "waist_cm": 82,
            "hip_cm": 95,
            "experience": "beginner",
            "injuries": [],
            "equipment": ["bodyweight", "dumbbell", "machine", "cable"],
            "weekly_days": 3,
            "session_minutes": 45,
        }
        response = client.put("/api/v1/me/profile", json=profile, headers=headers)
        assert response.status_code == 200, response.text
        print("profile bmi:", response.json()["profile"]["bmi"])

        goal = {
            "type": "build_muscle",
            "target_weight_kg": 76,
            "target_date": "2027-06-01",
        }
        response = client.put("/api/v1/me/goal", json=goal, headers=headers)
        assert response.status_code == 200, response.text
        print("goal:", response.json()["goal"]["type"])

        response = client.post("/api/v1/plans/generate", json={"force": False}, headers=headers)
        assert response.status_code == 200, response.text
        plan = response.json()
        assert plan["days"], "plan has no days"
        print(
            "plan:",
            plan["title"],
            "version",
            plan["version"],
            "days",
            len(plan["days"]),
            "warnings",
            plan.get("warnings"),
        )

        day = plan["days"][0]
        print("day 1:", day["weekday"], day["title"], len(day["exercises"]))

        workout = {
            "program_day_id": day["id"],
            "started_at": "2026-10-25T10:00:00Z",
            "finished_at": "2026-10-25T10:45:00Z",
            "feeling": 4,
            "notes": "冒烟测试",
            "sets": [
                {
                    "slug": day["exercises"][0]["slug"],
                    "set_index": 1,
                    "weight_kg": 12,
                    "reps": 10,
                    "rpe": 7,
                    "completed": True,
                }
            ],
        }
        response = client.post("/api/v1/workouts", json=workout, headers=headers)
        assert response.status_code == 201, response.text
        print("workout:", response.json())

        response = client.get("/api/v1/workouts/summary?weeks=4", headers=headers)
        assert response.status_code == 200, response.text
        print("summary:", response.json())

        response = client.post(
            f"/api/v1/plans/{plan['id']}/adjust", headers=headers
        )
        assert response.status_code == 200, response.text
        print("adjust:", response.json()["changes"])

        response = client.post(
            "/api/v1/coach/chat",
            json={"message": "今天练什么？"},
            headers=headers,
        )
        assert response.status_code == 200, response.text
        print("coach:", response.json()["reply"][:60])

        response = client.post(
            "/api/v1/coach/chat",
            json={"message": "我训练时胸痛、喘不上气"},
            headers=headers,
        )
        assert response.status_code == 200, response.text
        body = response.json()
        assert body["safety_flag"] == "medical_referral", body
        print("safety:", body["safety_flag"])

        response = client.post(
            "/api/v1/equipment/scan",
            files={"file": ("machine.png", PNG, "image/png")},
            headers=headers,
        )
        assert response.status_code == 200, response.text
        scan = response.json()
        assert scan["candidates"], scan
        print("scan:", scan["candidates"][0]["name_zh"], scan["needs_confirmation"])

        response = client.post(
            "/api/v1/body/analyze",
            files={"file": ("body.jpg", PNG, "image/jpeg")},
            headers=headers,
        )
        assert response.status_code == 200, response.text
        body = response.json()
        assert body["focus_areas"], body
        print("body analysis:", body["summary"][:30], body["focus_areas"])

        response = client.post(
            "/api/v1/diet/analyze",
            files={"file": ("meal.png", PNG, "image/png")},
            headers=headers,
        )
        assert response.status_code == 200, response.text
        meal = response.json()
        assert meal["items"], meal
        print(
            "food analysis:",
            len(meal["items"]),
            "items",
            meal["total_kcal"],
            "kcal",
        )

        response = client.post(
            "/api/v1/plans/generate",
            json={
                "force": True,
                "equipment_slugs": ["lat_pulldown", "leg_press"],
            },
            headers=headers,
        )
        assert response.status_code == 200, response.text
        print("equipment-filtered plan days:", len(response.json()["days"]))

        response = client.get("/api/v1/exercises/search?q=深蹲")
        assert response.status_code == 200, response.text
        print("search:", [item["name_zh"] for item in response.json()["items"]])

        response = client.post("/api/v1/diet/plan", json={}, headers=headers)
        assert response.status_code == 200, response.text
        diet = response.json()
        print("diet:", diet["targets"]["target_kcal"], "kcal")

        response = client.get("/api/v1/diet/meituan-link")
        assert response.status_code == 501, response.text
        print("meituan: not configured (expected)")

    print("\nSMOKE OK")


if __name__ == "__main__":
    main()
