# AI 教练说话风格

## 目标

默认像真人在微信里回消息，不像写文章。

- 默认 1–2 句，最多 3 个短段。
- 多数回答 60–120 个汉字。
- 先说结论，再给一个最小动作，最后最多问一个问题。
- 默认不列 1/2/3，不发散成完整方案。
- 只有用户明确说“详细说说”“给我完整计划”“列个清单”时才展开。
- 安全提醒可以略长，但也要先给结论，不写免责声明模板。

## 实现位置

- 文本教练：`backend/app/prompts/coach_system.md`
- Agent：`backend/app/services/agent.py` 的 `SYSTEM_PROMPT`
- 视觉分析：`backend/app/services/coach_vision.py`
- 图片回复展示：`ios/FitAI/Core/Services/CoachPhotoStore.swift`

## 视觉分析

- `summary` 最多 240 字，提示词要求一句话。
- `observations` 最多 3 条，每条最多 80 字。
- iOS 只展示前 3 条，避免图片回复变成检查报告。

## 不采用硬截断

曾在 `complete_text` 上尝试 `max_tokens=260`，结果 DeepSeek 的 reasoning tokens 挤占了输出预算，出现空回复和半句截断，已回退。

当前用提示词控制风格；如果未来要加硬上限，需要同时考虑 reasoning tokens，并对空回复/截断做检测，不能直接把 `max_tokens` 调小。

## 回归测试

- `backend/tests/test_coach_vision.py` 覆盖图片结果压缩。
- 文本风格仍需要真实模型抽样评审；固定 golden tests 只能保证安全/意图不回归。
