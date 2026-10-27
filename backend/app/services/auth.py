from __future__ import annotations

import base64
import hashlib
import hmac
import html
import secrets
import time
import uuid
from datetime import datetime, timedelta, timezone
from urllib.parse import parse_qs, quote, urlencode

import httpx
import jwt
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..models import (
    AuthEvent,
    AuthSession,
    Goal,
    OAuthTicket,
    Profile,
    SmsCode,
    User,
    utcnow,
)
from .serializers import goal_to_dict, profile_to_dict

PASSWORD_ALGORITHM = "scrypt"
PHONE_LENGTH = 11
_access_rate: dict[str, list[float]] = {}
_sms_rate: dict[str, list[float]] = {}
_apple_jwk_client: jwt.PyJWKClient | None = None


def jwt_secret() -> str:
    secret = settings.jwt_secret
    if secret:
        return secret
    if settings.app_env == "dev":
        return "fitai-dev-jwt-secret-change-before-production"
    raise HTTPException(status_code=503, detail="服务尚未配置 JWT_SECRET")


def normalize_phone(raw: str) -> str:
    value = "".join(ch for ch in raw.strip() if ch.isdigit() or ch == "+")
    if value.startswith("+86"):
        value = value[3:]
    if len(value) != PHONE_LENGTH or not value.startswith("1") or value[1] not in "3456789":
        raise HTTPException(status_code=400, detail="请输入正确的 11 位手机号")
    return value


def normalize_account(raw: str) -> tuple[str, str]:
    """返回 (类型, 值)；类型为 phone/username。"""
    text = raw.strip()
    try:
        return "phone", normalize_phone(text)
    except HTTPException:
        pass
    value = text.lower()
    if not (4 <= len(value) <= 32) or not all(
        ch.isalnum() or ch == "_" for ch in value
    ):
        raise HTTPException(status_code=400, detail="账号需为手机号，或 4–32 位字母、数字、下划线")
    return "username", value


def validate_password(password: str) -> None:
    if len(password) < 8 or len(password) > 72:
        raise HTTPException(status_code=400, detail="密码需为 8–72 位")
    if not any(ch.isalpha() for ch in password) or not any(ch.isdigit() for ch in password):
        raise HTTPException(status_code=400, detail="密码必须同时包含字母和数字")


def hash_password(password: str) -> str:
    validate_password(password)
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(
        password.encode("utf-8"),
        salt=salt,
        n=2**14,
        r=8,
        p=1,
        dklen=64,
    )
    return (
        f"{PASSWORD_ALGORITHM}$16384$8$1$"
        f"{base64.b64encode(salt).decode()}${base64.b64encode(digest).decode()}"
    )


def verify_password(password: str, encoded: str | None) -> bool:
    if not encoded:
        return False
    try:
        algorithm, n, r, p, salt_b64, digest_b64 = encoded.split("$")
        if algorithm != PASSWORD_ALGORITHM:
            return False
        salt = base64.b64decode(salt_b64)
        expected = base64.b64decode(digest_b64)
        actual = hashlib.scrypt(
            password.encode("utf-8"),
            salt=salt,
            n=int(n),
            r=int(r),
            p=int(p),
            dklen=len(expected),
        )
        return hmac.compare_digest(actual, expected)
    except (ValueError, TypeError):
        return False


def _limit(bucket: dict[str, list[float]], key: str, limit: int, window: int) -> bool:
    now = time.monotonic()
    values = [value for value in bucket.get(key, []) if now - value < window]
    if len(values) >= limit:
        bucket[key] = values
        return False
    values.append(now)
    bucket[key] = values
    return True


def check_login_limit(identifier: str) -> None:
    if not _limit(_access_rate, f"login:{identifier}", 10, 15 * 60):
        raise HTTPException(status_code=429, detail="登录尝试过于频繁，请 15 分钟后再试")


def _hash_sms(phone: str, purpose: str, code: str) -> str:
    payload = f"{phone}:{purpose}:{code}:{jwt_secret()}".encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def _refresh_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _access_token(user_id: str, session_id: str) -> tuple[str, int]:
    expires_in = max(60, settings.access_token_minutes * 60)
    now = datetime.now(timezone.utc)
    payload = {
        "sub": user_id,
        "sid": session_id,
        "type": "access",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(seconds=expires_in)).timestamp()),
        "jti": str(uuid.uuid4()),
    }
    token = jwt.encode(payload, jwt_secret(), algorithm="HS256")
    return token, expires_in


def decode_access_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, jwt_secret(), algorithms=["HS256"])
    except jwt.ExpiredSignatureError as exc:
        raise HTTPException(status_code=401, detail="登录已过期，请重新登录") from exc
    except jwt.InvalidTokenError as exc:
        raise HTTPException(status_code=401, detail="登录凭证无效") from exc
    if payload.get("type") != "access":
        raise HTTPException(status_code=401, detail="登录凭证类型不正确")
    return payload


def _event(
    db: Session,
    user_id: str | None,
    event: str,
    method: str,
    success: bool = True,
    request_meta: dict | None = None,
    detail: dict | None = None,
) -> None:
    meta = request_meta or {}
    db.add(
        AuthEvent(
            user_id=user_id,
            event=event,
            method=method,
            success=success,
            ip_address=meta.get("ip"),
            user_agent=meta.get("user_agent"),
            detail=detail or {},
        )
    )


def _ensure_profile(db: Session, user: User, nickname: str = "新用户") -> Profile:
    profile = db.get(Profile, user.id)
    if profile is None:
        profile = Profile(
            user_id=user.id,
            nickname=nickname[:50],
            equipment=["bodyweight"],
        )
        db.add(profile)
        db.flush()
    user.last_login_at = utcnow()
    if not user.status:
        user.status = "active"
    return profile


def _issue_session(
    db: Session,
    user: User,
    method: str,
    request_meta: dict | None = None,
    is_new_user: bool = False,
    nickname: str | None = None,
) -> dict:
    if user.deleted_at is not None or user.status != "active":
        raise HTTPException(status_code=403, detail="账号已被停用")
    profile = _ensure_profile(db, user, nickname or "新用户")
    now = datetime.now(timezone.utc)
    refresh_token = secrets.token_urlsafe(48)
    session = AuthSession(
        user_id=user.id,
        refresh_token_hash=_refresh_hash(refresh_token),
        device_name=(request_meta or {}).get("device_name"),
        ip_address=(request_meta or {}).get("ip"),
        user_agent=(request_meta or {}).get("user_agent"),
        expires_at=now + timedelta(days=max(1, settings.refresh_token_days)),
    )
    db.add(session)
    db.flush()
    access_token, expires_in = _access_token(user.id, session.id)
    _event(db, user.id, "login", method, request_meta=request_meta, detail={"new": is_new_user})
    db.commit()

    goal = db.execute(
        select(Goal).where(
            Goal.user_id == user.id,
            Goal.status == "active",
        )
    ).scalar_one_or_none()
    return {
        "user_id": user.id,
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": expires_in,
        "is_new_user": is_new_user,
        "onboarding_required": profile.onboarded_at is None,
        "profile": profile_to_dict(profile),
        "goal": goal_to_dict(goal),
    }


def _record_failed_login(
    db: Session,
    identifier: str,
    method: str,
    request_meta: dict | None = None,
    detail: dict | None = None,
) -> None:
    _event(db, None, "login_failed", method, False, request_meta, {"identifier": identifier, **(detail or {})})
    db.commit()


def register_or_login_password(
    db: Session,
    account: str,
    password: str,
    request_meta: dict | None = None,
) -> dict:
    check_login_limit(account.lower())
    kind, value = normalize_account(account)
    user = (
        db.execute(select(User).where(User.phone == value)).scalar_one_or_none()
        if kind == "phone"
        else db.execute(select(User).where(User.username == value)).scalar_one_or_none()
    )
    is_new = False
    if user is None:
        validate_password(password)
        nickname = f"用户{value[-4:]}" if kind == "phone" else value
        user = User(
            phone=value if kind == "phone" else None,
            username=value if kind == "username" else None,
            password_hash=hash_password(password),
            status="active",
        )
        db.add(user)
        db.flush()
        is_new = True
    else:
        if user.password_hash is None:
            _record_failed_login(db, value, "password", request_meta, {"reason": "password_not_set"})
            raise HTTPException(
                status_code=409,
                detail="该账号尚未设置密码，请先用手机验证码登录",
            )
        if not verify_password(password, user.password_hash):
            _record_failed_login(db, value, "password", request_meta, {"reason": "bad_password"})
            raise HTTPException(status_code=401, detail="账号或密码不正确")
    return _issue_session(db, user, "password", request_meta, is_new, nickname if is_new else None)


def send_sms_code(
    db: Session,
    phone: str,
    purpose: str = "login",
    request_meta: dict | None = None,
) -> dict:
    phone = normalize_phone(phone)
    if purpose not in {"login", "set_password", "reset_password"}:
        raise HTTPException(status_code=400, detail="验证码用途不正确")
    now = time.monotonic()
    recent = _sms_rate.get(f"resend:{phone}:{purpose}", [])
    recent = [value for value in recent if now - value < 60]
    _sms_rate[f"resend:{phone}:{purpose}"] = recent
    if recent:
        raise HTTPException(status_code=429, detail="验证码 60 秒内只能发送一次")
    if not _limit(_sms_rate, f"hour:{phone}", 5, 3600):
        raise HTTPException(status_code=429, detail="该手机号验证码发送过于频繁，请稍后再试")
    recent.append(now)

    code = f"{secrets.randbelow(1_000_000):06d}"
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
    db.add(
        SmsCode(
            phone=phone,
            purpose=purpose,
            code_hash=_hash_sms(phone, purpose, code),
            expires_at=expires_at,
        )
    )
    db.commit()

    delivery = "dev"
    if settings.sms_provider == "webhook":
        if not settings.sms_webhook_url:
            raise HTTPException(status_code=503, detail="短信网关尚未配置")
        try:
            response = httpx.post(
                settings.sms_webhook_url,
                json={"phone": phone, "code": code, "purpose": purpose, "template": "login_code"},
                headers=(
                    {"Authorization": f"Bearer {settings.sms_webhook_token}"}
                    if settings.sms_webhook_token
                    else {}
                ),
                timeout=8,
            )
            response.raise_for_status()
            delivery = "webhook"
        except httpx.HTTPError as exc:
            raise HTTPException(status_code=502, detail="短信发送失败，请稍后再试") from exc

    result = {
        "ok": True,
        "phone": phone,
        "expires_in": 300,
        "delivery": delivery,
        "message": "验证码已发送",
    }
    if delivery == "dev":
        result["dev_code"] = code
    return result


def _consume_sms_code(db: Session, phone: str, purpose: str, code: str) -> None:
    record = db.execute(
        select(SmsCode)
        .where(
            SmsCode.phone == phone,
            SmsCode.purpose == purpose,
            SmsCode.used_at.is_(None),
        )
        .order_by(SmsCode.created_at.desc())
    ).scalars().first()
    if record is None:
        raise HTTPException(status_code=400, detail="请先获取验证码")
    now = datetime.now(timezone.utc)
    expires = record.expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if expires < now:
        raise HTTPException(status_code=400, detail="验证码已过期，请重新获取")
    if record.attempts >= 5:
        raise HTTPException(status_code=429, detail="验证码错误次数过多，请重新获取")
    if not hmac.compare_digest(record.code_hash, _hash_sms(phone, purpose, code.strip())):
        record.attempts += 1
        db.commit()
        raise HTTPException(status_code=400, detail="验证码不正确")
    record.used_at = now


def login_with_phone(
    db: Session,
    phone: str,
    code: str,
    request_meta: dict | None = None,
) -> dict:
    phone = normalize_phone(phone)
    _consume_sms_code(db, phone, "login", code)

    user = db.execute(select(User).where(User.phone == phone)).scalar_one_or_none()
    is_new = False
    if user is None:
        user = User(phone=phone, status="active")
        db.add(user)
        db.flush()
        is_new = True
    return _issue_session(db, user, "phone_code", request_meta, is_new, f"用户{phone[-4:]}")


def login_with_apple(
    db: Session,
    identity_token: str,
    full_name: str | None = None,
    request_meta: dict | None = None,
) -> dict:
    """Verify an Apple identity token and create/find the local account.

    Apple only sends the display name on the first authorization; later logins
    rely on the stable `sub` claim.
    """
    global _apple_jwk_client

    if not settings.apple_client_id:
        raise HTTPException(status_code=503, detail="Apple 登录未配置 APPLE_CLIENT_ID")

    try:
        if _apple_jwk_client is None:
            _apple_jwk_client = jwt.PyJWKClient(
                "https://appleid.apple.com/auth/keys",
                cache_keys=True,
            )
        signing_key = _apple_jwk_client.get_signing_key_from_jwt(identity_token)
        payload = jwt.decode(
            identity_token,
            signing_key.key,
            algorithms=["RS256"],
            audience=settings.apple_client_id,
            issuer="https://appleid.apple.com",
        )
    except Exception as exc:  # noqa: BLE001 - provider errors must not leak token details
        raise HTTPException(status_code=401, detail="Apple 登录校验失败") from exc

    apple_sub = payload.get("sub")
    if not apple_sub:
        raise HTTPException(status_code=401, detail="Apple 登录凭证缺少用户标识")

    user = db.execute(
        select(User).where(User.apple_sub == apple_sub)
    ).scalar_one_or_none()
    is_new = user is None
    if user is None:
        user = User(apple_sub=apple_sub, status="active")
        db.add(user)
        db.flush()

    nickname = (full_name or "").strip() or "Apple 用户"
    return _issue_session(
        db,
        user,
        "apple",
        request_meta,
        is_new,
        nickname,
    )


def reset_password_with_code(
    db: Session,
    phone: str,
    code: str,
    new_password: str,
) -> dict:
    phone = normalize_phone(phone)
    user = db.execute(select(User).where(User.phone == phone)).scalar_one_or_none()
    if user is None or user.deleted_at is not None:
        raise HTTPException(status_code=404, detail="该手机号尚未注册")
    new_hash = hash_password(new_password)
    _consume_sms_code(db, phone, "reset_password", code)

    user.password_hash = new_hash
    now = datetime.now(timezone.utc)
    for session in db.execute(
        select(AuthSession).where(
            AuthSession.user_id == user.id,
            AuthSession.revoked_at.is_(None),
        )
    ).scalars():
        session.revoked_at = now
    db.add(
        AuthEvent(
            user_id=user.id,
            event="password_reset",
            method="password",
            success=True,
        )
    )
    db.commit()
    return {"ok": True, "message": "密码已重置，请重新登录"}


def refresh_session(
    db: Session,
    refresh_token: str,
    request_meta: dict | None = None,
) -> dict:
    row = db.execute(
        select(AuthSession).where(AuthSession.refresh_token_hash == _refresh_hash(refresh_token))
    ).scalar_one_or_none()
    if row is None:
        raise HTTPException(status_code=401, detail="登录已失效，请重新登录")
    now = datetime.now(timezone.utc)
    expires = row.expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if row.revoked_at is not None or expires < now:
        raise HTTPException(status_code=401, detail="登录已失效，请重新登录")
    user = db.get(User, row.user_id)
    if user is None or user.status != "active" or user.deleted_at is not None:
        raise HTTPException(status_code=403, detail="账号已被停用")
    new_refresh = secrets.token_urlsafe(48)
    row.refresh_token_hash = _refresh_hash(new_refresh)
    row.last_used_at = now
    row.expires_at = now + timedelta(days=max(1, settings.refresh_token_days))
    access_token, expires_in = _access_token(user.id, row.id)
    _event(db, user.id, "refresh", "refresh", request_meta=request_meta)
    db.commit()
    return {
        "user_id": user.id,
        "access_token": access_token,
        "refresh_token": new_refresh,
        "token_type": "bearer",
        "expires_in": expires_in,
    }


def revoke_session(db: Session, session_id: str, user_id: str) -> None:
    row = db.get(AuthSession, session_id)
    if row is not None and row.user_id == user_id and row.revoked_at is None:
        row.revoked_at = utcnow()
        _event(db, user_id, "logout", "logout")
        db.commit()


def check_access_session(db: Session, payload: dict) -> str:
    session_id = payload.get("sid")
    user_id = payload.get("sub")
    if not session_id or not user_id:
        raise HTTPException(status_code=401, detail="登录凭证无效")
    row = db.get(AuthSession, session_id)
    if row is None or row.revoked_at is not None or row.user_id != user_id:
        raise HTTPException(status_code=401, detail="登录已失效，请重新登录")
    user = db.get(User, user_id)
    if user is None or user.deleted_at is not None or user.status != "active":
        raise HTTPException(status_code=403, detail="账号已被停用")
    return user_id


# ---------- OAuth ----------

def provider_configured(provider: str) -> bool:
    if provider == "wechat":
        return bool(settings.wechat_app_id and settings.wechat_app_secret)
    if provider == "qq":
        return bool(settings.qq_app_id and settings.qq_app_secret)
    return False


def oauth_state(provider: str, app_redirect: str, callback_url: str = "") -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "type": "oauth_state",
        "provider": provider,
        "redirect": app_redirect,
        "callback": callback_url,
        "nonce": secrets.token_urlsafe(16),
        "exp": int((now + timedelta(minutes=10)).timestamp()),
    }
    return jwt.encode(payload, jwt_secret(), algorithm="HS256")


def decode_oauth_state(state: str) -> dict:
    try:
        payload = jwt.decode(state, jwt_secret(), algorithms=["HS256"])
    except jwt.InvalidTokenError as exc:
        raise HTTPException(status_code=400, detail="授权状态已失效，请重新登录") from exc
    if payload.get("type") != "oauth_state":
        raise HTTPException(status_code=400, detail="授权状态无效")
    return payload


def authorize_url(
    provider: str,
    state: str,
    callback_url: str,
    public_base: str | None = None,
) -> tuple[str, str]:
    base = (public_base or settings.oauth_callback_base).rstrip("/")
    if provider == "wechat":
        if provider_configured(provider):
            url = (
                "https://open.weixin.qq.com/connect/qrconnect?"
                + urlencode(
                    {
                        "appid": settings.wechat_app_id,
                        "redirect_uri": callback_url,
                        "response_type": "code",
                        "scope": "snsapi_login",
                        "state": state,
                    }
                )
                + "#wechat_redirect"
            )
            return url, "oauth"
        if settings.app_env == "dev":
            return (
                f"{base}/api/v1/auth/oauth/{provider}/mock?"
                + urlencode({"state": state}),
                "mock",
            )
        raise HTTPException(status_code=503, detail="微信登录尚未配置")
    if provider == "qq":
        if provider_configured(provider):
            url = (
                "https://graph.qq.com/oauth2.0/authorize?"
                + urlencode(
                    {
                        "response_type": "code",
                        "client_id": settings.qq_app_id,
                        "redirect_uri": callback_url,
                        "state": state,
                    }
                )
            )
            return url, "oauth"
        if settings.app_env == "dev":
            return (
                f"{base}/api/v1/auth/oauth/{provider}/mock?"
                + urlencode({"state": state}),
                "mock",
            )
        raise HTTPException(status_code=503, detail="QQ 登录尚未配置")
    raise HTTPException(status_code=400, detail="不支持的登录方式")


def mock_provider_html(provider: str, state: str) -> str:
    label = "微信" if provider == "wechat" else "QQ"
    callback = (
        f"{settings.oauth_callback_base}/api/v1/auth/oauth/{provider}/callback?"
        + urlencode({"code": f"mock-{provider}-{uuid.uuid4().hex}", "state": state})
    )
    return f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>模拟{html.escape(label)}登录</title>
<style>
body{{margin:0;min-height:100vh;display:grid;place-items:center;background:#0b1016;color:#fff;font-family:-apple-system,BlinkMacSystemFont,'PingFang SC',sans-serif}}
.card{{width:min(390px,calc(100% - 40px));padding:28px;border-radius:20px;background:#151b24;border:1px solid #2a3544;text-align:center}}
h1{{font-size:22px;margin:0 0 8px}}p{{color:#8b98a9;font-size:13px;line-height:1.6}}
a{{display:block;margin-top:18px;padding:14px;border-radius:12px;background:#5cdb8c;color:#06120a;text-decoration:none;font-weight:700}}
small{{display:block;margin-top:14px;color:#5b6778;font-size:11px}}
</style></head><body><div class="card">
<h1>{html.escape(label)}登录（开发模拟）</h1>
<p>当前未配置 {html.escape(label)} 开放平台密钥。点击下方按钮模拟授权，用于验证完整登录链路。</p>
<a href="{html.escape(callback)}">模拟{html.escape(label)}授权并登录</a>
<small>生产环境配置 WECHAT_APP_ID / WECHAT_APP_SECRET 或 QQ_APP_ID / QQ_APP_SECRET 后会自动切换到真实授权。</small>
</div></body></html>"""


async def exchange_code(
    provider: str,
    code: str,
    redirect_uri: str | None = None,
) -> dict:
    if settings.app_env == "dev" and code.startswith("mock-"):
        suffix = code.split("-")[-1][:12]
        return {
            "openid": f"mock-{provider}-{suffix}",
            "unionid": f"mock-union-{suffix}" if provider == "wechat" else None,
            "nickname": "微信体验用户" if provider == "wechat" else "QQ体验用户",
            "avatar_url": None,
        }
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            if provider == "wechat":
                token_response = await client.get(
                    "https://api.weixin.qq.com/sns/oauth2/access_token",
                    params={
                        "appid": settings.wechat_app_id,
                        "secret": settings.wechat_app_secret,
                        "code": code,
                        "grant_type": "authorization_code",
                    },
                )
                token_data = token_response.json()
                if "openid" not in token_data:
                    raise HTTPException(status_code=401, detail="微信授权失败，请重试")
                user_response = await client.get(
                    "https://api.weixin.qq.com/sns/userinfo",
                    params={
                        "access_token": token_data["access_token"],
                        "openid": token_data["openid"],
                        "lang": "zh_CN",
                    },
                )
                user_data = user_response.json()
                return {
                    "openid": token_data["openid"],
                    "unionid": token_data.get("unionid"),
                    "nickname": user_data.get("nickname") or "微信用户",
                    "avatar_url": user_data.get("headimgurl"),
                }
            if provider == "qq":
                token_response = await client.get(
                    "https://graph.qq.com/oauth2.0/token",
                    params={
                        "grant_type": "authorization_code",
                        "client_id": settings.qq_app_id,
                        "client_secret": settings.qq_app_secret,
                        "code": code,
                        "redirect_uri": redirect_uri or f"{settings.oauth_callback_base}/api/v1/auth/oauth/qq/callback",
                        "fmt": "json",
                    },
                )
                token_text = token_response.text
                try:
                    token_data = token_response.json()
                except ValueError:
                    token_data = {key: values[0] for key, values in parse_qs(token_text).items()}
                if "access_token" not in token_data:
                    raise HTTPException(status_code=401, detail="QQ 授权失败，请重试")
                me_response = await client.get(
                    "https://graph.qq.com/oauth2.0/me",
                    params={"access_token": token_data["access_token"], "fmt": "json"},
                )
                me_text = me_response.text.strip()
                if me_text.startswith("callback("):
                    me_text = me_text[len("callback("):-2]
                me_data = __import__("json").loads(me_text)
                openid = me_data.get("openid")
                if not openid:
                    raise HTTPException(status_code=401, detail="QQ 授权失败，请重试")
                return {
                    "openid": openid,
                    "unionid": None,
                    "nickname": "QQ用户",
                    "avatar_url": None,
                }
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail="第三方登录服务暂时不可用") from exc
    raise HTTPException(status_code=400, detail="不支持的登录方式")


def find_or_create_social_user(
    db: Session,
    provider: str,
    profile_data: dict,
) -> tuple[User, bool]:
    openid = profile_data["openid"]
    unionid = profile_data.get("unionid")
    user = None
    if provider == "wechat":
        user = db.execute(
            select(User).where(User.wechat_openid == openid)
        ).scalar_one_or_none()
        if user is None and unionid:
            user = db.execute(
                select(User).where(User.wechat_unionid == unionid)
            ).scalar_one_or_none()
    elif provider == "qq":
        user = db.execute(
            select(User).where(User.qq_openid == openid)
        ).scalar_one_or_none()
    if user is None:
        nickname = profile_data.get("nickname") or ("微信用户" if provider == "wechat" else "QQ用户")
        user = User(
            wechat_openid=openid if provider == "wechat" else None,
            wechat_unionid=unionid if provider == "wechat" else None,
            qq_openid=openid if provider == "qq" else None,
            avatar_url=profile_data.get("avatar_url"),
            status="active",
        )
        db.add(user)
        db.flush()
        profile = Profile(
            user_id=user.id,
            nickname=nickname[:50],
            equipment=["bodyweight"],
        )
        db.add(profile)
        db.flush()
        return user, True
    if provider == "wechat":
        if not user.wechat_openid:
            user.wechat_openid = openid
        if unionid and not user.wechat_unionid:
            user.wechat_unionid = unionid
    elif provider == "qq":
        if not user.qq_openid:
            user.qq_openid = openid
    if profile_data.get("avatar_url") and not user.avatar_url:
        user.avatar_url = profile_data["avatar_url"]
    db.flush()
    return user, False


def create_oauth_ticket(
    db: Session,
    user: User,
    provider: str,
    is_new_user: bool = False,
) -> str:
    ticket = OAuthTicket(
        user_id=user.id,
        provider=provider,
        is_new_user=is_new_user,
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=5),
    )
    db.add(ticket)
    db.commit()
    return ticket.id


def exchange_oauth_ticket(
    db: Session,
    ticket_id: str,
    request_meta: dict | None = None,
) -> dict:
    ticket = db.get(OAuthTicket, ticket_id)
    if ticket is None or ticket.used_at is not None:
        raise HTTPException(status_code=400, detail="授权凭证无效或已使用")
    expires = ticket.expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if expires < datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="授权凭证已过期")
    ticket.used_at = utcnow()
    user = db.get(User, ticket.user_id)
    if user is None:
        raise HTTPException(status_code=400, detail="用户不存在")
    db.commit()
    return _issue_session(
        db,
        user,
        f"{ticket.provider}_oauth",
        request_meta,
        ticket.is_new_user,
    )


def social_login_code(
    db: Session,
    provider: str,
    code: str,
    request_meta: dict | None = None,
) -> dict:
    if provider not in {"wechat", "qq"}:
        raise HTTPException(status_code=400, detail="不支持的登录方式")
    import asyncio

    profile_data = asyncio.run(exchange_code(provider, code))
    user, is_new = find_or_create_social_user(db, provider, profile_data)
    return _issue_session(db, user, f"{provider}_oauth", request_meta, is_new)
