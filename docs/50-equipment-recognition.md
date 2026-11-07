# 50 · 器械识别修复：从随机 mock 到器械目录匹配

> 2026-11-07：修复“拍照识别器械大部分不准”。根因不是模型太笨，而是视觉
> 请求失败后返回随机 mock、动作库只有 27 条旧动作、匹配只看中文名包含。

## 1. 修复前的问题

本地 `backend/smoke.db` 最近一次 `equipment_scan`：

```text
ai_jobs.status = fallback
ai_jobs.error  = vision HTTP 400
equipment_scans.model = mock
result = 跑步机快走 0.91 / 杠铃卧推 0.64 / 哑铃卧推 0.48
```

三个问题叠加：

1. **相册 HEIC 被当 JPEG 上传**，或原图过大，视觉接口返回 400。
2. **失败后回退随机 mock**，UI 把随机动作当成 AI 结果。
3. **动作库对不上**：生产只有 27 条旧动作，iOS 是 57 条 `cm_*` 训记动作；
   匹配只做中文名包含/二元组，蝴蝶机、龙门架、史密斯机等大量匹配不到。

## 2. 新链路

```text
拍照/相册
  -> iOS 统一转 JPEG、最长边 1280、修正方向
  -> 后端 Pillow 再校验/转码（支持 HEIC/PNG/WebP/JPEG）
  -> 视觉模型从器械目录中选 equipment_slug
  -> 后端把器械映射到动作库 slug
  -> 前端显示「识别到器械 + 1–3 个动作」
```

### 2.1 图片兼容

- iOS `ImageJPEGNormalizer`：
  - `UIImage` 重绘
  - 修正 EXIF 方向
  - 最长边 1280
  - 输出 JPEG 0.8
- 后端 `image_input.normalize_image_bytes`：
  - Pillow + `pillow-heif`
  - 支持 HEIC/PNG/WebP/JPEG
  - 去 EXIF、转 RGB、压到最长边 1280
  - 坏图返回 422，不再把非法数据发给视觉模型
- 器械、身体拍照、饮食拍照共用同一套归一化。

### 2.2 器械目录

`backend/app/services/equipment_catalog.py` 定义 37 个常见器械类型，包含：

- 中文名、英文名、常见别名
- 器械类别
- 可做的动作 slug（最多 3 个返回给前端）

覆盖示例：

```text
leg_press           腿举机
hack_squat          哈克深蹲机
pec_deck            蝴蝶机
chest_press_machine 坐姿推胸机
cable_station       龙门架 / 绳索训练站
lat_pulldown        高位下拉机
seated_row          坐姿划船机
leg_extension       腿屈伸机
leg_curl            腿弯举机
hip_abduction       髋外展机
hip_adduction       髋内收机
hip_thrust          臀推机
smith_machine       史密斯机
squat_rack          深蹲架
bench_press         卧推凳
incline_bench       上斜卧推凳
shoulder_press_machine 推肩机
calf_raise          提踵机
glute_kickback      后踢机
treadmill           跑步机
elliptical          椭圆机
rowing_machine      划船机
stationary_bike     动感单车
stair_climber       爬楼机
dumbbell_rack       哑铃架
barbell_rack        杠铃架
assisted_pullup     助力引体机
pullup_bar          引体向上架
dip_station         双杠架
...
```

多用途器械返回多个动作，例如龙门架：

```text
cm_cable_fly
cm_triceps_pushdown
cm_seated_row
cm_face_pull
cm_straight_arm_pulldown
cm_cable_crunch
cm_cable_kickback
```

### 2.3 视觉输出

模型只从目录中选，不再自由发明动作名：

```json
{
  "is_gym_equipment": true,
  "equipment_slug": "leg_press",
  "equipment_name": "腿举机",
  "confidence": 0.94,
  "visible_features": ["倾斜滑轨", "脚踏板", "挂片杆"],
  "exercise_slugs": ["cm_leg_press"],
  "description": "一台挂片式线性腿举机。"
}
```

### 2.4 失败不再返回随机结果

- 视觉失败返回 `status="unavailable"`，`candidates=[]`，带 `warning`
- 未识别到器械返回 `status="not_gym_equipment"`
- 识别到器械但动作库没有动作返回 `status="no_actions"`，`not_in_library=true`
- iOS 显示“识别服务暂时不可用 / 重新识别 / 手动添加”，不再展示随机候选
- 删除 `EquipmentService` 的本地随机 mock；保留命名空间给未来的真实本地分类器

## 3. 动作库同步

生产 `exercises` 已导入 57 条当前训记动作（`curated_iron_gym`），旧 27 条保留但
`is_active=0`，历史计划和记录仍可解析。

同时给示例动画补了 `cm_*` 媒体别名：

```text
cm_squat          <- squat
cm_hip_thrust     <- hip_thrust
cm_romanian_deadlift <- romanian_deadlift
cm_leg_press      <- leg_press
cm_rowing_machine <- rowing_machine
cm_triceps_pushdown <- triceps_pushdown
cm_treadmill      <- treadmill_walk
cm_shoulder_press <- shoulder_press
cm_lateral_raise  <- lateral_raise
cm_crunch         <- crunch
```

这样新动作库的水平也能命中已上传的示例动画。

## 4. 真实图片验证

用 4 张真实健身房照片 + 1 张非器械截图做生产烟测：

| 图片 | 期望 | 结果 |
|---|---|---|
| Hammer Strength 腿举/哈克机 | 腿举 / 哈克 | `leg_press` 0.94，候选含 `cm_hack_squat` 0.80 |
| 两台椭圆机 | 椭圆机 | `elliptical` 0.93 |
| StairMaster + 跑步机 | 跑步机 / 爬楼机 | `treadmill` 0.93 |
| 龙门架 + 训练凳 | 龙门架 | `cable_station` 0.93；候选 绳索夹胸/绳索下压/坐姿划船 |
| App 动作演示截图 | 非器械 | `not_gym_equipment`，无候选 |

结果：**5/5 主判断正确**。图片仅用于本地/生产烟测，未提交到仓库。

## 5. 仍未完成

- iOS 编译与真机验证（本轮代码推送后跑 CI）。
- 更细的器械分类：史密斯机 vs 普通深蹲架、蝴蝶机 vs 反式蝴蝶机、
  不同品牌的腿举/哈克一体机。
- 更多动作库：当前 57 条覆盖常见商业健身房；1,213 / 1,500 条全量仍需映射。
- 评测集：建议用 GymBro/GymGuide 23 类数据集（6,620 张，代码 MIT，数据集 license
  需在 Roboflow 页面核实）做 few-shot 参考和 30–50 张真实照片评测。
- 如果 top-3 仍低于 90%，再训练轻量分类器或 CLIP/SigLIP 检索；不要一上来就训练。

## 6. 验收

- 任意图片不再返回随机动作。
- 视觉失败有明确提示和重试入口。
- 常见器械能返回器械名 + 1–3 个动作候选。
- 多用途器械返回多个动作，不强行只给一个。
- 动作库 slug 与 iOS 当前 57 条一致。
- 器械、身体、饮食三条拍照链路都能接受 HEIC/JPEG/PNG/WebP。
