# Adversarial QA cases

These cases are deliberately outside `backend/tests` so the normal CI suite
stays green. Run them explicitly when touching coach control-plane routing or
plan editing:

```bash
cd backend
pytest -q qa/test_adversarial.py
```

As of 2026-11-14, 9 of 14 cases fail against `ca7afce`; they document real
routing and data-integrity gaps. Do not delete them when fixing the bugs; move
the fixed cases into `backend/tests` as regression tests.
