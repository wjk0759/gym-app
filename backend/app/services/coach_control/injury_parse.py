"""Structured injury mentions.

The coach used to branch on individual phrases. Parsing clauses into
(part, state) mentions keeps recovery, ongoing pain and new injuries separate.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from ..lexicon import BODY_PART_ALIASES

RECOVERY = re.compile(r"不疼|不痛|好了|康复|没事了|没有伤病|伤好了|恢复了")
ONGOING = re.compile(r"疼|痛|不舒服|难受|发紧|酸|没好|还没好|未好")
NEGATED_PAIN = re.compile(r"不疼|不痛|不难受|没有不舒服|不酸|不发紧")
GLOBAL_CLEAR = re.compile(r"没有伤病|都好了|全好了|伤好了|康复了|恢复了")
EXPLICIT_REPLACE = re.compile(r"改成|改为|更新为|我的伤病是|伤病是")
QUESTION = re.compile(r"怎么办|怎么|为什么|如何|吗|？|\?")
CONTRAST = re.compile(r"但(?:是)?|不过|[，,；;、]")


@dataclass(frozen=True)
class InjuryMention:
    part: str
    state: str  # recovered | ongoing
    text: str


@dataclass(frozen=True)
class InjuryParse:
    mentions: tuple[InjuryMention, ...]
    global_clear: bool
    has_recovery: bool
    explicit_replace: bool
    content: str

    @property
    def ongoing_parts(self) -> list[str]:
        return [item.part for item in self.mentions if item.state == "ongoing"]

    @property
    def recovered_parts(self) -> list[str]:
        return [item.part for item in self.mentions if item.state == "recovered"]


def body_parts(text: str) -> list[str]:
    return [
        part
        for part, aliases in BODY_PART_ALIASES.items()
        if any(alias in text for alias in aliases)
    ]


def injury_text(message: str) -> str:
    value = re.sub(
        r"^(?:请)?(?:帮我)?"
        r"(?:记录一下|记录|记一下|添加|新增|修改|更新|以后|记得|注意)"
        r"[，,。:\s]*",
        "",
        message.strip(),
    )
    value = re.sub(
        r"^(?:我的)?伤病(?:是|为|改成|改为|变成)?[，,。:\s]*",
        "",
        value,
    )
    return value.strip(" ，。!！")


def _active_pain(text: str) -> bool:
    return bool(ONGOING.search(text)) and not bool(
        NEGATED_PAIN.search(text)
    )


def parse_injury_message(message: str) -> InjuryParse:
    if QUESTION.search(message):
        return InjuryParse(
            mentions=(),
            global_clear=False,
            has_recovery=False,
            explicit_replace=False,
            content="",
        )
    parts = body_parts(message)
    has_recovery = bool(RECOVERY.search(message))
    global_clear = bool(GLOBAL_CLEAR.search(message)) and not parts
    mentions: list[InjuryMention] = []
    seen: set[tuple[str, str]] = set()
    for clause in CONTRAST.split(message):
        clause = clause.strip()
        if not clause:
            continue
        clause_parts = body_parts(clause)
        if not clause_parts:
            continue
        recovered = bool(RECOVERY.search(clause))
        ongoing = _active_pain(clause)
        if ongoing:
            state = "ongoing"
        elif recovered:
            state = "recovered"
        else:
            continue
        text = injury_text(clause)
        for part in clause_parts:
            key = (part, state)
            if key in seen:
                continue
            seen.add(key)
            mentions.append(
                InjuryMention(part=part, state=state, text=text)
            )
    return InjuryParse(
        mentions=tuple(mentions),
        global_clear=global_clear,
        has_recovery=has_recovery,
        explicit_replace=bool(EXPLICIT_REPLACE.search(message)),
        content=injury_text(message),
    )
