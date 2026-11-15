# Raw knowledge sources

- `knowledge_seed.json`
  - FitAI original equipment recognition cues and coach knowledge cards.
  - license: original summaries for this project; source links are kept per card.
  - not medical advice; clinician review still required.
  - food synonyms/categories/nutrition were removed after evaluation; do not
    re-add food data without a new answer-level evaluation.

Run `python scripts/build_knowledge_base.py` from `backend/` to regenerate
`backend/data/knowledge/`.
