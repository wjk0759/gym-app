from app.routers.coach import _requires_phone_confirmation, _speech_text
from app.services.agent import SYSTEM_PROMPT as AGENT_SYSTEM_PROMPT
from app.services.coach_core import (
    coach_core_prompt,
    watch_voice_system_prompt,
)


def test_speech_text_strips_markdown_and_limits_length():
    text = _speech_text("## 结论\n\n**先做 2 组**，然后休息。")
    assert "##" not in text
    assert "**" not in text
    assert text.startswith("结论")

    long = _speech_text("第一句。" * 80)
    assert len(long) <= 130
    assert long.endswith("详细内容看手机。")
    assert _speech_text("##") == "详细内容看手机。"


def test_plan_changes_require_phone_confirmation():
    assert _requires_phone_confirmation("帮我把下周改成一周四练")
    assert _requires_phone_confirmation("给我加一组")
    assert _requires_phone_confirmation("这个动作换一个动作")
    assert _requires_phone_confirmation("帮我改一下训练安排")
    assert not _requires_phone_confirmation("还有几组？")


def test_watch_voice_and_agent_share_the_coach_core():
    core = coach_core_prompt()
    watch = watch_voice_system_prompt()
    assert core[:40] in AGENT_SYSTEM_PROMPT
    assert core[:40] in watch
    assert "不调用工具" in watch
    assert "这个需要到 iPhone 上确认" in watch
