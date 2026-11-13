from __future__ import annotations

from datetime import date as dt_date
from typing import Literal

from pydantic import BaseModel, Field


class FoodItemIn(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    portion: str | None = Field(default=None, max_length=40)
    grams: float = Field(ge=0, le=5000)
    kcal: float = Field(ge=0, le=10000)
    protein_g: float = Field(ge=0, le=1000)
    carbs_g: float = Field(ge=0, le=1000)
    fat_g: float = Field(ge=0, le=1000)
    fiber_g: float = Field(default=0, ge=0, le=1000)
    confidence: float | None = Field(default=None, ge=0, le=1)


class LogFoodPayload(BaseModel):
    date: dt_date
    meal: Literal["breakfast", "lunch", "dinner", "snack"]
    raw_text: str | None = Field(default=None, max_length=500)
    items: list[FoodItemIn] = Field(min_length=1, max_length=20)


class LogPlannedMealPayload(BaseModel):
    date: dt_date
    meal: Literal["breakfast", "lunch", "dinner", "snack"]


class UpdateFoodLogPayload(BaseModel):
    client_id: str = Field(min_length=1, max_length=36)
    date: dt_date | None = None
    meal: Literal["breakfast", "lunch", "dinner", "snack"] | None = None
    food_name: str | None = Field(default=None, min_length=1, max_length=120)
    grams: float | None = Field(default=None, ge=0, le=5000)
    kcal: float | None = Field(default=None, ge=0, le=10000)
    protein_g: float | None = Field(default=None, ge=0, le=1000)
    carbs_g: float | None = Field(default=None, ge=0, le=1000)
    fat_g: float | None = Field(default=None, ge=0, le=1000)
    fiber_g: float | None = Field(default=None, ge=0, le=1000)


class DeleteFoodLogPayload(BaseModel):
    client_id: str = Field(min_length=1, max_length=36)


class WorkoutSetIn(BaseModel):
    slug: str = Field(min_length=1, max_length=60)
    set_index: int | None = Field(default=None, ge=1, le=100)
    weight_kg: float = Field(default=0, ge=0, le=1000)
    reps: int = Field(default=0, ge=0, le=200)
    rpe: float = Field(default=7, ge=1, le=10)
    completed: bool = True


class LogWorkoutPayload(BaseModel):
    date: dt_date
    title: str = Field(min_length=1, max_length=80)
    duration_minutes: int = Field(ge=1, le=300)
    kind: Literal["strength", "cardio"] = "strength"
    notes: str | None = Field(default=None, max_length=500)
    program_day_id: str | None = Field(default=None, max_length=36)
    sets: list[WorkoutSetIn] = Field(default_factory=list, max_length=100)


class UpdateWorkoutPayload(BaseModel):
    session_id: str = Field(min_length=1, max_length=36)
    date: dt_date | None = None
    duration_minutes: int | None = Field(default=None, ge=1, le=300)
    notes: str | None = Field(default=None, max_length=500)
    sets: list[WorkoutSetIn] | None = Field(default=None, max_length=100)


class DeleteWorkoutPayload(BaseModel):
    session_id: str = Field(min_length=1, max_length=36)
