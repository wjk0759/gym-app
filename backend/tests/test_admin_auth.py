import time

import jwt
import pytest
from fastapi import HTTPException
from starlette.requests import Request

from app.config import settings
from app.routers.admin import _admin_permission, require_admin


def test_admin_permission_mapping():
    assert _admin_permission("GET", "/api/v1/admin/users") == "user:read"
    assert _admin_permission("DELETE", "/api/v1/admin/users/x") == "user:write"
    assert _admin_permission("GET", "/api/v1/admin/programs") == "plan:read"
    assert _admin_permission("POST", "/api/v1/admin/programs/x/activate") == "plan:write"
    assert _admin_permission("GET", "/api/v1/admin/ai/overview") == "ai:read"
    assert _admin_permission("GET", "/api/v1/admin/audit") == "audit:read"
    assert _admin_permission("GET", "/api/v1/admin/auth/check") is None


def _request(path: str) -> Request:
    return Request(
        {
            "type": "http",
            "method": "GET",
            "path": path,
            "headers": [],
        }
    )


def _token(perms: list[str], secret: str, issuer: str) -> str:
    return jwt.encode(
        {
            "sub": "admin-1",
            "username": "alice",
            "typ": "access",
            "iss": issuer,
            "exp": int(time.time()) + 60,
            "perms": perms,
        },
        secret,
        algorithm="HS256",
    )


def test_admin_jwt_verification_and_permission(monkeypatch):
    secret = "test-admin-jwt-secret-at-least-32-bytes"
    monkeypatch.setattr(settings, "admin_jwt_secret", secret)
    monkeypatch.setattr(settings, "admin_jwt_issuer", "fitai-admin")

    actor = require_admin(
        _request("/api/v1/admin/stats"),
        authorization=f"Bearer {_token(['dashboard:read'], secret, 'fitai-admin')}",
    )
    assert actor == "alice"

    with pytest.raises(HTTPException) as exc:
        require_admin(
            _request("/api/v1/admin/users"),
            authorization=f"Bearer {_token(['dashboard:read'], secret, 'fitai-admin')}",
        )
    assert exc.value.status_code == 403
