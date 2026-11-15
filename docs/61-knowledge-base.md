# 61 · 教练知识库与 RAG 基线

> 目标：先把「数据太少」补到可用，再让教练按模块检索；不急着上向量库。
>
> 状态：三份知识库已生成并接入 `lookup_knowledge` 工具；检索是关键词基线，可替换为 embedding。
>
> 食物品类知识库已删除：它应该服务「用户自选饮食」，不应进入 AI 识别或教练 RAG。

## 1. 之前的数据缺口

| 模块 | 之前 | 问题 |
|---|---|---|
| 食物营养 | `food_vision.FOODS` 25 条 | 只能认少数家常菜，热量/宏量营养覆盖太窄 |
| 教练知识 | 无独立语料 | 体态、动作纠正、训练原则只能靠模型记忆 |
| 器械知识 | `equipment_catalog_v2.py` 95 条 | 有名称/肌群，缺识别线索、易混淆、使用要点 |
| 动作技术 | `exercises_rag.jsonl` 736 条 | 有中文步骤，但没有统一检索入口 |

## 2. 现在有什么

| 文件 | 条数 | 内容 |
|---|---:|---|
| `food_nutrition.jsonl` | 2,017 | 中文食物、每 100g 热量/蛋白质/脂肪/碳水/纤维/钠等 |
| `coach_knowledge.jsonl` | 782 | 736 条动作技术卡 + 46 条体态/训练/营养/安全卡 |
| `equipment_knowledge.jsonl` | 95 | 器械名称、别名、目标肌群、识别线索、易混淆、使用要点 |

食物营养里 **1,586 条宏量营养完整**，431 条只有部分营养；每条都带 `quality` 和 `flags`，检索/展示时可以降权。食物记录不再带 `category` 字段。

> **为什么删掉食物品类知识库**：AI 食物识别已经稳定，不应该再把 32 个品类或 2,017 条食物塞进视觉 prompt。品类数据后续只用于用户自选饮食目录，单独设计、单独接口，和视觉链路隔离。

## 3. 数据来源与许可

| 来源 | 用途 | 许可 |
|---|---|---|
| 台湾 FDA 食品营养成分数据库（2015） | 食物营养 | OGDL 1.0，可商用，需署名 |
| `hasaneyldrm/exercises-dataset` | 动作步骤 | MIT 文本；媒体不引入 |
| FitAI 器械目录 v2 | 器械 | 内部数据 |
| FitAI 整理卡片 | 教练知识、器械线索 | 原创摘要 |

原始文件在 `backend/data/raw/`，构建脚本在 `backend/scripts/build_knowledge_base.py`，清单在 `backend/data/knowledge/manifest.json`。

> 注意：台湾 2015 版是可靠的中文食物基线，但不等于最新版《中国食物成分表》；品牌食品仍应优先看包装营养表。

## 4. 三轮清洗

### 第一轮：接入与规范化

- 解析 CSV/JSONL，统一 UTF-8。
- 繁体中文 → 简体中文（OpenCC `t2s`）。
- 名称去多余空格，统一编号。
- 只删除完全重复；保留生/熟、去皮/带皮等真实差异。

结果：2,082 → 2,081 条（1 条完全重复）。

### 第二轮：校验与过滤

- 能量 0–950 kcal；蛋白质/脂肪/碳水 0–100g；钠 0–50,000mg。
- 用 4/4/9 估算热量，和表内热量差超过 `max(150 kcal, 35%)` 时标记 `macro_mismatch`。
- 对肉类/鱼贝/蛋缺失碳水、谷物/水果/蔬菜缺失脂肪等**明确为零**的情况补 0。
- 删除越界记录；同一规范化名称 + 相同营养桶的近似重复只留质量更高的一条。

结果：2,081 → 2,017 条；4 条越界删除，60 条近似重复合并，4 条热量/宏量不一致被标记。

### 第三轮：为 RAG 加工

- 生成别名：去括号、去“平均值/代表值”、拆分“、”、常见大陆同义词（米饭/白饭、三文鱼/鲑鱼、酸奶/发酵乳、奶酪/干酪等）。
- 加默认份量、质量分。
- 生成 `search_text`、`source`、`source_url`、`license`。
- 动作卡补目标肌群、部位、器械、步骤和安全提示。
- 器械卡补识别线索、使用要点和安全提示。

## 5. 检索入口

`backend/app/services/knowledge_search.py`：

```python
search_knowledge(query, domain="coach", limit=3)
knowledge_payload(query, domain="food", limit=3)
lookup_food("鸡胸肉")  # -> 每 100g 宏量营养
```

- 关键词评分：中文 2/3/4-gram + 英文词；标题/别名权重高于正文。
- 查询扩展：肩膀疼 → 肩痛/肩部，膝盖疼 → 膝痛，腰背 → 腰痛/背部。
- 食物解析按“精确名 > 代表值 > 非加工 > 质量 > 长度”排序，避免“鸡腿”误配“鸡腿菇”。
- `lookup_food` 已接入 `food_text.py`，确定性饮食记录从 25 条扩到 2,017 条；`FOODS` 里的人工菜谱仍优先。
- `lookup_knowledge(domain=coach)` 默认排除动作技术卡，动作步骤只走 `lookup_exercise`，避免双路径口径冲突。

教练侧新增工具：

```json
{"action":"tool","tool":"lookup_knowledge","arguments":{"domain":"coach","query":"深蹲膝盖内扣怎么纠正","limit":3}}
```

`domain` 只能是 `coach` / `food` / `equipment`。

## 6. 小评测

`backend/scripts/eval_knowledge.py`，36 条跨域查询（教练 14、食物 12、器械 10）：

- Hit@1：**1.00**
- Hit@3：**1.00**
- MRR@3：**1.00**

这是**检索冒烟集**，不是生产准确率；查询是人工构造的，覆盖有限。检索命中不等于回答更好，答案级 A/B 见 `docs/62-knowledge-impact-eval.md`。

## 7. 还没做

- 没上 embedding / Qdrant；当前是关键词 RAG 基线。
- 没做真实用户查询评测，也没做跨域混合检索；目前只有 36 条检索冒烟和 18 条答案级 A/B（`docs/62-knowledge-impact-eval.md`）。
- 教练卡片是原创摘要，**没有经过医生/康复师审阅**；疼痛、孕期、术后仍按安全护栏转专业评估。
- 没引入食物图片、动作视频、器械图片；媒体版权另行处理。
- 台湾 2015 数据不含部分大陆常见菜/品牌；需要继续补中国大陆食物成分表或包装营养表。
- 用户自选饮食目录还没做：需要单独设计分类、常用排序、份量预设和搜索接口，不能复用这次的视觉线索。
- 食物品类知识库已删除，避免进入 AI 识别/教练 RAG。

## 8. 重建

```powershell
cd backend
.\.venv\Scripts\python.exe -m pip install opencc-python-reimplemented==0.1.7
.\.venv\Scripts\python.exe scripts\build_knowledge_base.py
.\.venv\Scripts\python.exe -m pytest tests/test_knowledge_search.py -q
$env:PYTHONPATH="$PWD"; .\.venv\Scripts\python.exe scripts\eval_knowledge.py
```
