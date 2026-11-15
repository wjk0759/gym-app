"""Coverage for the coach/equipment knowledge bases and lexical RAG."""

from __future__ import annotations

from app.services.knowledge_search import (
    DOMAINS,
    knowledge_payload,
    load_domain,
    search_knowledge,
)


def test_knowledge_base_minimum_coverage():
    counts = {domain: len(load_domain(domain)) for domain in DOMAINS}
    assert counts["coach"] >= 700
    assert counts["equipment"] >= 90


def test_every_knowledge_record_has_source_and_license():
    for domain in DOMAINS:
        for item in load_domain(domain):
            assert item.get("title"), (domain, item.get("id"))
            assert item.get("source"), (domain, item.get("id"))
            assert item.get("license"), (domain, item.get("id"))


def test_food_matching_keeps_curated_dishes():
    from app.services.food_text import _match_food

    assert _match_food("螺蛳粉一份") == ("螺蛳粉", "螺蛳粉")
    assert _match_food("一杯奶茶") == ("奶茶", "奶茶")


def test_search_coach_posture_and_nutrition():
    posture = search_knowledge(
        "深蹲膝盖内扣怎么纠正", domain="coach", limit=3
    )
    assert posture
    assert "膝内扣" in posture[0]["title"] or "深蹲" in posture[0]["title"]

    protein = search_knowledge("蛋白质吃多少", domain="coach", limit=3)
    assert protein
    assert "蛋白质" in protein[0]["title"]


def test_coach_knowledge_does_not_duplicate_exercise_lookup():
    filtered = search_knowledge("杠铃卧推", domain="coach", limit=3)
    assert all(result["kind"] != "exercise" for result in filtered)

    raw = search_knowledge(
        "杠铃卧推",
        domain="coach",
        limit=3,
        include_exercises=True,
    )
    assert any(result["kind"] == "exercise" for result in raw)


def test_search_equipment_uses_recognition_cues():
    results = search_knowledge(
        "坐姿划船机怎么辨认", domain="equipment", limit=3
    )
    assert results
    assert results[0]["title"] == "坐姿划船机"
    assert "水平拉" in results[0]["text"]


def test_knowledge_payload_is_tool_safe():
    payload = knowledge_payload("膝盖疼怎么办", domain="coach", limit=2)
    assert payload["ok"] is True
    assert len(payload["results"]) <= 2
    assert all(result["source"] for result in payload["results"])

    missing = knowledge_payload("不存在的知识条目", domain="equipment")
    assert missing["ok"] is False


def test_agent_exposes_lookup_knowledge_tool():
    from app.services.agent import AGENT_INSTRUCTIONS, ALLOWED_TOOLS

    assert "lookup_knowledge" in ALLOWED_TOOLS
    assert "lookup_knowledge" in AGENT_INSTRUCTIONS


def test_food_text_splits_compound_portions():
    from app.services.food_text import resolve_food_rules

    breakfast = resolve_food_rules("早餐两个鸡蛋一杯牛奶")
    assert [item["name"] for item in breakfast.items] == ["鸡蛋", "牛奶"]
    assert [item["grams"] for item in breakfast.items] == [100, 250]

    dinner = resolve_food_rules("晚饭米饭150g和西兰花200g")
    assert [item["name"] for item in dinner.items] == ["米饭", "西兰花"]
    assert [item["grams"] for item in dinner.items] == [150, 200]

    # "牛筋" is a real food, but "牛筋肉肠" is a different product. The
    # deterministic matcher must ask instead of logging 80g of beef tendon.
    unknown = resolve_food_rules("80 克牛筋肉肠")
    assert unknown.items == []
    assert "牛筋肉肠" in unknown.questions[0]
