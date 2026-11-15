# Third-party data notices

## Taiwan FDA Food Nutrition Database (2015)

- 中文名稱：衛生福利部食品藥物管理署《食品營養成分資料庫（2015 版）》
- Source: https://consumer.fda.gov.tw/Food/TFND.aspx?nodeID=178
- Mirror used: https://github.com/hanksudo/food-nutrition-data
- License: Taiwan government open data license (OGDL 1.0)
  - https://data.gov.tw/licenses
- Used in: `backend/data/raw/tw_food_2015.csv`,
  `backend/data/knowledge/food_nutrition.jsonl`
- Changes: Traditional Chinese converted to Simplified Chinese; rows validated,
  deduplicated, aliased and reshaped for retrieval. Values are not altered
  except for the documented zero-fill and energy/macro quality flags.

## hasaneyldrm/exercises-dataset

- Source: https://github.com/hasaneyldrm/exercises-dataset
- License: MIT for text/data; exercise media is © Gym visual and is **not**
  included in this repository.
- Used in: `backend/data/exercises_rag.jsonl`,
  `backend/data/knowledge/coach_knowledge.jsonl`
- Changes: filtered to common exercises, Chinese steps retained, records
  re-shaped for retrieval. The original safety note is kept.

## FitAI equipment catalog v2

- Internal project data in `backend/app/services/equipment_catalog_v2.py`.
- Used in: `backend/data/knowledge/equipment_knowledge.jsonl`.

## FitAI curated knowledge cards

- Original summaries written for this project, with source links per card.
- Not medical advice; clinician review is still required before using them as
  clinical guidance.
