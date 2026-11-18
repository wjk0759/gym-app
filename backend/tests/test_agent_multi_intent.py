from __future__ import annotations

import asyncio
from datetime import date, datetime, timedelta

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import (
    AIMemory,
    Exercise,
    Profile,
    Program,
    ProgramDay,
    User,
)
from app.services.agent import (
    REVIEW_TZ,
    _deterministic_extra_turn,
    _forced_food_log_intent,
    _forget_memory_turn,
    _guard_action_card_claims,
    _guard_goal_action_consistency,
    _guard_pending_action_claims,
    _multi_intent_action_turn,
)
from app.services.memory import (
    _fact_conflicts_with_plan,
    is_pending_action_fact,
    list_memories,
    remember_facts,
    retire_goal_memories,
)

USER_ID = "00000000-0000-0000-0000-000000000001"
DAY_ID = "00000000-0000-0000-0000-0000000000d1"
PROGRAM_ID = "00000000-0000-0000-0000-0000000000b1"


def _tomorrow() -> date:
    return datetime.now(REVIEW_TZ).date() + timedelta(days=1)


def _plan_context() -> dict:
    target = _tomorrow()
    return {
        "plan": {
            "id": PROGRAM_ID,
            "current_week": 1,
            "days": [
                {
                    "id": DAY_ID,
                    "week_index": 1,
                    "weekday": target.isoweekday(),
                    "title": "全身 C",
                    "exercises": [
                        {
                            "slug": "push-up",
                            "name_zh": "俯卧撑",
                        },
                        {
                            "slug": "goblet-squat",
                            "name_zh": "高脚杯深蹲",
                        },
                    ],
                }
            ],
            "day_states": [
                {
                    "day_id": DAY_ID,
                    "assigned_date": target.isoformat(),
                }
            ],
        },
        "today_day": {"id": DAY_ID},
    }


@pytest.fixture()
def db():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session = Session(engine)
    session.add(User(id=USER_ID, phone="13800138000", status="active"))
    session.add(
        Profile(
            user_id=USER_ID,
            nickname="测试",
            sex="male",
            birth_date=date(1996, 1, 1),
            height_cm=178,
            weight_kg=72,
            equipment=["bodyweight", "dumbbell"],
        )
    )
    session.add_all(
        [
            Exercise(
                slug="push-up",
                name_zh="俯卧撑",
                name_en="push up",
                muscle_group="chest",
                equipment="bodyweight",
                plan_eligible=True,
            ),
            Exercise(
                slug="goblet-squat",
                name_zh="高脚杯深蹲",
                name_en="goblet squat",
                muscle_group="legs",
                equipment="dumbbell",
                plan_eligible=True,
            ),
        ]
    )
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def test_food_and_body_metric_become_two_cards(db):
    result = asyncio.run(
        _multi_intent_action_turn(
            db,
            USER_ID,
            "午餐吃了200g米饭，再记体重72kg",
            {},
        )
    )

    assert result is not None
    assert [action["type"] for action in result["actions"]] == [
        "log_food",
        "log_body_metric",
    ]
    assert result["actions"][1]["payload"]["weight_kg"] == 72


def test_multiple_body_metrics_merge_into_one_card(db):
    result = asyncio.run(
        _multi_intent_action_turn(
            db,
            USER_ID,
            "今天体重72kg，体脂18%，腰围80",
            {},
        )
    )

    assert result is not None
    assert [action["type"] for action in result["actions"]] == [
        "log_body_metric"
    ]
    payload = result["actions"][0]["payload"]
    assert payload["weight_kg"] == 72
    assert payload["body_fat_pct"] == 18
    assert payload["waist_cm"] == 80


def test_food_correction_without_pending_asks_instead_of_new_log(db):
    result = asyncio.run(
        _multi_intent_action_turn(
            db,
            USER_ID,
            "把今天午餐的米饭改成200g",
            {},
        )
    )

    assert result is not None
    assert result["actions"] == []
    assert "修改" in result["reply"]
    assert "新记" in result["reply"]


def _next_weekday(weekday: int) -> date:
    today = datetime.now(REVIEW_TZ).date()
    return today + timedelta(days=(weekday - today.isoweekday()) % 7)


def _ios_plan_context(weekday: int = 5, title: str = "全身 C") -> dict:
    target = _next_weekday(weekday)
    return {
        "plan": {
            "id": PROGRAM_ID,
            "days": [
                {
                    "id": DAY_ID,
                    "title": title,
                    "date": target.isoformat(),
                    "week_index": 1,
                    "exercises": [
                        {"slug": "push-up", "name_zh": "俯卧撑"},
                        {
                            "slug": "goblet-squat",
                            "name_zh": "高脚杯深蹲",
                        },
                    ],
                }
            ],
        },
        "today_day": {"id": DAY_ID},
    }


def test_bodyweight_reps_become_one_workout_card(db):
    result = asyncio.run(
        _multi_intent_action_turn(
            db,
            USER_ID,
            "100个俯卧撑分5组",
            {},
        )
    )

    assert result is not None
    assert [action["type"] for action in result["actions"]] == [
        "log_workout"
    ]
    payload = result["actions"][0]["payload"]
    assert payload["kind"] == "strength"
    assert len(payload["sets"]) == 5
    assert payload["sets"][0]["slug"] == "push-up"
    assert payload["sets"][0]["reps"] == 20
    assert sum(item["reps"] for item in payload["sets"]) == 100


def test_per_set_reps_are_not_divided_again(db):
    result = asyncio.run(
        _multi_intent_action_turn(
            db,
            USER_ID,
            "深蹲5组每组20个",
            {},
        )
    )

    assert result is not None
    payload = result["actions"][0]["payload"]
    assert len(payload["sets"]) == 5
    assert payload["sets"][0]["reps"] == 20


def test_cardio_log_gets_a_confirmation_card(db):
    result = asyncio.run(
        _multi_intent_action_turn(
            db,
            USER_ID,
            "刚跑了5公里，30分钟",
            {},
        )
    )

    assert result is not None
    assert [action["type"] for action in result["actions"]] == [
        "log_workout"
    ]
    payload = result["actions"][0]["payload"]
    assert payload["kind"] == "cardio"
    assert payload["duration_minutes"] == 30


def test_natural_language_skip_creates_a_card(db):
    result = asyncio.run(
        _multi_intent_action_turn(
            db,
            USER_ID,
            "明天全身 C 不练了",
            _plan_context(),
        )
    )

    assert result is not None
    assert [action["type"] for action in result["actions"]] == [
        "skip_training"
    ]
    assert result["actions"][0]["payload"]["day_id"] == DAY_ID


def _ios_week_context() -> dict:
    today = datetime.now(REVIEW_TZ).date()
    monday = today - timedelta(days=today.isoweekday() - 1)
    days: list[dict] = []
    for index in range(7):
        target = monday + timedelta(days=index)
        if target < today:
            continue
        days.append(
            {
                "id": f"00000000-0000-0000-0000-0000000000{index:02d}",
                "title": f"全身 {chr(65 + index % 3)}",
                "date": target.isoformat(),
                "week_index": 1,
                "exercises": [{"slug": "push-up", "name_zh": "俯卧撑"}],
                "completed": False,
                "skipped": False,
            }
        )
    return {
        "plan": {
            "id": PROGRAM_ID,
            "current_week": 1,
            "days": days,
        },
        "today_day": {"id": days[0]["id"]} if days else {},
    }


def test_body_metric_and_reschedule_become_two_cards(db):
    result = asyncio.run(
        _multi_intent_action_turn(
            db,
            USER_ID,
            "今天体重72kg，再把周五全身 C 改到周六",
            _ios_plan_context(5),
        )
    )

    assert result is not None
    assert [action["type"] for action in result["actions"]] == [
        "reschedule_training",
        "log_body_metric",
    ]
    assert result["actions"][1]["payload"]["weight_kg"] == 72


def test_skip_remaining_week_creates_batch_cards(db):
    context = _ios_week_context()
    expected = len(context["plan"]["days"])
    result = asyncio.run(
        _multi_intent_action_turn(
            db,
            USER_ID,
            "这周都不练了，帮我跳过剩下的训练",
            context,
        )
    )

    assert result is not None
    assert [action["type"] for action in result["actions"]] == [
        "skip_training"
    ] * expected
    assert "本周剩余" in result["reply"]


def test_ios_context_skip_uses_day_date_field(db):
    tomorrow = datetime.now(REVIEW_TZ).date() + timedelta(days=1)
    context = _ios_plan_context(5)
    context["plan"]["days"][0]["date"] = tomorrow.isoformat()
    result = asyncio.run(
        _multi_intent_action_turn(
            db,
            USER_ID,
            "明天全身 C 不练了",
            context,
        )
    )

    assert result is not None
    assert [action["type"] for action in result["actions"]] == [
        "skip_training"
    ]
    assert result["actions"][0]["payload"]["day_id"] == DAY_ID


def test_ios_context_delete_last_exercise_uses_day_date_field(db):
    result = asyncio.run(
        _multi_intent_action_turn(
            db,
            USER_ID,
            "把周五全身 C 的最后一个动作删掉",
            _ios_plan_context(5),
        )
    )

    assert result is not None
    assert [action["type"] for action in result["actions"]] == [
        "modify_workout"
    ]
    assert result["actions"][0]["payload"]["changes"] == [
        {"op": "remove", "slug": "goblet-squat"}
    ]


def test_explicit_body_metric_logging_creates_a_card(db):
    result = asyncio.run(
        _multi_intent_action_turn(
            db,
            USER_ID,
            "记一下今天体重72kg",
            {},
        )
    )

    assert result is not None
    assert [action["type"] for action in result["actions"]] == [
        "log_body_metric"
    ]
    assert result["actions"][0]["payload"]["weight_kg"] == 72


def test_explicit_body_metric_is_not_forced_into_food_tools():
    assert not _forced_food_log_intent("记一下今天体重72kg")
    assert not _forced_food_log_intent("今天体脂18%")


def test_two_skip_dates_are_not_silently_reduced_to_one(db):
    result = asyncio.run(
        _multi_intent_action_turn(
            db,
            USER_ID,
            "明天全身 C 不练了，后天也不练了",
            _plan_context(),
        )
    )

    assert result is None


def test_delete_last_exercise_creates_a_card_without_permission_claim(db):
    result = asyncio.run(
        _multi_intent_action_turn(
            db,
            USER_ID,
            "把明天全身 C 的最后一个动作删掉",
            _plan_context(),
        )
    )

    assert result is not None
    assert [action["type"] for action in result["actions"]] == [
        "modify_workout"
    ]
    changes = result["actions"][0]["payload"]["changes"]
    assert changes == [{"op": "remove", "slug": "goblet-squat"}]
    assert "权限" not in result["reply"]
    assert "准备" in result["reply"]


def test_week_high_protein_diet_plan_creates_a_card(db):
    result = _deterministic_extra_turn(
        db,
        USER_ID,
        "给我一周高蛋白饮食计划",
        {},
    )

    assert result is not None
    assert [action["type"] for action in result["actions"]] == [
        "create_diet_plan"
    ]
    assert result["actions"][0]["payload"]["strategy"] == "high_protein"


def test_whole_plan_change_is_honestly_downgraded(db):
    result = _deterministic_extra_turn(
        db,
        USER_ID,
        "整个计划的深蹲都换成前弓步",
        _plan_context(),
    )

    assert result is not None
    assert result["actions"] == []
    assert "只能按一个训练日改" in result["reply"]


def test_confirmed_card_claims_are_rewritten_before_write(db):
    text = _guard_pending_action_claims("米饭 200g 记好了，点确认记进饮食页。")

    assert "记好了" not in text
    assert "准备好了" in text


def test_card_claim_without_action_is_not_left_dangling():
    text = _guard_action_card_claims(
        "记录卡已经准备好了，你确认后就会写入。",
        [],
        None,
        None,
    )

    assert "记录卡" not in text
    assert "没有生成可确认的操作卡" in text


def test_forget_memory_deactivates_matching_memory(db):
    memory = AIMemory(
        user_id=USER_ID,
        kind="preference",
        memory_key="running",
        content="用户不喜欢跑步",
        source="agent",
        confidence=0.9,
        active=True,
    )
    db.add(memory)
    db.commit()

    result = _forget_memory_turn(db, USER_ID, "忘掉我不喜欢跑步这条")

    assert result is not None
    assert result["actions"] == []
    assert "已删除长期记忆" in result["reply"]
    db.refresh(memory)
    assert memory.active is False


def test_plan_fact_mismatch_is_rejected(db):
    db.add(
        Program(
            id=PROGRAM_ID,
            user_id=USER_ID,
            title="全身三分化",
            goal_type="build_muscle",
            version=1,
            status="active",
            start_date=date.today(),
            weeks=4,
            generated_by="ai",
        )
    )
    for index, title in enumerate(["全身 A", "全身 B", "全身 C"], start=1):
        db.add(
            ProgramDay(
                id=f"{PROGRAM_ID}-{index}",
                program_id=PROGRAM_ID,
                week_index=1,
                weekday=index * 2,
                title=title,
            )
        )
    db.commit()

    assert _fact_conflicts_with_plan(
        db,
        USER_ID,
        "用户当前训练计划采用全身 A 与全身 B 交替安排",
    )
    assert not _fact_conflicts_with_plan(
        db,
        USER_ID,
        "用户当前训练计划采用全身 A、B、C 循环安排",
    )


def test_goal_facts_are_not_written_to_long_term_memory(db):
    saved = remember_facts(
        db,
        USER_ID,
        [
            {
                "kind": "goal",
                "content": "用户目标改为减脂，体重目标 65kg",
                "confidence": 0.95,
            }
        ],
    )

    assert saved == []
    assert db.query(AIMemory).filter(AIMemory.kind == "goal").count() == 0


def test_retire_goal_memories_keeps_non_goal_memories(db):
    goal_memory = AIMemory(
        user_id=USER_ID,
        kind="goal",
        memory_key="fat_loss_target",
        content="用户目标改为减脂，体重目标 65kg",
        source="agent",
        confidence=0.9,
        active=True,
    )
    preference = AIMemory(
        user_id=USER_ID,
        kind="preference",
        memory_key="running",
        content="用户更喜欢早上跑步",
        source="agent",
        confidence=0.9,
        active=True,
    )
    db.add_all([goal_memory, preference])
    db.commit()

    retired = retire_goal_memories(db, USER_ID)
    db.commit()

    assert retired == 1
    db.refresh(goal_memory)
    db.refresh(preference)
    assert goal_memory.active is False
    assert preference.active is True
    assert all(item.kind != "goal" for item in list_memories(db, USER_ID))


def test_goal_reply_and_card_are_aligned():
    actions = [
        {
            "type": "update_goal",
            "payload": {"target_weight_kg": 65},
        }
    ]
    message = "6 周掉 7kg 太急，先定 68kg 吧，要不要我把目标改成 68kg？"

    guarded = _guard_goal_action_consistency(message, actions)

    assert actions[0]["payload"]["target_weight_kg"] == 68
    assert "68kg" in guarded
    assert "目标卡已按 68kg 准备" in guarded


def test_goal_reply_soft_wording_is_aligned():
    actions = [
        {
            "type": "update_goal",
            "payload": {"target_weight_kg": 65},
        }
    ]
    message = "6 周掉 7kg 太急，先摸到 67kg，之后稳住 67kg 左右。"

    guarded = _guard_goal_action_consistency(message, actions)

    assert actions[0]["payload"]["target_weight_kg"] == 67
    assert "目标卡已按 67kg 准备" in guarded


def test_pending_schedule_change_is_not_written(db):
    saved = remember_facts(
        db,
        USER_ID,
        [
            {
                "kind": "schedule",
                "content": (
                    "用户将全身 C 训练从周五调整到周六 11:00–21:00，"
                    "训练内容不变。"
                ),
                "confidence": 0.9,
            }
        ],
    )

    assert saved == []
    assert is_pending_action_fact(
        "schedule",
        "用户要求把周五全身C的深蹲改为4组×12次、20kg（待确认执行）",
    )


def test_soft_schedule_wish_is_still_allowed(db):
    saved = remember_facts(
        db,
        USER_ID,
        [
            {
                "kind": "schedule",
                "content": "用户希望将周五全身 C 的深蹲替换为前弓步",
                "confidence": 0.9,
            }
        ],
    )

    assert len(saved) == 1


def test_pending_schedule_memory_is_hidden_from_list(db):
    memory = AIMemory(
        user_id=USER_ID,
        kind="schedule",
        memory_key="pending_change",
        content=(
            "用户将周一漏练的全身A改到明天，"
            "原定明天的全身C已改到周六。"
        ),
        source="agent",
        confidence=0.9,
        active=True,
    )
    db.add(memory)
    db.commit()

    assert all(
        not is_pending_action_fact(item.kind, item.content)
        for item in list_memories(db, USER_ID)
    )


