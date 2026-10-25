from __future__ import annotations

from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Header, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy import select

from ..config import settings
from ..deps import DBSession, DEMO_USER_ID, CurrentUser
from ..models import AuthEvent, AuthSession, Goal, Profile, User
from ..schemas import (
    DevLoginIn,
    OAuthCodeIn,
    OAuthExchangeIn,
    PasswordLoginIn,
    PasswordSetIn,
    PhoneLoginIn,
    RefreshIn,
    SmsSendIn,
)
from ..services import auth as auth_service
from ..services.serializers import goal_to_dict, profile_to_dict

router = APIRouter(prefix="/auth", tags=["auth"])


def _meta(request: Request, device_name: str | None = None) -> dict:
    return {
        "ip": request.client.host if request.client else None,
        "user_agent": request.headers.get("user-agent"),
        "device_name": device_name,
    }


def _require_terms(agreed: bool) -> None:
    if not agreed:
        raise HTTPException(status_code=400, detail="请先阅读并同意用户协议与隐私政策")


def _bearer_payload(authorization: Annotated[str | None, Header()] = None) -> dict:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="请先登录")
    return auth_service.decode_access_token(authorization.split(" ", 1)[1].strip())


def _auth_me(db: DBSession, user_id: str) -> dict:
    user = db.get(User, user_id)
    if user is None or user.deleted_at is not None or user.status != "active":
        raise HTTPException(status_code=403, detail="账号已被停用")
    profile = db.get(Profile, user_id)
    goal = db.execute(
        select(Goal).where(Goal.user_id == user_id, Goal.status == "active")
    ).scalar_one_or_none()
    return {
        "user_id": user.id,
        "phone": user.phone,
        "username": user.username,
        "status": user.status,
        "last_login_at": (
            user.last_login_at.isoformat() if user.last_login_at else None
        ),
        "profile": profile_to_dict(profile) if profile else None,
        "goal": goal_to_dict(goal),
        "onboarding_required": profile is None or profile.onboarded_at is None,
        "auth_methods": {
            "phone": bool(user.phone),
            "password": bool(user.password_hash),
            "wechat": bool(user.wechat_openid),
            "qq": bool(user.qq_openid),
        },
    }


@router.post("/phone/send-code")
def send_phone_code(payload: SmsSendIn, request: Request, db: DBSession):
    return auth_service.send_sms_code(
        db,
        payload.phone,
        payload.purpose,
        _meta(request),
    )


@router.post("/phone/login")
def phone_login(payload: PhoneLoginIn, request: Request, db: DBSession):
    _require_terms(payload.agreed_terms)
    return auth_service.login_with_phone(
        db,
        payload.phone,
        payload.code,
        _meta(request, payload.device_name),
    )


@router.post("/password/login")
def password_login(payload: PasswordLoginIn, request: Request, db: DBSession):
    _require_terms(payload.agreed_terms)
    return auth_service.register_or_login_password(
        db,
        payload.account,
        payload.password,
        _meta(request, payload.device_name),
    )


@router.post("/password/set")
def set_password(
    payload: PasswordSetIn,
    user_id: CurrentUser,
    db: DBSession,
):
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="用户不存在")
    user.password_hash = auth_service.hash_password(payload.password)
    db.add(
        AuthEvent(
            user_id=user_id,
            event="password_set",
            method="password",
            success=True,
        )
    )
    db.commit()
    return {"ok": True}


@router.post("/refresh")
def refresh(payload: RefreshIn, request: Request, db: DBSession):
    return auth_service.refresh_session(
        db,
        payload.refresh_token,
        _meta(request, payload.device_name),
    )


@router.get("/me")
def me(user_id: CurrentUser, db: DBSession):
    return _auth_me(db, user_id)


@router.post("/logout")
def logout(
    db: DBSession,
    authorization: Annotated[str | None, Header()] = None,
):
    token_payload = _bearer_payload(authorization)
    auth_service.revoke_session(db, token_payload["sid"], token_payload["sub"])
    return {"ok": True}


@router.get("/sessions")
def sessions(user_id: CurrentUser, db: DBSession):
    rows = db.execute(
        select(AuthSession)
        .where(AuthSession.user_id == user_id)
        .order_by(AuthSession.last_used_at.desc())
    ).scalars().all()
    now = datetime.now(timezone.utc)
    return {
        "items": [
            {
                "id": row.id,
                "device_name": row.device_name,
                "ip_address": row.ip_address,
                "created_at": row.created_at.isoformat(),
                "last_used_at": row.last_used_at.isoformat(),
                "expires_at": row.expires_at.isoformat(),
                "revoked": row.revoked_at is not None or (
                    row.expires_at.replace(tzinfo=timezone.utc)
                    if row.expires_at.tzinfo is None
                    else row.expires_at
                ) < now,
            }
            for row in rows
        ]
    }


@router.delete("/sessions/{session_id}")
def revoke_other_session(
    session_id: str,
    user_id: CurrentUser,
    db: DBSession,
):
    row = db.get(AuthSession, session_id)
    if row is None or row.user_id != user_id:
        raise HTTPException(status_code=404, detail="会话不存在")
    row.revoked_at = datetime.now(timezone.utc)
    db.commit()
    return {"ok": True}


@router.get("/oauth/{provider}/start")
def oauth_start(provider: str, request: Request):
    if provider not in {"wechat", "qq"}:
        raise HTTPException(status_code=400, detail="不支持的登录方式")
    app_redirect = f"{settings.app_callback_scheme}://auth/callback"
    state = auth_service.oauth_state(provider, app_redirect)
    public_base = settings.oauth_callback_base.rstrip("/") or str(request.base_url).rstrip("/")
    callback_url = (
        f"{public_base}/api/v1/auth/oauth/{provider}/callback"
    )
    url, mode = auth_service.authorize_url(provider, state, callback_url, public_base)
    return {
        "authorize_url": url,
        "mode": mode,
        "provider": provider,
        "callback_scheme": app_redirect,
    }


@router.get("/oauth/{provider}/mock", response_class=HTMLResponse)
def oauth_mock(provider: str, state: str):
    if settings.app_env != "dev":
        raise HTTPException(status_code=404, detail="Not Found")
    auth_service.decode_oauth_state(state)
    return HTMLResponse(auth_service.mock_provider_html(provider, state))


@router.get("/oauth/{provider}/callback")
async def oauth_callback(
    provider: str,
    code: str,
    state: str,
    request: Request,
    db: DBSession,
):
    state_data = auth_service.decode_oauth_state(state)
    if state_data.get("provider") != provider:
        raise HTTPException(status_code=400, detail="授权状态不匹配")
    profile_data = await auth_service.exchange_code(provider, code)
    user, is_new = auth_service.find_or_create_social_user(db, provider, profile_data)
    ticket = auth_service.create_oauth_ticket(db, user, provider, is_new)
    redirect = (
        f"{settings.app_callback_scheme}://auth/callback?"
        f"ticket={ticket}&provider={provider}"
    )
    return RedirectResponse(url=redirect, status_code=302)


@router.post("/oauth/{provider}/login")
async def oauth_login_code(
    provider: str,
    payload: OAuthCodeIn,
    request: Request,
    db: DBSession,
):
    _require_terms(payload.agreed_terms)
    if provider not in {"wechat", "qq"}:
        raise HTTPException(status_code=400, detail="不支持的登录方式")
    profile_data = await auth_service.exchange_code(provider, payload.code)
    user, is_new = auth_service.find_or_create_social_user(db, provider, profile_data)
    return auth_service._issue_session(
        db,
        user,
        f"{provider}_oauth",
        _meta(request, payload.device_name),
        is_new,
    )


@router.post("/oauth/exchange")
def oauth_exchange(
    payload: OAuthExchangeIn,
    request: Request,
    db: DBSession,
):
    _require_terms(payload.agreed_terms)
    return auth_service.exchange_oauth_ticket(
        db,
        payload.ticket,
        _meta(request, payload.device_name),
    )


@router.post("/dev-login")
def dev_login(payload: DevLoginIn, request: Request, db: DBSession):
    """仅开发使用：保留 X-User-Id 兼容现有冒烟测试。"""
    if settings.app_env != "dev":
        raise HTTPException(status_code=404, detail="Not Found")
    user = db.get(User, DEMO_USER_ID)
    if user is None:
        user = User(id=DEMO_USER_ID)
        db.add(user)
        db.commit()

    profile = db.get(Profile, DEMO_USER_ID)
    if profile is None:
        profile = Profile(user_id=DEMO_USER_ID, nickname=payload.nickname or "体验用户")
        db.add(profile)
        db.commit()

    goal = db.execute(
        select(Goal).where(Goal.user_id == DEMO_USER_ID, Goal.status == "active")
    ).scalar_one_or_none()

    return {
        "user_id": user.id,
        "access_token": f"dev-{user.id}",
        "expires_in": 86400,
        "profile": profile_to_dict(profile),
        "goal": goal_to_dict(goal),
    }
