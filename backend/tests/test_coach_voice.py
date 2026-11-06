from app.routers.coach import _requires_phone_confirmation, _speech_text


def test_speech_text_strips_markdown_and_limits_length():
    text = _speech_text("## 结论\n\n**先做 2 组**，然后休息。")
    assert "##" not in text
    assert "**" not in text
    assert text.startswith("结论")

    long = _speech_text("第一句。" * 80)
    assert len(long) <= 130
    assert long.endswith("详细内容看手机。")


def test_plan_changes_require_phone_confirmation():
    assert _requires_phone_confirmation("帮我把下周改成一周四练")
    assert _requires_phone_confirmation("给我加一组")
    assert _requires_phone_confirmation("这个动作换一个动作")
    assert not _requires_phone_confirmation("还有几组？")
