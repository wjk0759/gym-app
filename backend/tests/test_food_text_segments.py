from __future__ import annotations

from app.services.food_text import (
    _food_segments,
    meal_analysis,
    rule_resolution_by_meal,
    split_meal_clauses,
)


def test_food_segments_split_punctuation_and_spaces():
    assert _food_segments("鸡胸肉 200 g 米饭 150 g") == [
        "鸡胸肉 200 g",
        "米饭 150 g",
    ]
    assert _food_segments("鸡蛋 牛奶 米饭") == ["鸡蛋", "牛奶", "米饭"]
    assert _food_segments("燕麦+一杯冰美式") == ["燕麦", "一杯 冰美式"]
    assert _food_segments("湿炒螺蛳粉一份，半杯奶茶") == [
        "湿炒螺蛳粉 一份",
        "半杯 奶茶",
    ]


def test_food_segments_keep_dates_times_and_ranges_whole():
    assert _food_segments("2026-11-16 12:30 鸡胸肉 100-150g") == [
        "2026-11-16",
        "12:30",
        "鸡胸肉 100-150g",
    ]


def test_meal_clauses_split_on_meal_labels_not_commas():
    clauses = split_meal_clauses(
        "我昨天早上吃了200g麦片、中午吃的是干蒸牛肉+腊肠+200g米饭、"
        "晚饭吃了250g炒米粉+60g紫薯+100g玉米肠"
    )
    assert [meal for meal, _ in clauses] == ["breakfast", "lunch", "dinner"]

    trailing = split_meal_clauses("干蒸牛肉、腊肠、米饭是昨天中午吃的")
    assert trailing == [("lunch", "干蒸牛肉、腊肠、米饭是昨天中午吃的")]


def test_meal_analysis_uses_explicit_meal_not_first_mention():
    analysis = meal_analysis("这是我今天的晚饭，中午吃了300g燕麦+一杯冰美式")
    assert analysis["meal"] == "dinner"
    assert analysis["explicit"] == ["lunch"]


def test_rule_resolution_groups_three_meals():
    groups = rule_resolution_by_meal(
        "我昨天早上吃了200g麦片、中午吃的是干蒸牛肉+腊肠+200g米饭、"
        "晚饭吃了250g炒米粉+60g紫薯+100g玉米肠"
    )
    assert set(groups) == {"breakfast", "lunch", "dinner"}
    assert [item["name"] for item in groups["breakfast"].items] == ["麦片"]
    assert {item["name"] for item in groups["lunch"].items} == {
        "干蒸牛肉",
        "腊肠",
        "米饭",
    }
    assert {item["name"] for item in groups["dinner"].items} == {
        "炒米粉",
        "紫薯",
        "玉米肠",
    }
    assert all(not group.questions for group in groups.values())
