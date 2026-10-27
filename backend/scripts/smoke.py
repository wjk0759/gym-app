"""端到端冒烟测试：不依赖 Postgres，使用临时 SQLite。

运行：
    .\\.venv\\Scripts\\python.exe scripts\\smoke.py
"""

import base64
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB_PATH = ROOT / "smoke.db"
if DB_PATH.exists():
    DB_PATH.unlink()

os.environ["DATABASE_URL"] = f"sqlite:///{DB_PATH}"
os.environ["LLM_PROVIDER"] = "mock"
os.environ["MEDIA_ROOT"] = str(ROOT / "smoke_media")

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
        assert health.headers.get("X-Request-ID"), health.headers
        assert health.headers.get("Server-Timing"), health.headers
        ready = client.get("/health/ready")
        assert ready.status_code == 200, ready.text
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

        schedule_payload = {
            "plan_id": plan["id"],
            "plan_version": plan["version"],
            "days": [
                {
                    "day_id": day["id"],
                    "assigned_date": "2026-10-27",
                    "skipped_at": None,
                    "client_updated_at": "2026-10-27T10:00:00Z",
                }
            ],
        }
        response = client.put("/api/v1/schedule", json=schedule_payload, headers=headers)
        assert response.status_code == 200, response.text
        assert response.json()["accepted"] == [day["id"]], response.text
        response = client.get(
            f"/api/v1/schedule?plan_id={plan['id']}", headers=headers
        )
        assert response.status_code == 200, response.text
        assert response.json()["days"][0]["assigned_date"] == "2026-10-27"

        older = {
            **schedule_payload,
            "days": [
                {
                    **schedule_payload["days"][0],
                    "assigned_date": "2026-10-28",
                    "client_updated_at": "2026-10-27T09:00:00Z",
                }
            ],
        }
        response = client.put("/api/v1/schedule", json=older, headers=headers)
        assert response.status_code == 200, response.text
        assert response.json()["ignored"] == [day["id"]], response.text
        response = client.get(
            f"/api/v1/schedule?plan_id={plan['id']}", headers=headers
        )
        assert response.json()["days"][0]["assigned_date"] == "2026-10-27"
        print("schedule last-write-wins: ok")

        workout_started = (datetime.now(timezone.utc) - timedelta(days=1)).replace(
            hour=10, minute=0, second=0, microsecond=0
        )
        workout_finished = workout_started + timedelta(minutes=45)
        workout = {
            "client_id": "smoke-workout-01",
            "program_day_id": day["id"],
            "started_at": workout_started.isoformat().replace("+00:00", "Z"),
            "finished_at": workout_finished.isoformat().replace("+00:00", "Z"),
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
        workout_id = response.json()["id"]
        print("workout:", response.json())

        duplicate = client.post("/api/v1/workouts", json=workout, headers=headers)
        assert duplicate.status_code == 201, duplicate.text
        assert duplicate.json()["duplicate"] is True, duplicate.json()
        assert duplicate.json()["id"] == workout_id, duplicate.json()
        print("workout idempotency: ok")

        workout_update = {
            **workout,
            "feeling": 5,
            "notes": "冒烟测试-已编辑",
            "sets": [
                {
                    "slug": day["exercises"][0]["slug"],
                    "set_index": 1,
                    "weight_kg": 15,
                    "reps": 8,
                    "rpe": 8,
                    "completed": True,
                }
            ],
        }
        response = client.patch(
            f"/api/v1/workouts/{workout_id}",
            json=workout_update,
            headers=headers,
        )
        assert response.status_code == 200, response.text
        response = client.get(f"/api/v1/workouts/{workout_id}", headers=headers)
        assert response.status_code == 200, response.text
        updated = response.json()
        assert updated["feeling"] == 5, updated
        assert updated["notes"] == "冒烟测试-已编辑", updated
        assert updated["sets"][0]["weight_kg"] == 15, updated
        print("workout update:", updated["notes"])

        response = client.get(
            "/api/v1/workouts?limit=5&include_sets=true",
            headers=headers,
        )
        assert response.status_code == 200, response.text
        assert response.json()["items"][0]["sets"], response.text
        print("workout sync list: ok")

        response = client.post("/api/v1/agent/reviews/weekly", headers=headers)
        assert response.status_code == 200, response.text
        weekly_review = response.json()
        assert weekly_review["run_id"], weekly_review
        assert weekly_review["summary"], weekly_review
        assert weekly_review["actions"], weekly_review
        assert weekly_review["stats"]["sessions"] >= 1, weekly_review
        print(
            "weekly review:",
            weekly_review["stats"]["sessions"],
            "sessions,",
            weekly_review["summary"][:40],
        )

        response = client.post(
            "/api/v1/agent/actions/smoke-action/result",
            json={
                "run_id": weekly_review["run_id"],
                "action_type": "open_screen",
                "status": "executed",
                "message": "smoke action",
            },
            headers=headers,
        )
        assert response.status_code == 200, response.text
        actions = client.get("/api/v1/agent/actions", headers=headers)
        assert actions.status_code == 200, actions.text
        assert actions.json()["items"][0]["action_id"] == "smoke-action", actions.text
        response = client.post(
            "/api/v1/agent/actions/smoke-action/result",
            json={
                "run_id": weekly_review["run_id"],
                "action_type": "open_screen",
                "status": "undone",
                "message": "smoke undo",
            },
            headers=headers,
        )
        assert response.status_code == 200, response.text
        assert response.json()["status"] == "undone", response.text
        print("agent action audit: ok")

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
            json={"message": "减脂怎么安排三餐？", "skill": "nutrition"},
            headers=headers,
        )
        assert response.status_code == 200, response.text
        print("coach nutrition skill:", response.json()["reply"][:60])

        response = client.post(
            "/api/v1/coach/chat",
            json={"message": "我训练时胸痛、喘不上气"},
            headers=headers,
        )
        assert response.status_code == 200, response.text
        body = response.json()
        assert body["safety_flag"] == "medical_referral", body
        print("safety:", body["safety_flag"])

        response = client.delete(f"/api/v1/workouts/{workout_id}", headers=headers)
        assert response.status_code == 200, response.text
        response = client.get(f"/api/v1/workouts/{workout_id}", headers=headers)
        assert response.status_code == 404, response.text
        print("workout delete: ok")

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

        now = datetime.now(timezone.utc)
        for client_id, days_ago, weight in (
            ("smoke-body-old", 3, 77.0),
            ("smoke-body-new", 1, 82.0),
            ("smoke-body-late-old", 2, 79.0),
        ):
            response = client.post(
                "/api/v1/body/metrics",
                json={
                    "client_id": client_id,
                    "measured_at": (now - timedelta(days=days_ago)).isoformat(),
                    "weight_kg": weight,
                    "body_fat_pct": 20,
                    "waist_cm": 80,
                },
                headers=headers,
            )
            assert response.status_code == 201, response.text
        me = client.get("/api/v1/me", headers=headers)
        assert me.status_code == 200, me.text
        assert me.json()["profile"]["weight_kg"] == 82.0, me.json()
        response = client.delete(
            "/api/v1/body/metrics/smoke-body-new", headers=headers
        )
        assert response.status_code == 200, response.text
        me = client.get("/api/v1/me", headers=headers)
        assert me.json()["profile"]["weight_kg"] == 79.0, me.json()
        print("body metric ordering: ok")

        response = client.get("/api/v1/me/export", headers=headers)
        assert response.status_code == 200, response.text
        export_data = response.json()
        assert export_data["body_metrics"], export_data
        assert export_data["schedule_states"], export_data
        assert export_data["profile"]["nickname"] == "小林", export_data
        print("user export: ok")

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

        response = client.post("/api/v1/diet/plan", json={}, headers=headers)
        assert response.status_code == 200, response.text
        print("diet idempotent day: ok")

        response = client.get("/api/v1/diet/meituan-link")
        assert response.status_code == 501, response.text
        print("meituan: not configured (expected)")

        # 手机验证码登录：未注册自动建号 + JWT + 刷新 + 退出
        auth_phone = "13800138000"
        response = client.post(
            "/api/v1/auth/phone/send-code",
            json={"phone": auth_phone, "purpose": "login"},
        )
        assert response.status_code == 200, response.text
        auth_code = response.json()["dev_code"]
        response = client.post(
            "/api/v1/auth/phone/login",
            json={
                "phone": auth_phone,
                "code": auth_code,
                "agreed_terms": True,
                "device_name": "smoke-test",
            },
        )
        assert response.status_code == 200, response.text
        auth = response.json()
        assert auth["access_token"] and auth["refresh_token"], auth
        bearer = {"Authorization": f"Bearer {auth['access_token']}"}
        me = client.get("/api/v1/auth/me", headers=bearer)
        assert me.status_code == 200, me.text
        assert me.json()["phone"] == auth_phone
        refreshed = client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": auth["refresh_token"]},
        )
        assert refreshed.status_code == 200, refreshed.text
        bearer = {"Authorization": f"Bearer {refreshed.json()['access_token']}"}
        client.post("/api/v1/auth/logout", headers=bearer)
        assert client.get("/api/v1/auth/me", headers=bearer).status_code == 401
        print("auth phone:", auth_phone, "refresh/logout ok")

        # 账号密码：未注册不能自动创建，必须先验证手机号完成注册
        password_payload = {
            "account": "smoke_user_01",
            "password": "Smoke12345",
            "agreed_terms": True,
            "device_name": "smoke-test",
        }
        first_password_login = client.post(
            "/api/v1/auth/password/login", json=password_payload
        )
        assert first_password_login.status_code == 409, first_password_login.text
        assert first_password_login.json()["error"]["code"] == "REGISTRATION_REQUIRED"
        register_phone = "13900000001"
        register_code = client.post(
            "/api/v1/auth/phone/send-code",
            json={"phone": register_phone, "purpose": "login"},
        )
        assert register_code.status_code == 200, register_code.text
        registration = client.post(
            "/api/v1/auth/password/register",
            json={
                **password_payload,
                "phone": register_phone,
                "code": register_code.json()["dev_code"],
            },
        )
        assert registration.status_code == 200, registration.text
        assert registration.json()["is_new_user"] is True
        second_password_login = client.post(
            "/api/v1/auth/password/login", json=password_payload
        )
        assert second_password_login.status_code == 200, second_password_login.text
        assert second_password_login.json()["is_new_user"] is False
        print("auth password: SMS registration + login ok")

        # 忘记密码：先用手机验证码建立账号，再重置密码
        login_code = client.post(
            "/api/v1/auth/phone/send-code",
            json={"phone": "13900000002", "purpose": "login"},
        )
        assert login_code.status_code == 200, login_code.text
        phone_login = client.post(
            "/api/v1/auth/phone/login",
            json={
                "phone": "13900000002",
                "code": login_code.json()["dev_code"],
                "agreed_terms": True,
                "device_name": "smoke-test",
            },
        )
        assert phone_login.status_code == 200, phone_login.text
        reset_code = client.post(
            "/api/v1/auth/phone/send-code",
            json={"phone": "13900000002", "purpose": "reset_password"},
        )
        assert reset_code.status_code == 200, reset_code.text
        reset = client.post(
            "/api/v1/auth/password/reset",
            json={
                "phone": "13900000002",
                "code": reset_code.json()["dev_code"],
                "password": "NewPass123",
            },
        )
        assert reset.status_code == 200, reset.text
        new_login = client.post(
            "/api/v1/auth/password/login",
            json={
                "account": "13900000002",
                "password": "NewPass123",
                "agreed_terms": True,
                "device_name": "smoke-test",
            },
        )
        assert new_login.status_code == 200, new_login.text
        print("auth password reset: ok")

        # 微信模拟 OAuth：start -> callback -> one-time ticket -> exchange
        start = client.get("/api/v1/auth/oauth/wechat/start")
        assert start.status_code == 200, start.text
        from urllib.parse import parse_qs, urlparse

        state = parse_qs(urlparse(start.json()["authorize_url"]).query)["state"][0]
        callback = client.get(
            f"/api/v1/auth/oauth/wechat/callback?code=mock-wechat-smoke&state={state}",
            follow_redirects=False,
        )
        assert callback.status_code == 302, callback.text
        ticket = parse_qs(urlparse(callback.headers["location"]).query)["ticket"][0]
        social = client.post(
            "/api/v1/auth/oauth/exchange",
            json={"ticket": ticket, "agreed_terms": True, "device_name": "smoke-test"},
        )
        assert social.status_code == 200, social.text
        assert social.json()["access_token"], social.text
        assert social.json()["is_new_user"] is True
        print("auth wechat mock: oauth ticket exchange ok")

    print("\nSMOKE OK")


if __name__ == "__main__":
    main()
