from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Type

from pydantic import BaseModel


@dataclass(frozen=True)
class ActionSpec:
    payload_model: Type[BaseModel]
    execute: Callable
    undo: Callable | None = None
    permission: str | None = None


REGISTRY: dict[str, ActionSpec] = {}


def register(action_type: str, spec: ActionSpec) -> None:
    REGISTRY[action_type] = spec
