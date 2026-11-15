# Raw knowledge sources

- `tw_food_2015.csv`
  - 衛生福利部食品藥物管理署《食品營養成分資料庫（2015 版）》
  - source: https://consumer.fda.gov.tw/Food/TFND.aspx?nodeID=178
  - mirror used for this build: https://github.com/hanksudo/food-nutrition-data
  - license: Taiwan government open data license (OGDL 1.0)
  - note: 2015 edition; Traditional Chinese converted to Simplified during build.

- `knowledge_seed.json`
  - FitAI original food synonyms, food-category cues, equipment recognition
    cues and coach knowledge cards.
  - license: original summaries for this project; source links are kept per card.
  - not medical advice; clinician review still required.

Run `python scripts/build_knowledge_base.py` from `backend/` to regenerate
`backend/data/knowledge/`.
