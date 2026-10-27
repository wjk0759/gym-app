from __future__ import annotations

from datetime import date
from datetime import date as dt_date
from typing import Literal

from pydantic import BaseModel, Field

Sex = Literal["male", "female", "other"]
Experience = Literal["beginner", "intermediate", "advanced"]
GoalType = Literal["lose_fat", "build_muscle", "recomp", "endurance"]
EquipmentType = Literal[
    "bodyweight", "dumbbell", "barbell", "machine", "cable", "band", "kettlebell"
]


class DevLoginIn(BaseModel):
    nickname: str = Field(default="体验用户", max_length=50)


class SmsSendIn(BaseModel):
    phone: str = Field(min_length=11, max_length=20)
    purpose: Literal["login", "set_password", "reset_password"] = "login"


class PhoneLoginIn(BaseModel):
    phone: str = Field(min_length=11, max_length=20)
    code: str = Field(min_length=4, max_length=8)
    device_name: str | None = Field(default=None, max_length=120)
    agreed_terms: bool = False


class PasswordLoginIn(BaseModel):
    account: str = Field(min_length=4, max_length=50)
    password: str = Field(min_length=8, max_length=72)
    device_name: str | None = Field(default=None, max_length=120)
    agreed_terms: bool = False


class RefreshIn(BaseModel):
    refresh_token: str = Field(min_length=20, max_length=200)
    device_name: str | None = Field(default=None, max_length=120)


class OAuthExchangeIn(BaseModel):
    ticket: str = Field(min_length=10, max_length=200)
    device_name: str | None = Field(default=None, max_length=120)
    agreed_terms: bool = False


class OAuthCodeIn(BaseModel):
    code: str = Field(min_length=2, max_length=500)
    redirect_uri: str | None = Field(default=None, max_length=500)
    device_name: str | None = Field(default=None, max_length=120)
    agreed_terms: bool = False


class AppleLoginIn(BaseModel):
    identity_token: str = Field(min_length=20, max_length=5000)
    full_name: str | None = Field(default=None, max_length=80)
    device_name: str | None = Field(default=None, max_length=120)
    agreed_terms: bool = False


class PasswordSetIn(BaseModel):
    password: str = Field(min_length=8, max_length=72)


class PasswordResetIn(BaseModel):
    phone: str = Field(min_length=11, max_length=20)
    code: str = Field(min_length=4, max_length=8)
    password: str = Field(min_length=8, max_length=72)


class ProfileIn(BaseModel):
    nickname: str = Field(default="", max_length=50)
    sex: Sex = "male"
    birth_date: date | None = None
    height_cm: float | None = Field(default=None, ge=100, le=250)
    weight_kg: float | None = Field(default=None, ge=25, le=300)
    body_fat_pct: float | None = Field(default=None, ge=3, le=60)
    chest_cm: float | None = Field(default=None, ge=30, le=200)
    waist_cm: float | None = Field(default=None, ge=30, le=200)
    hip_cm: float | None = Field(default=None, ge=30, le=200)
    experience: Experience = "beginner"
    injuries: list[str] = Field(default_factory=list)
    equipment: list[EquipmentType] = Field(default_factory=lambda: ["bodyweight"])
    weekly_days: int = Field(default=3, ge=1, le=7)
    session_minutes: int = Field(default=45, ge=15, le=180)


class GoalIn(BaseModel):
    type: GoalType = "recomp"
    target_weight_kg: float | None = Field(default=None, ge=25, le=300)
    target_body_fat_pct: float | None = Field(default=None, ge=3, le=60)
    target_waist_cm: float | None = Field(default=None, ge=30, le=200)
    target_date: date | None = None


class PlanGenerateIn(BaseModel):
    force: bool = False
    equipment_slugs: list[str] = Field(default_factory=list, max_length=50)
    split: str | None = Field(default=None, max_length=20)


class PlanExercisePatch(BaseModel):
    slug: str
    sets: int = Field(default=3, ge=1, le=10)
    reps: str = Field(default="10", max_length=20)
    weight_kg: float | None = Field(default=None, ge=0, le=500)
    rest_sec: int = Field(default=60, ge=0, le=600)
    rpe: float | None = Field(default=None, ge=1, le=10)


class PlanDayPatch(BaseModel):
    exercises: list[PlanExercisePatch] = Field(min_length=1, max_length=12)


class SetIn(BaseModel):
    slug: str
    set_index: int = Field(ge=1, le=20)
    weight_kg: float | None = Field(default=None, ge=0, le=500)
    reps: int | None = Field(default=None, ge=0, le=100)
    rpe: float | None = Field(default=None, ge=1, le=10)
    completed: bool = True


class WorkoutIn(BaseModel):
    program_day_id: str | None = None
    started_at: str
    finished_at: str | None = None
    feeling: int | None = Field(default=None, ge=1, le=5)
    notes: str | None = Field(default=None, max_length=1000)
    sets: list[SetIn] = Field(default_factory=list, max_length=200)


class ChatIn(BaseModel):
    session_id: str | None = None
    message: str = Field(min_length=1, max_length=2000)
    skill: Literal["trainer", "rehab", "nutrition"] = "trainer"


class DietPlanIn(BaseModel):
    date: dt_date | None = None
