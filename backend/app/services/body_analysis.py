"""体型照片分析：当前为可替换的 Mock，视觉模型接入后保持同一返回结构。

隐私原则：
- 不落盘原图，不写数据库
- 只返回训练建议，不做体脂/医疗诊断
- 真实视觉模型上线前需完成敏感个人信息单独同意与内容安全评估
"""

from __future__ import annotations

import hashlib

DISCLAIMER = (
    "照片分析仅用于训练重点参考，不构成体脂率、体态诊断或医疗建议。"
    "如需体成分数据，请使用专业设备；如有疼痛或伤病，请咨询医生或康复师。"
)

VARIANTS = [
    {
        "summary": "整体比例比较均衡，建议把训练重点放在背部与臀部，配合核心稳定，减少只练胸和手臂的倾向。",
        "focus_areas": ["back", "glutes", "core"],
        "recommendations": [
            "每周增加 1 次背部训练，优先高位下拉、坐姿划船",
            "臀部训练加入臀推或臀桥，每周 2 次",
            "核心稳定加入平板支撑，每次训练收尾 2 组",
        ],
        "confidence": 0.82,
    },
    {
        "summary": "下肢与核心可以承担更多训练量，建议采用上下肢分化，先把深蹲和髋伸动作做扎实。",
        "focus_areas": ["legs", "glutes", "core"],
        "recommendations": [
            "保留深蹲或腿举作为下肢主项",
            "加入罗马尼亚硬拉，强化后链",
            "每周至少 2 次核心稳定训练",
        ],
        "confidence": 0.76,
    },
    {
        "summary": "上肢推拉比例可以更平衡，建议增加划船类动作，同时控制卧推总量，避免肩部过度疲劳。",
        "focus_areas": ["back", "shoulders", "core"],
        "recommendations": [
            "推拉比例调整为 1:1.5",
            "加入面拉，改善肩胛稳定",
            "推日最后减少 1 组卧推，改为划船",
        ],
        "confidence": 0.71,
    },
    {
        "summary": "训练重点可以放在全身复合动作与稳定输出，不建议只做孤立动作。先建立规律，再追求围度变化。",
        "focus_areas": ["legs", "back", "core"],
        "recommendations": [
            "每次训练保留 2 个复合动作",
            "优先深蹲、硬拉、划船、推举",
            "每周记录完成率，连续两周再增加负荷",
        ],
        "confidence": 0.68,
    },
]


async def analyze(image_bytes: bytes, filename: str = "body.jpg") -> dict:
    digest = hashlib.sha256(image_bytes).digest()
    variant = VARIANTS[digest[0] % len(VARIANTS)]
    return {
        **variant,
        "disclaimer": DISCLAIMER,
        "model": "mock",
        "image_name": filename,
    }
