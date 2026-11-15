# 61 · 教练与器械知识库

> 目标：让教练按模块检索动作、体态、训练原则和器械知识；不急着上向量库。
>
> 状态：教练 / 器械两套知识库已接入 `lookup_knowledge`；食物营养知识库已彻底删除。

## 1. 现在有什么

| 文件 | 条数 | 内容 |
|---|---:|---|
| `coach_knowledge.jsonl` | 782 | 736 条动作技术卡 + 46 条体态/训练/营养/安全卡 |
| `equipment_knowledge.jsonl` | 95 | 器械名称、别名、目标肌群、识别线索、易混淆、使用要点 |
| `manifest.json` | — | 来源、许可、条数、构建元数据 |

动作技术仍走 `lookup_exercise` / `exercise_search.py`；`lookup_knowledge(domain=coach)` 默认排除动作卡，避免同一动作两套说法。

## 2. 食物知识库为什么删除

食物营养知识库（2,017 条）在 18 条答案级 A/B 中 **0 胜 6 负**；修正多食物检索后仍是 **3 胜 7 负 2 平**。主要问题：

- 台湾 2015 表与大陆常见生/熟、部位、品种口径不一致；
- 白饭 41g 碳水/100g、鸡胸肉 20–22g 等数值被模型常识反超；
- 431/2,017 条只有部分宏量营养；
- 照片识别从未使用该库。

结论：食物营养库不适合作为自由问答权威，已删除；文字饮食记录仍使用 `food_vision.FOODS` 的 25 条人工表和 LLM 兜底。详见 `docs/62-knowledge-impact-eval.md`。

## 3. 数据来源与许可

| 来源 | 用途 | 许可 |
|---|---|---|
| `hasaneyldrm/exercises-dataset` | 动作步骤 | MIT 文本；媒体不引入 |
| FitAI 器械目录 v2 | 器械 | 内部数据 |
| FitAI 整理卡片 | 教练知识、器械线索 | 原创摘要 |

原始文件在 `backend/data/raw/`，构建脚本在 `backend/scripts/build_knowledge_base.py`，清单在 `backend/data/knowledge/manifest.json`。

## 4. 检索入口

`backend/app/services/knowledge_search.py`：

```python
search_knowledge(query, domain="coach", limit=3)
knowledge_payload(query, domain="equipment", limit=3)
```

- 关键词评分：中文 2/3/4-gram + 英文词；标题/别名权重高于正文。
- 查询扩展：肩膀疼 → 肩痛/肩部，膝盖疼 → 膝痛，腰背 → 腰痛/背部。
- `domain` 只能是 `coach` / `equipment`。
- 教练侧工具：

```json
{"action":"tool","tool":"lookup_knowledge","arguments":{"domain":"coach","query":"深蹲膝盖内扣怎么纠正","limit":3}}
```

## 5. 评测

检索冒烟集 24 条（教练 14、器械 10）：

- Hit@1 / Hit@3 / MRR@3：**1.00**

答案级 A/B 见 `docs/62-knowledge-impact-eval.md`：

- 器械稳定偏正向；
- 教练略偏正向但大量平局；
- 食物已删除。

检索命中不等于回答更好；当前只有关键词基线，可替换为 embedding。

## 6. 边界

- 教练卡片是原创摘要，**没有经过医生/康复师审阅**；疼痛、孕期、术后仍按安全护栏转专业评估。
- 器械识别线索只有 30 条是人工写的，其余是派生描述，质量不均。
- 不要把这些知识注入视觉 prompt；照片识别链路保持独立。
- 没有引入食物图片、动作视频、器械图片；媒体版权另行处理。

## 7. 重建

```powershell
cd backend
.\.venv\Scripts\python.exe scripts\build_knowledge_base.py
.\.venv\Scripts\python.exe -m pytest tests/test_knowledge_search.py -q
$env:PYTHONPATH="$PWD"; .\.venv\Scripts\python.exe scripts\eval_knowledge.py
```
