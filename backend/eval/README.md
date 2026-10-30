# Coach evaluation harness

Phase 0 calibration for the AI coach. It runs the real Agent against synthetic
profiles and, for media scenarios, a structured `visual_context` fixture. No
real photos or videos are uploaded.

## Why fixtures

The vision model is not what Phase 0 measures. We want to isolate:

- intent recognition
- tool/action selection
- body-fat answer policy (`约 20%`, no range)
- photo/video follow-up logic
- safety behavior
- response length and style

A real photo would add vision-model variance and cost without helping those
checks. The upload contract itself is covered separately by
`backend/tests/test_coach_media_limits.py`.

## Commands

From `backend/`:

```powershell
# regenerate the 100 calibration scenarios
.\.venv\Scripts\python.exe -m eval.generate_calibration

# validate without calling the model
.\.venv\Scripts\python.exe -m eval.runner --dry-run

# 1 scenario smoke test
.\.venv\Scripts\python.exe -m eval.runner --limit 1 --output eval/results/smoke.jsonl

# full calibration
.\.venv\Scripts\python.exe -m eval.runner --limit 100 --output eval/results/calibration-100.jsonl

# one category
.\.venv\Scripts\python.exe -m eval.runner --category body --output eval/results/body.jsonl

# exercise RAG cases (requires data/exercises_rag.jsonl)
.\.venv\Scripts\python.exe -m eval.generate_exercise_cases
.\.venv\Scripts\python.exe -m eval.runner --scenarios eval/scenarios/exercise_120.jsonl --limit 120 --output eval/results/exercise-120.jsonl
```

`exercise_120.jsonl` checks that `lookup_exercise` is actually called and that
the retrieved names are relevant. The summary also reports `lookup_exact`:
exact-name retrieval is a stricter quality metric, but a nearby common variant
still counts as a useful answer.

`eval/results/` is intentionally gitignored; scenario files are committed.

## Scenario contract

Each JSONL line:

```json
{
  "id": "body_001",
  "category": "body",
  "persona": "beginner",
  "turns": ["我体脂多少？"],
  "visual_context": {
    "kind": "body_photo",
    "body_fat_estimate": 20,
    "confidence": 0.62
  },
  "expected": {
    "must_include_any": ["约", "大概", "左右", "20%"],
    "must_not_include": ["精确", "一定"],
    "expected_actions": [],
    "expected_safety": false,
    "body_fat_approx": true,
    "max_sentences": 3
  }
}
```

Media kinds:

- `body_photo` — body-fat estimate; user-facing answer is one approximate number.
- `training_video` — ordered keyframes; `summary`, `observations`, `next_cue`.
- `equipment_photo` — equipment name/use/muscle.
- `food_photo` — food items and estimated nutrition.

The coach receives the fixture in `app_context.visual_context`, exactly where
the real analysed media summary lands.

## Token accounting

`llm.complete_json` / `complete_text` / `complete_vision_json` accept an optional
`usage` dict. The runner sums `prompt_tokens`, `completion_tokens`, cache hit and
cache miss tokens, then prices them with the off-peak CNY rate card:

- input cache miss: ¥1 / 1M
- input cache hit: ¥0.02 / 1M
- output: ¥4 / 1M

Update `PRICE_*` in `runner.py` only when the official rate card changes.

## Media upload tests

`backend/tests/test_coach_media_limits.py` covers:

- video posted to the image endpoint → 415
- empty image → 400
- single image over 8MB → 413
- batch over 6 frames → 413
- batch over 24MB → 413
- six video keyframes accepted
- single photo accepted

Video is deliberately converted to keyframes on iOS before upload. The backend
never accepts a movie file.
