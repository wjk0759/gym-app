# 28 · 动作库数据与导入

## 1. 当前数据规模

动作库已从 27 个手工种子扩展为 **80 个常用健身房/铁馆动作，且以固定器械为主**：

| 来源 | 数量 | 说明 |
|---|---:|---|
| FitAI 手工种子 | 27 | 保留原有中文动作、中文说明与精选字段 |
| `hasaneyldrm/exercises-dataset` | 53 | 按核心动作白名单导入，不保留宽握/窄握、上斜/下斜、单臂/交替等变式 |
| 合计 | **80** | 覆盖胸、背、腿、臀、肩、手臂、核心和有氧 |

导入后分类分布：

- 肌群：背 14、腿 14、肩 13、胸 12、手臂 11、臀 7、核心 6、有氧 3
- 器械：固定器械 33、杠铃 14、绳索 12、哑铃 10、自重 8、壶铃 3

固定轨迹器械（固定器械 + 绳索）共 **45 个**，已超过自由重量和自重动作；后续可以继续沿白名单增加固定器械动作。

## 2. 数据来源与许可证

选择的是当前公开可用的、规模较大且带中文说明的数据集：

- 仓库：<https://github.com/hasaneyldrm/exercises-dataset>
- 固定版本：`7455efae41b330c265e7cd4b78dfa848e7ce5ebd`
- 文件：`data/exercises.json`
- 文本/元数据/多语言说明：**MIT License**（完整声明见 `tools/db/data/EXERCISE_DATASET_NOTICE.md`）
- 仓库中的图片和 GIF：© Gym visual，需单独遵守其条款；本项目**不导入这些媒体**，只保存文字和元数据
- 英文名称到中文名称的翻译缓存：`tools/db/data/exercise_name_zh.json`，可人工校对

> 说明：公开数据只作为动作知识库；医疗、康复、孕期和术后场景仍按现有安全规则处理，不把导入数据当作诊断建议。

## 3. 字段映射

- `name_zh`：翻译缓存；缺失时保留英文名
- `name_en`：原始英文名
- `muscle_group`：映射到 App 支持的 8 个肌群；少数核心动作按训练习惯修正
- `equipment`：映射到 App 支持的 7 类器械
- `difficulty`：按器械复杂度和名称推断为 1–3
- `is_compound`：按次级肌群和动作名称推断
- `instructions`：优先使用数据集中文说明
- `contraindications`：导入数据不臆造禁忌症，保持空数组；人工维护的 27 个动作保留原值
- `video_url` / `thumbnail_url`：不导入媒体，保持空值；教学视频仍从后台发布
- `source`：`hasaneyldrm/exercises-dataset`
- `license`：`MIT; Gym visual media excluded`
- 核心动作白名单：`tools/db/data/common_exercise_allowlist.txt`

## 4. 重新导入

先确保 MySQL 已由 admin-server Flyway 建好，然后从仓库根目录执行：

```powershell
# 查看按核心动作白名单将新增/清理多少条
backend\.venv\Scripts\python.exe tools\db\import_exercises.py --dry-run

# 实际导入（默认只导入核心动作白名单；下载固定版本并校验 SHA-256）
backend\.venv\Scripts\python.exe tools\db\import_exercises.py

# 清理此前已导入、但不在核心白名单中的动作
backend\.venv\Scripts\python.exe tools\db\import_exercises.py --prune

# 如果需要所有健身房器械动作（不做核心白名单筛选）
backend\.venv\Scripts\python.exe tools\db\import_exercises.py --all-gym-equipment

# 离线使用已下载的 JSON
backend\.venv\Scripts\python.exe tools\db\import_exercises.py `
  --source C:\path\to\exercises.json
```

脚本是幂等的：已有英文名会跳过，重复执行不会重复插入。`--prune` 只有当行不在当前白名单/筛选范围内时才会删除导入行；被计划或训练引用的动作会被保护并报告。手工种子、计划、训练记录和用户数据不会被删除。

## 5. 后续可选增强

1. 给高频动作补充教学视频和封面；
2. 人工校对翻译缓存中的长尾动作名称；
3. 增加动作别名（英文缩写、俗称），提升搜索召回；
4. 为动作维护康复/禁忌标签时，必须由专业教练或康复师审核；
5. 若要使用 Gym visual 的图片/GIF，需单独取得媒体授权并保留 `© Gym visual — https://gymvisual.com/` 标识。
