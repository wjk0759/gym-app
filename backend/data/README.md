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

## 2. Three-domain knowledge base

`knowledge/` is built by `scripts/build_knowledge_base.py` from audited open
sources. It is committed so production does not rebuild it at boot.

| File | Records | Purpose |
|---|---:|---|
| `food_nutrition.jsonl` | 2,017 | Chinese food composition, per 100g |
| `coach_knowledge.jsonl` | 782 | 736 exercise technique cards + 46 curated cards |
| `equipment_knowledge.jsonl` | 95 | Gym equipment, muscles, recognition cues |
| `manifest.json` | — | source/license/counts/cleaning stats |

> The food-category taxonomy was removed. It is for a future user-facing food
> picker, not for the vision model or coach RAG. Do not inject it into the
> food-photo prompt.

### Sources and licenses

| Source | Used for | License |
|---|---|---|
| Taiwan FDA Food Nutrition Database (2015) | food composition | OGDL 1.0 |
| `hasaneyldrm/exercises-dataset` | exercise technique | MIT text; media excluded |
| FitAI equipment catalog v2 | equipment records | internal |
| FitAI curated cards | coach, equipment cues | original summaries |

The Taiwan dataset is distributed under the Taiwan government open data
license (OGDL 1.0), which permits commercial use with attribution. Keep the
source and license fields on every record and in the manifest.

### Three cleaning rounds

1. **Ingest + normalize**
   - parse the source CSV / JSONL
   - Traditional Chinese → Simplified Chinese (`opencc`)
   - normalize whitespace, names, categories
   - drop exact duplicates
2. **Validate + filter**
   - enforce nutrient ranges (0–950 kcal, macros 0–100g, sodium 0–50,000mg)
   - flag kcal vs. 4/4/9 macro mismatches above max(150 kcal, 35%)
   - fill unambiguous zeros (meat/seafood/egg carbs, grain/fruit/veg fat)
   - drop invalid rows and collapse identical near-duplicates
3. **Enrich + shape for retrieval**
   - add aliases (parentheses, average labels, common mainland synonyms)
   - add serving hints, quality scores
   - build deterministic search text and source metadata

Rebuild:

```powershell
.\.venv\Scripts\python.exe -m pip install opencc-python-reimplemented==0.1.7
.\.venv\Scripts\python.exe scripts\build_knowledge_base.py
```

Runtime retrieval is standard-library only:

```python
from app.services.knowledge_search import (
    search_knowledge, knowledge_payload, lookup_food,
)
```

`lookup_food` is used by `food_text.py` for deterministic diet logging;
`search_knowledge` / `knowledge_payload` back the `lookup_knowledge` coach tool.
The lexical baseline is replaceable by embeddings behind the same interface.

## 3. Safety and quality boundaries

- Food values are per 100g unless noted; cooked/raw and brand variants differ.
- The Taiwan table is the 2015 edition. It is a solid Chinese-food baseline,
  not a substitute for the current Chinese Food Composition Table or a
  manufacturer's nutrition label.
- Coach cards are educational summaries written for this project, with source
  links. They are not medical advice and have not been reviewed by a clinician.
- Exercise records use a generic safety note; they do not contain
  contraindications, rehab protocols, or pregnancy-specific guidance.
- No food photos, exercise videos, or equipment images are included here.
