import uuid
from typing import Annotated

from fastapi import Depends, Header, HTTPException
from sqlalchemy.orm import Session

from .config import settings
from .db import get_db
from .models import User
from .services.auth import check_access_session, decode_access_token

DEMO_USER_ID = "00000000-0000-0000-0000-000000000001"

DBSession = Annotated[Session, Depends(get_db)]


def get_user_id(
    db: DBSession,
    authorization: Annotated[str | None, Header()] = None,
    x_user_id: Annotated[str | None, Header(alias="X-User-Id")] = None,
) -> str:
    """优先 Bearer JWT；开发环境保留 X-User-Id 兼容旧客户端与冒烟测试。"""
    if authorization:
        if not authorization.lower().startswith("bearer "):
            raise HTTPException(status_code=401, detail="Authorization 需使用 Bearer 格式")
        payload = decode_access_token(authorization.split(" ", 1)[1].strip())
        return check_access_session(db, payload)

    if settings.app_env == "dev" and settings.allow_dev_user_header:
        if x_user_id:
            try:
                uuid.UUID(x_user_id)
            except ValueError as exc:
                raise HTTPException(status_code=401, detail="invalid user id") from exc
            user = db.get(User, x_user_id)
            if user is None or user.deleted_at is not None or user.status != "active":
                raise HTTPException(status_code=401, detail="请先登录")
            return user.id
        raise HTTPException(status_code=401, detail="请先登录")

    raise HTTPException(status_code=401, detail="请先登录")


CurrentUser = Annotated[str, Depends(get_user_id)]
