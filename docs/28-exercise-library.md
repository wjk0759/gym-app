# 28 · 动作库数据与导入

## 1. 当前数据规模

当前 App 的动作库已切换为用户提供的训记动作清单：

| 项目 | 数量 | 说明 |
|---|---:|---|
| 训记动作清单 | **1,213** | `tools/db/data/xunji_movements_1213.json` |
| 原 FitAI 动作 | 80 | 保留在数据库中并标记为 `is_active = FALSE`，只用于历史计划/训练记录解析 |
| 当前可新建/可搜索 | **1,213** | iOS 资源 `ios/FitAI/Resources/xunji_movements.json`；API 只返回 `is_active = TRUE` |

训记文件只有三个字段：

- `序号`：稳定的 1–1213 序号，用来生成 `xj_0001` 这样的 slug；
- `动作名称`：中文动作名；
- `分区`：胸、背、腿、臀、肩、手臂、核心、有氧等原始分区。

该文件由用户本地提供，未附带公开再分发许可；当前按自用项目使用。若要公开仓库或对外分发这份动作清单，需要先确认权利来源。

因此当前动作库**没有原始英文名、器械、动作说明和禁忌症**。导入脚本会：

- 将 `分区` 映射到 App 的 8 个肌群；
- 根据动作名称中的器械关键词推断 `equipment`；没有明确器械时默认 `bodyweight`，不把它伪装成器械动作；
- 按动作名称推断 `is_compound`；
- 不编造动作说明和禁忌症，保持空值，App 使用通用提示文案；
- 把旧的 80 个动作保留为历史档案，不删除，避免计划/训练记录外键失效。

当前器械推断分布（仅用于筛选和计划生成，后续应根据真实器械数据校正）：

| 器械 | 数量 |
|---|---:|
| 自重 | 509 |
| 固定器械 | 221 |
| 哑铃 | 160 |
| 弹力带 | 121 |
| 杠铃 | 107 |
| 绳索 | 79 |
| 壶铃 | 16 |

> 训记清单包含大量变式和拉伸动作，和之前“80 个常用固定器械”的白名单策略不同。当前以用户指定的 1,213 条为准。

## 2. 与旧动作库的关系

- 旧动作行**不删除**，只把 `is_active` 设为 `FALSE`。
- `plan_exercises`、训练历史、用户器械库仍可引用旧 slug。
- iOS 的 `ExerciseLibrary.exercise(slug:)` 会同时索引当前动作和历史动作；搜索、候选动作、计划生成只使用当前的 1,213 条。
- Spring 管理后台的动作列表默认只显示 `is_active = TRUE` 的当前动作。

## 3. 数据库变更

Flyway `V10__exercise_library_switch.sql` 增加：

```sql
motion_start_url TEXT NULL
motion_end_url   TEXT NULL
is_active        BOOLEAN NOT NULL DEFAULT TRUE
```

`motion_start_url` / `motion_end_url` 只用于 RepDB Free 的双帧示意，不是视频字段，也不代表已经购买动画素材。

## 4. 导入/更新命令

先让 admin-server 启动并完成 Flyway，然后从仓库根目录执行：

```powershell
# 只生成 iOS 资源，不碰数据库
backend\.venv\Scripts\python.exe tools\db\import_xunji_movements.py --ios-only

# 预览将插入/更新多少条，不提交数据库
backend\.venv\Scripts\python.exe tools\db\import_xunji_movements.py --dry-run

# 实际切换：旧行归档为 inactive，训记 1,213 条设为 active
backend\.venv\Scripts\python.exe tools\db\import_xunji_movements.py
```

脚本是幂等的：按 `xj_序号` upsert，重复执行会更新当前动作并重新归档旧行。

## 5. RepDB Free 双帧示例

当前只为两个动作配置了 RepDB Free 的 `start` / `peak` 图片，用于评估：

| 当前动作 | RepDB 动作 | 状态 |
|---|---|---|
| `xj_0011` / 器械推胸 | `chest-press-machine` | 双帧示例 |
| `xj_0320` / 腿举 | `leg-press` | 双帧示例 |

iOS 端在「动作详情 → 动作轨迹」中使用 `FrameMotionBoard`，每 900ms 在两张静态图之间淡入淡出。**没有生成 GIF、没有把两张图合成新的媒体文件、也没有复制 RepDB 数据集到公开仓库。**

RepDB Free 许可要求可见署名：

```text
Exercise data by RepDB (repdb.co)
```

当前已在设置页和双帧卡片上显示该署名。若后续全量接入，需要继续保留署名，并且只把图片用于 App 内展示，不重新分发原始数据集。

浏览器预览：

```text
http://127.0.0.1:8765/xunji-repdb-demo.html
```

## 6. 旧数据集导入脚本

`tools/db/import_exercises.py` 仍保留，作为历史/备选数据源工具：

- 来源：<https://github.com/hasaneyldrm/exercises-dataset>
- 固定版本：`7455efae41b330c265e7cd4b78dfa848e7ce5ebd`
- 文本/元数据：MIT；图片/GIF 未导入
- 旧白名单：`tools/db/data/common_exercise_allowlist.txt`

除非需要恢复旧数据，不要在新的训记动作库上运行 `import_exercises.py`；两边都写同一张 `exercises` 表。

## 7. 后续

1. 根据真实器械清单校正 1,213 条动作的 `equipment`，尤其是无器械关键词的变式；
2. 为常用固定器械动作补动作说明、禁忌症和教学视频；
3. 若要全量使用 RepDB Free，先按当前动作名建立映射表，再批量配置双帧 URL；
4. 若必须使用真正的 GIF/视频，需要单独取得 RepDB Standard 或其他商业授权，不能把免费静态图导出成 GIF 再分发。
