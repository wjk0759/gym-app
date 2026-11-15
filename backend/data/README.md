# Data files

## 1. Exercise RAG corpus

`exercises_rag.jsonl` is a filtered, text-only subset of the Agent data pack:

- source: `hasaneyldrm/exercises-dataset`
- text license: MIT (per the source pack)
- media license: © Gym visual — **media is intentionally excluded**
- source records: 1,324
- kept: 736 common exercises
- dropped: 571 unranked, 17 duplicates

Regenerate from the original pack:

```powershell
.\.venv\Scripts\python.exe scripts\build_exercise_rag.py "C:\path\to\FitAI_Agent_数据包.json"
```

The coach does not receive this whole file. `app/services/exercise_search.py`
retrieves the top 3–5 records for a `lookup_exercise` tool call, so the prompt
stays small and the knowledge remains auditable.

Every record carries a safety note because the source has no contraindications
or rehabilitation guidance. Do not treat it as medical advice.

## 2. Coach and equipment knowledge base

`knowledge/` is built by `scripts/build_knowledge_base.py` from audited sources.
It is committed so production does not rebuild it at boot.

| File | Records | Purpose |
|---|---:|---|
| `coach_knowledge.jsonl` | 782 | 736 exercise technique cards + 46 curated cards |
| `equipment_knowledge.jsonl` | 95 | Gym equipment, muscles, recognition cues |
| `manifest.json` | — | source/license/counts/build metadata |

> Food nutrition was removed after answer-level A/B: it is not used by the
> vision model, and its 2015 regional composition values were judged worse than
> the model's own common knowledge for free-form nutrition questions. Do not
> re-add food data to the vision or coach prompt without a new evaluation.

### Sources and licenses

| Source | Used for | License |
|---|---|---|
| `hasaneyldrm/exercises-dataset` | exercise technique | MIT text; media excluded |
| FitAI equipment catalog v2 | equipment records | internal |
| FitAI curated cards | coach, equipment cues | original summaries |

Rebuild:

```powershell
.\.venv\Scripts\python.exe scripts\build_knowledge_base.py
```

Runtime retrieval is standard-library only:

```python
from app.services.knowledge_search import search_knowledge, knowledge_payload
```

`search_knowledge` / `knowledge_payload` back the `lookup_knowledge` coach tool.
Exercise technique still uses `lookup_exercise` / `exercise_search.py`; the coach
domain excludes exercise cards to keep one canonical path.

## 3. Safety and quality boundaries

- Coach cards are educational summaries written for this project, with source
  links. They are not medical advice and have not been reviewed by a clinician.
- Exercise records use a generic safety note; they do not contain
  contraindications, rehab protocols, or pregnancy-specific guidance.
- Food logging still uses the small curated `food_vision.FOODS` table plus the
  LLM fallback; no food knowledge base is shipped.
- No food photos, exercise videos, or equipment images are included here.
