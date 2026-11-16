"""Typed schema for generated diet plans.

The API keeps returning plain dicts, but generation and tests validate against
this schema so nested fields cannot silently drift. Extra fields are allowed
for forward compatibility; the invariant is enforced by ``diet_preferences``.
"""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class DietRecipe(BaseModel):
    model_config = ConfigDict(extra="allow")

    title: str | None = None
    ingredients: list[str] = Field(default_factory=list)
    steps: list[str] = Field(default_factory=list)
    tip: str | None = None


class DietDish(BaseModel):
    model_config = ConfigDict(extra="allow")

    name: str | None = None
    items: list[str] = Field(default_factory=list)
    recipe: DietRecipe | None = None


class DietMeal(BaseModel):
    model_config = ConfigDict(extra="allow")

    meal: str | None = None
    name: str | None = None
    kcal: float | None = None
    protein_g: float | None = None
    carbs_g: float | None = None
    fat_g: float | None = None
    items: list[str] = Field(default_factory=list)
    dishes: list[DietDish] | None = None


class DietTargets(BaseModel):
    model_config = ConfigDict(extra="allow")

    bmr_kcal: float | None = None
    tdee_kcal: float | None = None
    target_kcal: float | None = None
    protein_g: float | None = None
    carb_g: float | None = None
    fat_g: float | None = None
    note: str | None = None


class DietDay(BaseModel):
    model_config = ConfigDict(extra="allow")

    date: str | None = None
    weekday: int | None = None
    day_type: str | None = None
    day_type_label: str | None = None
    title: str | None = None
    targets: DietTargets | None = None
    meals: list[DietMeal] = Field(default_factory=list)


class DietStrategy(BaseModel):
    model_config = ConfigDict(extra="allow")

    id: str | None = None
    label: str | None = None
    description: str | None = None
    caution: str | None = None


class DietPlan(BaseModel):
    model_config = ConfigDict(extra="allow")

    date: str | None = None
    week_start: str | None = None
    strategy: DietStrategy | None = None
    targets: DietTargets | None = None
    meals: list[DietMeal] | None = None
    days: list[DietDay] | None = None
    total_kcal: float | None = None
    total_protein_g: float | None = None
    total_carbs_g: float | None = None
    total_fat_g: float | None = None
    tips: list[str] = Field(default_factory=list)
    note: str | None = None
    disclaimer: str | None = None
    generated_by: str | None = None
    model: str | None = None
    warning: str | None = None
    training_days: list[int] = Field(default_factory=list)


def validate_diet_plan(plan: dict[str, Any]) -> DietPlan:
    return DietPlan.model_validate(plan)
