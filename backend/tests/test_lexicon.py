from pathlib import Path

from app.services.lexicon import (
    BODY_PART_ALIASES,
    EQUIPMENT_ALIASES,
    MEAL_ALIASES,
    MEAL_LABELS,
    MEAL_ORDER,
)

APP_ROOT = Path(__file__).resolve().parents[1] / "app"
LEXICON = APP_ROOT / "services" / "lexicon.py"
FORBIDDEN = (
    "MEAL_LABELS =",
    "MEAL_PATTERNS =",
    "MEAL_ALIASES =",
    "EQUIPMENT_LABELS =",
    "EQUIPMENT_ALIASES =",
    "BODY_PART_ALIASES =",
    "INJURY_BODY_PARTS =",
)


def test_domain_vocabulary_has_one_definition():
    duplicates: list[str] = []
    for path in APP_ROOT.rglob("*.py"):
        if path == LEXICON:
            continue
        text = path.read_text(encoding="utf-8")
        for marker in FORBIDDEN:
            if marker in text:
                duplicates.append(f"{path.relative_to(APP_ROOT)}: {marker}")
    assert duplicates == []


def test_meal_aliases_cover_tonight_and_this_morning():
    assert "今晚" in MEAL_ALIASES["dinner"]
    assert "今早" in MEAL_ALIASES["breakfast"]
    assert set(MEAL_LABELS) == set(MEAL_ORDER)


def test_body_and_equipment_aliases_cover_common_variants():
    assert any("膝盖" in alias for alias in BODY_PART_ALIASES["膝"])
    assert "壶铃" in EQUIPMENT_ALIASES["kettlebell"]
