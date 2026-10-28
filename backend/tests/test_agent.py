import pytest

from app.services.agent import _normalize_app_actions, _normalize_split, _normalize_weekdays


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


def test_app_action_normalization():
    context = {"plan": {"days": [{"id": "day-1"}]}}
    actions = _normalize_app_actions(
        [
            {
                "type": "reschedule_training",
                "title": "顺延拉日",
                "summary": "保留训练内容",
                "payload": {"day_id": "day-1", "target_date": "next_free"},
            },
            {
                "type": "open_screen",
                "title": "打开计划",
                "payload": {"screen": "plan"},
            },
        ],
        context,
    )
    assert len(actions) == 2
    assert actions[0]["requires_confirmation"] is True
    assert actions[1]["requires_confirmation"] is True
    assert actions[0]["id"] != actions[1]["id"]


def test_app_action_rejects_unknown_day_or_screen():
    context = {"plan": {"days": [{"id": "day-1"}]}}
    with pytest.raises(ValueError):
        _normalize_app_actions(
            [{"type": "skip_training", "payload": {"day_id": "not-mine"}}],
            context,
        )
    with pytest.raises(ValueError):
        _normalize_app_actions(
            [{"type": "open_screen", "payload": {"screen": "unknown"}}],
            context,
        )
    with pytest.raises(ValueError):
        _normalize_app_actions(
            [
                {
                    "type": "reschedule_training",
                    "payload": {"day_id": "day-1", "target_date": "tomorrow"},
                }
            ],
            context,
        )


def test_body_metric_action_requires_valid_weight():
    actions = _normalize_app_actions(
        [
            {
                "type": "log_body_metric",
                "title": "记录体重",
                "payload": {"weight_kg": 70},
            }
        ]
    )
    assert actions[0]["payload"]["weight_kg"] == 70
    with pytest.raises(ValueError):
        _normalize_app_actions(
            [{"type": "log_body_metric", "payload": {"weight_kg": "heavy"}}]
        )


def test_app_action_allows_full_week_skips():
    context = {
        "plan": {
            "days": [{"id": f"day-{index}"} for index in range(1, 9)]
        }
    }
    raw_actions = [
        {
            "type": "skip_training",
            "title": f"取消第 {index} 天",
            "payload": {"day_id": f"day-{index}"},
        }
        for index in range(1, 8)
    ]
    actions = _normalize_app_actions(raw_actions, context)
    assert len(actions) == 7

    with pytest.raises(ValueError):
        _normalize_app_actions(
            [
                *raw_actions,
                {
                    "type": "skip_training",
                    "title": "取消第 8 天",
                    "payload": {"day_id": "day-8"},
                },
            ],
            context,
        )
