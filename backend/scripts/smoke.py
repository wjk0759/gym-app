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

        # 账号密码：首次登录自动注册
        password_payload = {
            "account": "smoke_user_01",
            "password": "Smoke12345",
            "agreed_terms": True,
            "device_name": "smoke-test",
        }
        first_password_login = client.post(
            "/api/v1/auth/password/login", json=password_payload
        )
        assert first_password_login.status_code == 200, first_password_login.text
        assert first_password_login.json()["is_new_user"] is True
        second_password_login = client.post(
            "/api/v1/auth/password/login", json=password_payload
        )
        assert second_password_login.status_code == 200, second_password_login.text
        assert second_password_login.json()["is_new_user"] is False
        print("auth password: auto-register + login ok")

        # 忘记密码：短信校验后重置密码，旧会话失效，新密码可登录
        client.post(
            "/api/v1/auth/password/login",
            json={
                "account": "13900000002",
                "password": "OldPass123",
                "agreed_terms": True,
                "device_name": "smoke-test",
            },
        )
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

        admin_headers = {"X-Admin-Token": "dev-admin-token"}
        assert client.get("/api/v1/admin/stats").status_code == 401
        assert client.get(
            "/api/v1/admin/stats", headers={"X-Admin-Token": "wrong"}
        ).status_code == 401
        response = client.get("/api/v1/admin/stats", headers=admin_headers)
        assert response.status_code == 200, response.text
        admin_stats = response.json()
        assert admin_stats["users_total"] >= 1, admin_stats
        print("admin stats:", admin_stats["users_total"], "users,", admin_stats["sessions_total"], "sessions")

        ai_overview = client.get("/api/v1/admin/ai/overview?days=30", headers=admin_headers)
        assert ai_overview.status_code == 200, ai_overview.text
        assert len(ai_overview.json()["skills"]) == 3
        ai_jobs = client.get("/api/v1/admin/ai/jobs", headers=admin_headers)
        assert ai_jobs.status_code == 200, ai_jobs.text
        print("admin ai usage:", ai_overview.json()["total"], "calls")

        response = client.get("/api/v1/admin/users", headers=admin_headers)
        assert response.status_code == 200, response.text
        assert response.json()["items"], response.text
        print("admin users:", len(response.json()["items"]))

        response = client.get(
            f"/api/v1/admin/users/{user_id}",
            headers=admin_headers,
        )
        assert response.status_code == 200, response.text
        assert response.json()["profile"]["nickname"] == "小林"
        print("admin user detail:", response.json()["profile"]["nickname"])

        response = client.get("/api/v1/admin/exercises?q=深蹲", headers=admin_headers)
        assert response.status_code == 200, response.text
        exercise_items = response.json()["items"]
        assert exercise_items, response.text
        exercise_slug = exercise_items[0]["slug"]
        response = client.patch(
            f"/api/v1/admin/exercises/{exercise_slug}",
            json={"instructions": exercise_items[0]["instructions"] or "admin smoke"},
            headers=admin_headers,
        )
        assert response.status_code == 200, response.text
        print("admin exercise edit:", exercise_slug)

        upload = client.post(
            "/api/v1/admin/videos/upload",
            headers=admin_headers,
            data={"kind": "video"},
            files={"file": ("smoke.mp4", b"smoke-video-bytes", "video/mp4")},
        )
        assert upload.status_code == 200, upload.text
        created_video = client.post(
            "/api/v1/admin/videos",
            headers=admin_headers,
            json={
                "exercise_slug": exercise_slug,
                "title": "冒烟测试教学视频",
                "video_url": upload.json()["url"],
                "source": "smoke",
                "license_note": "内部测试",
                "status": "draft",
            },
        )
        assert created_video.status_code == 200, created_video.text
        video = created_video.json()
        published = client.post(
            f"/api/v1/admin/videos/{video['id']}/publish",
            headers=admin_headers,
        )
        assert published.status_code == 200, published.text
        public_video = client.get(f"/api/v1/videos/{exercise_slug}")
        assert public_video.status_code == 200, public_video.text
        assert public_video.json()["video"]["title"] == "冒烟测试教学视频"
        deleted = client.delete(
            f"/api/v1/admin/videos/{video['id']}",
            headers=admin_headers,
        )
        assert deleted.status_code == 200, deleted.text
        print("admin video upload/publish/delete: ok")

        response = client.get(
            f"/api/v1/admin/users/{user_id}/export",
            headers=admin_headers,
        )
        assert response.status_code == 200, response.text
        assert response.json()["user"]["id"] == user_id
        print("admin export: ok")

        response = client.get("/api/v1/admin/audit", headers=admin_headers)
        assert response.status_code == 200, response.text
        assert response.json()["items"], response.text
        print("admin audit:", len(response.json()["items"]), "entries")

        response = client.get("/admin")
        assert response.status_code == 200, response.text
        assert "FitAI 数据后台" in response.text
        print("admin console: ok")

    print("\nSMOKE OK")


if __name__ == "__main__":
    main()
