from fastapi import APIRouter, HTTPException
from sqlalchemy import select

from ..deps import DBSession, DEMO_USER_ID
from ..models import Goal, Profile, User
from ..schemas import DevLoginIn
from ..services.serializers import goal_to_dict, profile_to_dict


router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/dev-login")
def dev_login(payload: DevLoginIn, db: DBSession):
    """开发期登录。生产替换为 Sign in with Apple + JWT。"""
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
