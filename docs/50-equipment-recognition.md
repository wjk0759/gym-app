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

## 4.1 准确率实验（2026-11-08，18 张多品牌实拍）

用 18 张不同健身房/品牌的实拍图（Hammer Strength、Life Fitness、Inspiration、
SHUA、Precor 等）做评测，人工校正标签后对比几种方案：

| 方案 | top-1 | top-3 | 结论 |
|---|---|---|---|
| 当前 `deepseek-flash` + 37 类目录 | ~10/18 | ~11/18 | 可用但不稳定 |
| Prompt 短名单 + 标签读数 | ~10/18 | ~11/18 | 提升有限 |
| 参考图网格 few-shot | 7/18 | 7/18 | 不采用 |
| 公开数据集 MobileNet 线性探针 | 2/18 | 4/18 | 产品图与真实健身房差异太大，不采用 |
| CLIP 线性探针（每类 10 张） | 0/18 | 4/18 | 数据太少，不采用 |

主要失败类型：

- 推胸机 / 推肩机 / 蝴蝶机 / 侧平举机互相混淆
- 龙门架前方有训练凳或背景器械时，模型看错主体
- 椭圆机 / 健身车 / 爬楼机混淆
- 山羊挺身 / 高位下拉 / 坐姿划船混淆

结论：**`deepseek-flash` 是当前准确率上限**。继续调 prompt 的收益已经很小，
下一档提升需要换更强的视觉模型（Qwen-VL / Doubao Vision / GPT-4o 级）或
用真实健身房照片重新训练专用分类器/检测器。

## 4.2 已落地的补充：设备端 OCR 标签

很多机器有 `SHOULDER PRESS`、`LATERAL RAISE`、`推胸训练器`、
`大腿外展训练器` 等标签。iOS 现在用 Vision OCR 先读图上的文字，随图片一起
上传；后端把它作为强证据放进视觉 prompt：

```text
OCR 在图片上读到的文字：SHOULDER PRESS Life Fitness
OCR 匹配提示：shoulder_press_machine（推肩机）
如果文字属于画面主体器械，优先考虑；如果属于背景器械，忽略。
```

生产烟测：

```text
SHOULDER PRESS 标签 → shoulder_press_machine 0.92
CHEST PRESS 标签    → chest_press_machine    0.93
```

这条链路不增加模型成本，对带标签的器械提升明显；没有标签的器械仍依赖视觉模型。

## 4.3 生产视觉模型切换：Qwen3-VL-Plus（2026-11-08）

生产视觉识别已从 `deepseek-flash` 切到 **Qwen3-VL-Plus**，文本教练/计划仍用
DeepSeek：

```env
VISION_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
VISION_MODEL=qwen3-vl-plus
VISION_API_KEY=仅写入服务器 /opt/fitai/.env，不入库
LLM_MODEL=deepseek-flash
```

- 阿里云百炼控制台可能把 `qwen3-vl-plus` 收进历史模型/不展示，但 API 的
  `/compatible-mode/v1/models` 仍返回该模型，实际可调用。
- 生产 `/health` 返回 `vision: qwen3-vl-plus`。
- 生产烟测：
  - 数据集推肩机图 + `SHOULDER PRESS` → `shoulder_press_machine` 0.95
  - 数据集推胸机图 + `CHEST PRESS` → `chest_press_machine` 0.95
- 低分辨率 contact-sheet 缩略图（360px）测试结果不稳定，例如椭圆机/腿举、
  哈克/髋外展会互相混淆；这些缩略图不能代表手机原图，需用高分辨率实拍复测。
- 价格：北京地域 0–32K 输入约 1 元/百万 token、输出 10 元/百万 token；
  一次扫描约 2.3k 输入 + 130 输出，约 0.004 元。
- 下一步：用 30–50 张高分辨率真实照片做 A/B，确认 top-1/top-3；如果 Qwen
  仍不够，再考虑 `qwen3.8-max` / `qwen3.7-plus` 或专用检测器。

## 5. 仍未完成

- iOS CI 编译已通过（`iOS Build` success @ `23e41c8`）；真机相机/相册 HEIC/大图/
  弱网仍需 Mac 验证。
- 更强视觉模型：`qwen3-vl-plus` 已接入生产；`qwen3.8-max` / `qwen3.7-plus`
  作为高精度备选，需用同一批高分辨率照片 A/B。
- 真实数据闭环：建议每类收集 100+ 张真实健身房照片，训练检测器/分类器；
  公开产品图数据集（HF `suc1dalspinach/Gym_machines_Image_dataset`，MIT）
  与真实场景差异较大，直接线性探针效果差。
- 更细的器械分类：史密斯机 vs 普通深蹲架、蝴蝶机 vs 反式蝴蝶机、
  不同品牌的腿举/哈克一体机。
- 多候选确认：当 top-2 接近时，UI 应显示“最可能 A / 也可能是 B”，让用户选。
- 评测集：继续补充多品牌真实照片，记录 top-1/top-3/未识别率。
- 更多动作库：当前 57 条覆盖常见商业健身房；1,213 / 1,500 条全量仍需映射。

## 6. 验收

- 任意图片不再返回随机动作。
- 视觉失败有明确提示和重试入口。
- 常见器械能返回器械名 + 1–3 个动作候选。
- 多用途器械返回多个动作，不强行只给一个。
- 动作库 slug 与 iOS 当前 57 条一致。
- 器械、身体、饮食三条拍照链路都能接受 HEIC/JPEG/PNG/WebP。
