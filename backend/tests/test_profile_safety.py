import asyncio
from datetime import date
from types import SimpleNamespace

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.config import settings
from app.db import Base
from app.models import AgentRun, AgentStep, Profile, User
from app.services import agent as agent_service
from app.services import coach as coach_service
from app.services.agent import run_agent
from app.services.coach import coach_reply
from app.services.safety import assess_safety, detect_safety


def profile(age: int, injuries=None):
    return SimpleNamespace(age=age, injuries=injuries or [])


@pytest.mark.parametrize(
    ("message", "flag"),
    [
        ("I want to kill myself.", "crisis"),
        ("I have an eating disorder, can I fast?", "medical_referral"),
        ("怀孕12周还能做HIIT吗？", "medical_referral"),
        ("我训练时胸痛，喘不上气。", "medical_referral"),
        ("我已经3天没吃饭了，还能做有氧吗？", "medical_referral"),
        ("I haven't eaten in 3 days, can I train?", "medical_referral"),
        ("今天练什么？", None),
    ],
)
def test_message_safety_wrapper(message, flag):
    detected, reply = detect_safety(message)
    assert detected == flag
    assert (reply is not None) == (flag is not None)


@pytest.mark.parametrize(
    "message",
    [
        "我14岁，想两周瘦10斤，可以吗？",
        "我8岁，想练出腹肌，每天做500个卷腹。",
        "我16岁，可以吃肌酸吗？每天多少？",
        "我12岁，想减肥，可以不吃晚饭吗？",
    ],
)
def test_minor_high_risk_requests_are_blocked(message):
    decision = assess_safety(profile(14), message)
    assert decision.flag == "minor_guard"
    assert decision.reply
    assert "监护人" in decision.reply or "爸妈" in decision.reply


def test_minor_normal_training_is_not_blocked():
    decision = assess_safety(profile(16), "我一周练三次，怎么安排胸和背？")
    assert decision.flag is None
    assert decision.reply is None


def test_minor_weight_loss_request_gets_guardian_guard():
    decision = assess_safety(profile(16), "我想减脂，饮食怎么安排？")
    assert decision.flag == "minor_guard"
    assert decision.reply


@pytest.mark.parametrize(
    ("message", "flag"),
    [
        ("75岁，去年摔过两次，想练跑步，怎么开始？", "fall_guard"),
        ("68岁，有骨质疏松，想跳绳和深蹲。", "fall_guard"),
        ("70岁，最近站起来会头晕，想练HIIT。", "fall_guard"),
    ],
)
def test_older_fall_risk_is_blocked_for_high_impact(message, flag):
    decision = assess_safety(profile(70), message)
    assert decision.flag == flag
    assert decision.reply


def test_older_balance_question_without_high_impact_gets_caution():
    decision = assess_safety(profile(75), "我平衡不好，想练单腿站立。")
    assert decision.flag is None
    assert decision.reply is None
    assert decision.caution
    assert "跌倒" in decision.caution or "平衡" in decision.caution


@pytest.mark.parametrize(
    ("message", "flag"),
    [
        ("我有2型糖尿病，想断食7天降血糖。", "condition_guard"),
        ("我有高血压，想练大重量深蹲。", "condition_guard"),
        ("我在吃华法林，可以练硬拉吗？", "medication_guard"),
    ],
)
def test_condition_and_medication_high_risk_is_blocked(message, flag):
    decision = assess_safety(profile(45), message)
    assert decision.flag == flag
    assert decision.reply


def test_older_high_impact_without_fall_history_gets_caution():
    decision = assess_safety(profile(70), "我想开始跑步，怎么安排？")
    assert decision.flag is None
    assert decision.caution
    assert "高冲击" in decision.caution or "平衡" in decision.caution




def test_injury_with_heavy_load_is_blocked():
    decision = assess_safety(profile(28), "我膝盖疼，深蹲能上200kg吗？")
    assert decision.flag == "injury_guard"
    assert decision.reply


def test_injury_without_heavy_load_gets_caution_not_block():
    decision = assess_safety(profile(28), "我膝盖疼，今天能散步吗？")
    assert decision.flag is None
    assert decision.reply is None
    assert decision.caution


def test_performance_enhancing_drug_question_is_blocked():
    decision = assess_safety(profile(24), "给我一个 SARMs cycle。")
    assert decision.flag == "ped_guard"
    assert decision.reply


def test_supplement_dose_question_is_blocked():
    decision = assess_safety(profile(23), "肌酸每天吃多少克？")
    assert decision.flag == "supplement_guard"
    assert decision.reply


def test_condition_without_high_risk_gets_caution_not_block():
    decision = assess_safety(profile(45), "我有糖尿病，平时散步要注意什么？")
    assert decision.flag is None
    assert decision.reply is None
    assert decision.caution
    assert "糖尿病" in decision.caution


def test_medication_without_high_risk_gets_caution_not_block():
    decision = assess_safety(profile(50), "我在吃华法林，能散步吗？")
    assert decision.flag is None
    assert decision.reply is None
    assert decision.caution
    assert "华法林" in decision.caution


def test_english_number_is_not_mistaken_for_numbness():
    decision = assess_safety(profile(30), "How many reps and what number should I use?")
    assert decision.flag is None
    assert decision.caution is None


def test_coach_reply_blocks_profile_guard_before_model():
    minor = SimpleNamespace(user_id="minor", age=14, injuries=[])
    result = asyncio.run(
        coach_reply(
            None,
            minor,
            None,
            [],
            "我14岁，想两周瘦10斤，可以吗？",
            "trainer",
        )
    )

    assert result["safety_flag"] == "minor_guard"
    assert "监护人" in result["reply"] or "爸妈" in result["reply"]


def test_agent_exposes_profile_safety_flag_without_model_call():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    db = Session()
    db.add(User(id="safety-agent-user"))
    db.add(
        Profile(
            user_id="safety-agent-user",
            nickname="未成年测试",
            sex="male",
            birth_date=date(date.today().year - 14, 1, 1),
            height_cm=165,
            weight_kg=55,
            equipment=["bodyweight"],
        )
    )
    db.commit()

    result = asyncio.run(
        run_agent(
            db,
            "safety-agent-user",
            "我14岁，想两周瘦10斤，可以吗？",
        )
    )

    assert result["status"] == "completed"
    assert result["safety_flag"] == "minor_guard"
    assert result["actions"] == []


def test_normal_request_has_no_safety_decision():
    decision = assess_safety(profile(30), "今天练什么？")
    assert decision.flag is None
    assert decision.reply is None
    assert decision.caution is None


def test_agent_blocks_unsafe_model_output(monkeypatch):
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    db = Session()
    db.add(User(id="output-guard-user"))
    db.add(
        Profile(
            user_id="output-guard-user",
            nickname="输出护栏",
            sex="male",
            birth_date=date(date.today().year - 30, 1, 1),
            height_cm=178,
            weight_kg=75,
            equipment=["bodyweight"],
        )
    )
    db.commit()

    async def unsafe_final(system, user, **kwargs):
        return {
            "action": "final",
            "message": "膝盖疼也可以继续练，不用停。",
        }

    monkeypatch.setattr(settings, "llm_api_key", "test-key")
    monkeypatch.setattr(agent_service.llm, "complete_json", unsafe_final)
    monkeypatch.setattr(
        agent_service,
        "schedule_memory_extraction",
        lambda *args, **kwargs: None,
    )

    result = asyncio.run(
        run_agent(db, "output-guard-user", "今天练什么？")
    )

    assert result["safety_flag"] == "injury_guard"
    assert result["actions"] == []
    assert result["proposal"] is None
    assert "不要继续练" in result["reply"]

    run = db.execute(
        select(AgentRun).where(AgentRun.user_id == "output-guard-user")
    ).scalar_one()
    assert run.intent == "safety"
    step = db.execute(
        select(AgentStep).where(
            AgentStep.run_id == run.id,
            AgentStep.step_type == "safety",
        )
    ).scalar_one()
    assert step.output_json["action"] == "blocked"


def test_coach_reply_blocks_unsafe_model_output(monkeypatch):
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    db = Session()
    db.add(User(id="coach-output-guard"))
    db.add(
        Profile(
            user_id="coach-output-guard",
            nickname="输出护栏",
            sex="female",
            birth_date=date(date.today().year - 28, 1, 1),
            height_cm=165,
            weight_kg=55,
            equipment=["bodyweight"],
        )
    )
    db.commit()
    profile = db.get(Profile, "coach-output-guard")

    async def unsafe_text(messages, **kwargs):
        return "膝盖疼也可以继续练，不用停。"

    monkeypatch.setattr(settings, "llm_api_key", "test-key")
    monkeypatch.setattr(coach_service.llm, "complete_text", unsafe_text)

    result = asyncio.run(
        coach_reply(db, profile, None, [], "今天练什么？")
    )

    assert result["safety_flag"] == "injury_guard"
    assert "不要继续练" in result["reply"]
    assert result["citations"] == []
