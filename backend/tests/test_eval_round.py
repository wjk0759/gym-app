from eval.round import _provider_down


def test_provider_balance_error_is_not_a_coach_failure():
    assert _provider_down(
        {"error": 'LLM HTTP 402: {"code":"insufficient_balance_error"}'}
    )
    assert _provider_down({"error": "HTTP 429: rate limited"})
    assert not _provider_down({"error": "missing action: update_goal"})
    assert not _provider_down({})
