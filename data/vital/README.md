# Vital Animations 1500 动作库草稿

这目录是 **只读分析 + 翻译 + 映射草稿**，还没有接入 iOS / 后端 / 生产库。

## 数据来源

- `E:\3d健身素材\1500VitalAnimations`
  - 健身房部分 832 条，和 `800VitalAnimations` 的视频哈希完全重复
  - 家庭部分 870 条，新增；去重后新增 866 条
  - 1500 缺少 `200workouts.json`，所以健身房元数据用 800 包补齐
- `E:\训记动作库\xunji_movements_1213.json`
  - 1,213 条中文动作名 + 15 个分区，无视频

## 生成结果

- `vital_actions_base.json`
  - 1,577 个唯一动作
  - 1,702 条媒体记录
- `vital_actions_zh_draft.json`
  - 中英双语动作草稿
  - `name_zh`：246 个来自训记精确同名，1,331 个来自模型翻译
  - `instructions_zh`：全部由模型翻译，全部标记 `instructions_needs_review=1`
- `xunji_vital_mapping.csv`
  - 1,213 条训记动作 → 1500 动作的映射
  - `exact` 287 条：中文名可直接用训记名
  - `base` 663 条：只是候选，**没有自动用作正式中文名**
  - `none` 263 条：当前没有找到可靠对应
- `vital_media_manifest.csv`
  - 1,702 条源视频 → 动作 slug、性别、来源路径
- `review_high.csv` / `review_medium.csv` / `review_low.csv`
  - 人工复核队列
  - 建议先看 `review_high.csv`（243 条），再看 medium

## 复核文件

- `review_high_videos.csv` / `review_high_videos.html`
  - 243 条高优先级复核，**包含源视频绝对路径**
  - HTML 可直接点开播放
- `review_medium_videos.csv`
- `review_low_videos.csv`
- `vital_actions_review_videos.csv`
  - 全部 1,577 条，包含 `primary_video_path` / `all_video_paths`
- 早期 `review_high.csv` / `review_medium.csv` / `review_low.csv` 没有视频路径，仅保留作对照

## 重要规则

1. `base` 映射只做候选，不自动写中文名。
   - 例如「反手俯卧撑」曾被错误匹配到 `Bench Dips`
   - 所以正式 `name_zh` 只使用 `exact` 训记名；其余用模型翻译
2. 原 1500 JSON 没有被覆盖，English 原名和 instructions 都保留。
3. 训练动作库最终是否合并训记独有动作，还需要确认：
   - 当前草稿是 1,577 个 Vital 动作
   - 训记 `none` 263 条还没有作为独立动作加入

## 数据修正

- 1500 的 `200workouts.json` 缺失：用 800 包
- 1500 的 `100gym` 有一条空 ID：视频为 `0028.mp4`
- Home Pilates `the hundred` 视频文件名不是 ID：单独按名称匹配
- 1500 内部有 5 组重复视频；800/400 是 1500 的子集

## 重新生成

```bash
python scripts/vital/build_catalog.py --out data/vital
python scripts/vital/merge_translations.py --data data/vital
```

翻译和 LLM 匹配文件在 `data/vital/llm/`，可复现当前草稿。
