# Profile Safety：模型调用前的确定性安全分流

## 目标

在调用 LLM 之前先判断用户请求是否需要硬拦截，避免“这次模型发挥得好”成为唯一的安全保障。

实现位置：`backend/app/services/safety.py`

## 分流顺序

1. **消息级红线**：自伤/自杀、胸痛/呼吸困难/晕厥、急性关节损伤、孕期/产后/术后、进食障碍。中英文关键词都覆盖。
2. **未成年人保护**：年龄 < 18，且涉及极端减重、断食、类固醇/SARMs、补剂剂量、超大训练量时，直接返回 `minor_guard`。
3. **老年人跌倒/平衡**：年龄 ≥ 65，且同时出现跌倒/平衡/头晕/骨密度风险与跑跳、HIIT、大重量时，返回 `fall_guard`。
4. **慢性病 + 高风险动作**：糖尿病、高血压、肾病、骨质疏松等 + 断食、大重量、HIIT、跑跳等，返回 `condition_guard`。
5. **用药 + 高风险动作**：华法林/抗凝、胰岛素、降压药、降糖药等 + 断食、大重量、HIIT 等，返回 `medication_guard`。
6. **疼痛/伤病 + 大重量或高冲击**：返回 `injury_guard`。
7. **类固醇/SARMs**：返回 `ped_guard`；**补剂剂量**返回 `supplement_guard`。
8. **软提醒**：未成年人正常训练、慢性病/用药但没有高风险动作、老年人平衡问题但没有高冲击动作，不拦截模型，只注入 `safety_context`，要求保守回答。

## 返回结构

```python
SafetyDecision(
    flag="minor_guard" | "fall_guard" | "condition_guard" | "medication_guard" | "medical_referral" | "crisis" | None,
    reply="直接展示的拦截回复",
    caution="交给模型的保守上下文",
    reason="触发原因，便于审计",
)
```

## 接入

- 旧教练：`coach_reply` 先调用 `assess_safety(profile, message)`；硬拦截直接返回，软提醒作为 system message 注入。
- Agent：`run_agent` 在模型调用前分流；安全回复会返回 `safety_flag`，并跳过工具和 LLM。
- Agent API：响应新增 `safety_flag`。
- iOS：Agent 消息和图片分析消息现在都会根据 `safety_flag` 显示“安全提醒”样式。
- 图片分析：`CoachPhotoStore` 把视觉结果的安全标记带入聊天气泡。

## 当前边界

- 慢性病和用药目前从当前消息识别；用户档案还没有结构化的 `conditions` / `medications` 字段。后续应在档案编辑页补齐，避免用户不重复提及就丢失上下文。
- 关键词是确定性底线，不是诊断；真正复杂的医学问题仍由医生评估。
- 软提醒只影响模型上下文，不会阻塞普通训练问答。

## 测试

`backend/tests/test_profile_safety.py` 覆盖：

- 英文自伤、英文进食障碍、孕期、胸痛
- 未成年人极端减重、超大训练量、补剂
- 未成年人正常训练不误伤
- 老年人跌倒/骨质疏松 + 高冲击
- 老年人平衡问题但没有高冲击 → 软提醒
- 糖尿病/高血压 + 断食/大重量
- 华法林 + 硬拉
- 疼痛 + 大重量
- SARMs、补剂剂量
- 慢性病/用药的普通问题 → 软提醒不拦截
- 正常请求无安全决策

运行：

```bash
cd backend
.venv/Scripts/python.exe -m pytest -q tests/test_profile_safety.py
```
