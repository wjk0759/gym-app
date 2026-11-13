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
