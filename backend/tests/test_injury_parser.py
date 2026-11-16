from app.services.coach_control.injury_parse import parse_injury_message

PARTS = ("膝", "腰", "肩", "腕", "踝", "肘", "半月板")


def test_parser_splits_recovered_and_ongoing_clauses():
    parsed = parse_injury_message("膝盖好了，腰还疼")
    assert parsed.recovered_parts == ["膝"]
    assert parsed.ongoing_parts == ["腰"]
    assert not parsed.global_clear


def test_parser_is_order_independent():
    parsed = parse_injury_message("膝盖不舒服但腰好了")
    assert parsed.recovered_parts == ["腰"]
    assert parsed.ongoing_parts == ["膝"]


def test_parser_handles_not_healed_and_discomfort():
    parsed = parse_injury_message("膝盖好了，腰还没好")
    assert parsed.recovered_parts == ["膝"]
    assert parsed.ongoing_parts == ["腰"]

    parsed = parse_injury_message("膝盖好了，腰不舒服")
    assert parsed.recovered_parts == ["膝"]
    assert parsed.ongoing_parts == ["腰"]


def test_global_clear_requires_no_body_part():
    parsed = parse_injury_message("没有伤病，都好了")
    assert parsed.global_clear is True
    assert parsed.mentions == ()

    parsed = parse_injury_message("膝盖伤好了")
    assert parsed.global_clear is False
    assert parsed.recovered_parts == ["膝"]


def test_explicit_replace_is_flagged():
    parsed = parse_injury_message("伤病改成右肩疼")
    assert parsed.explicit_replace is True
    assert parsed.ongoing_parts == ["肩"]


def test_every_part_pair_keeps_recovery_and_pain_separate():
    for first in PARTS:
        for second in PARTS:
            if first == second:
                continue
            parsed = parse_injury_message(f"{first}好了，{second}还疼")
            assert parsed.recovered_parts == [first]
            assert parsed.ongoing_parts == [second]
            assert first not in parsed.ongoing_parts
            assert second not in parsed.recovered_parts
