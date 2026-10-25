from typing import Annotated

from fastapi import Depends, Header, HTTPException
from sqlalchemy.orm import Session

from .db import get_db

DEMO_USER_ID = "00000000-0000-0000-0000-000000000001"

DBSession = Annotated[Session, Depends(get_db)]


def get_user_id(
    x_user_id: Annotated[str | None, Header(alias="X-User-Id")] = None,
) -> str:
    """开发期鉴权：优先使用 X-User-Id，否则落到 demo 用户。

    生产替换为 JWT 校验，并从 token 中取 user_id。
    """
    if not x_user_id:
        return DEMO_USER_ID
    if len(x_user_id) > 64:
        raise HTTPException(status_code=401, detail="invalid user id")
    return x_user_id


CurrentUser = Annotated[str, Depends(get_user_id)]
