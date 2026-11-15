"""Typed capability registry.

The model chooses a capability; the server owns its payload, validation,
confirmation, idempotency, undo and events. New coach features register here
instead of adding another branch to ``agent.py``.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Capability:
    id: str
    domain: str
    kind: str
    title: str
    description: str
    requires_confirmation: bool = True
    undo: bool = True
    events: tuple[str, ...] = ()
    refreshes: tuple[str, ...] = ()


CAPABILITIES: dict[str, Capability] = {}


def register(capability: Capability) -> Capability:
    if capability.id in CAPABILITIES:
        raise ValueError(f"duplicate capability: {capability.id}")
    CAPABILITIES[capability.id] = capability
    return capability


def capability_payloads() -> list[dict]:
    from .manifest import spec_for

    items = []
    for item in CAPABILITIES.values():
        spec = spec_for(item.id)
        items.append(
            {
                "id": item.id,
                "domain": item.domain,
                "kind": item.kind,
                "title": item.title,
                "description": item.description,
                "requires_confirmation": item.requires_confirmation,
                "undo": item.undo,
                "events": list(item.events),
                "refreshes": list(item.refreshes),
                "examples": list(spec.examples) if spec else [],
                "slots": list(spec.slots) if spec else [],
                "card": spec.card if spec else "generic",
            }
        )
    return items
