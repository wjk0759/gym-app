from app.services.exercise_search import (
    load_exercises,
    search_exercise_payload,
    search_exercises,
)


def test_exercise_corpus_is_filtered_and_loaded():
    rows = load_exercises()
    assert 600 <= len(rows) <= 800
    assert all(row.get("name_zh") for row in rows)
    assert all(row.get("safety_note") for row in rows)
    assert not any("(male)" in str(row.get("name_en", "")).lower() for row in rows)


def test_chinese_band_row_query_returns_row_variants():
    results = search_exercises("弹力带划船", limit=3)
    assert results
    text = " ".join(
        f"{item['name_zh']} {item['name_en']} {item['equipment_zh']}"
        for item in results
    )
    assert "划船" in text
    assert "弹力带" in text


def test_common_squat_query():
    results = search_exercises("深蹲", limit=3)
    assert results
    assert any("深蹲" in item["name_zh"] for item in results)


def test_english_query():
    results = search_exercises("bench press", limit=3)
    assert results
    assert any("press" in str(item["name_en"]).lower() for item in results)


def test_empty_and_missing_queries():
    assert search_exercises("") == []
    payload = search_exercise_payload("完全不存在的动作 xyz", limit=2)
    assert payload["ok"] is False
    assert "没有找到" in payload["error"]
