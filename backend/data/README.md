# Exercise RAG corpus

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
