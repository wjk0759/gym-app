"""Coach control plane: sessions, capabilities, actions and events."""

from .registry import CAPABILITIES, Capability, register

__all__ = ["CAPABILITIES", "Capability", "register"]
