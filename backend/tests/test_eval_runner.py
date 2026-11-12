import json

from eval.runner import gate_failures


def _summary(rate: float = 1.0, *, category: dict | None = None) -> dict:
    return {
        "pass_rate": rate,
        "by_category": category or {},
    }


def test_gate_fails_below_threshold():
    failures = gate_failures(
        summary=_summary(0.5),
        results=[],
        scenarios=[],
        fail_under=0.9,
        fail_on_safety=False,
        baseline=None,
    )
    assert failures
    assert "pass_rate" in failures[0]


def test_gate_fails_when_safety_case_fails():
    failures = gate_failures(
        summary=_summary(1.0),
        results=[
            {
                "id": "safety-1",
                "pass": False,
                "failures": ["safety reply lacks referral language"],
            }
        ],
        scenarios=[
            {
                "id": "safety-1",
                "expected": {"expected_safety": True},
            }
        ],
        fail_under=None,
        fail_on_safety=True,
        baseline=None,
    )
    assert failures
    assert "safety" in failures[0]


def test_gate_ignores_style_only_safety_scenario_failure():
    failures = gate_failures(
        summary=_summary(1.0),
        results=[
            {
                "id": "safety-1",
                "pass": False,
                "failures": ["too many sentences: 6"],
            }
        ],
        scenarios=[
            {
                "id": "safety-1",
                "expected": {"expected_safety": True},
            }
        ],
        fail_under=None,
        fail_on_safety=True,
        baseline=None,
    )
    assert failures == []


def test_gate_fails_below_baseline_category(tmp_path):
    baseline = tmp_path / "baseline.json"
    baseline.write_text(
        json.dumps(
            {
                "pass_rate": 0.8,
                "by_category": {
                    "training": {"total": 2, "passed": 2},
                },
            }
        ),
        encoding="utf-8",
    )
    failures = gate_failures(
        summary=_summary(
            0.9,
            category={"training": {"total": 2, "passed": 1}},
        ),
        results=[],
        scenarios=[],
        fail_under=None,
        fail_on_safety=False,
        baseline=str(baseline),
    )
    assert failures
    assert "training" in failures[0]


def test_gate_passes_clean_run(tmp_path):
    baseline = tmp_path / "baseline.json"
    baseline.write_text(
        json.dumps({"pass_rate": 0.9, "by_category": {}}),
        encoding="utf-8",
    )
    failures = gate_failures(
        summary=_summary(0.95),
        results=[],
        scenarios=[],
        fail_under=0.9,
        fail_on_safety=True,
        baseline=str(baseline),
    )
    assert failures == []
