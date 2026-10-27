from app.services.agent import _normalize_split, _normalize_weekdays


def test_weekday_normalization():
    assert _normalize_weekdays([2, 4, 6, 2]) == [2, 4, 6]
    assert _normalize_weekdays([]) == []
    assert _normalize_weekdays([0, 8, "3"]) == [3]


def test_split_aliases():
    assert _normalize_split("推/拉/腿") == "3分化"
    assert _normalize_split("推拉腿") == "3分化"
    assert _normalize_split("全身") == "1分化"
    assert _normalize_split("5分化") == "5分化"
    assert _normalize_split(None) is None
