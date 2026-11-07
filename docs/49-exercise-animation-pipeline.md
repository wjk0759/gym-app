# 49 · iPhone / Watch 动作演示素材管线

> 2026-11-07：先用 VitalAnimations 免费 sample 打通 iPhone 训练页循环动画、
> 批量媒体接口和 Watch 复用。正式 1,500 动作 × 男女两套仍待购买与映射。

## 1. 目标

- iPhone 训练页和 Apple Watch 使用同一批动作素材。
- 一套媒体元数据，按用户性别解析：
  - 先取同性别版本；
  - 没有同性别时取 `unisex`；
  - 最后才回退到另一性别，避免完全无图。
- 不伪造动画：素材缺失时只显示动作文字/海报，不显示假动作。
- 视频静音、循环、不打断用户音乐。

## 2. 数据表

沿用 V23 的 `exercise_media_assets`：

| 字段 | 用途 |
|---|---|
| `exercise_slug` | 动作 slug，外键到 `exercises.slug` |
| `sex` | `male` / `female` / `unisex` |
| `phone_url` | iPhone 720p 循环 MP4 |
| `watch_url` | Watch 480p 循环 MP4 |
| `poster_url` | 首帧/海报 JPEG |
| `duration_seconds` | 整数时长 |
| `loop_start_ms` / `loop_end_ms` | 循环区间元数据 |
| `watch_sha256` | Watch 文件校验 |
| `version` | 同一动作/性别可多版本，取最新 |
| `status` | 只有 `published` 对客户端可见 |
| `license_note` | 素材授权说明 |
| `purchase_ref` | 购买凭证/订单号，正式素材必填 |

URL 可以是 `/media/...` 相对路径；iPhone 用
`AppConfig.resolveMediaURL`，Watch 用 `RemoteWatchMedia.asset(resolvingAgainst:)`
补全为 API 域名。

## 3. 后端接口

### 3.1 iPhone 批量查询

```http
GET /api/v1/exercise-media?slugs=squat,hip_thrust,leg_press
Authorization: Bearer <access_token>
```

- 一次最多 20 个 slug；超过返回 400。
- 重复 slug 自动去重。
- 只返回 `status=published` 的最新版本。
- 按当前用户 `profiles.sex` 做性别匹配。
- 响应：

```json
{
  "items": [
    {
      "exercise_slug": "squat",
      "sex": "male",
      "phone_url": "/media/exercises/vital/squat/male-phone.mp4",
      "watch_url": "/media/exercises/vital/squat/male-watch.mp4",
      "poster_url": "/media/exercises/vital/squat/male-poster.jpg",
      "duration_seconds": 6,
      "loop_start_ms": 0,
      "loop_end_ms": 6250,
      "sha256": "...",
      "version": 1
    }
  ]
}
```

### 3.2 Watch

`/watch/bootstrap` 复用同一个 resolver，媒体数组仍在 `media` 字段：

```json
{
  "media": [
    {
      "exercise_slug": "squat",
      "watch_url": "/media/exercises/vital/squat/male-watch.mp4"
    }
  ]
}
```

## 4. iPhone UI

- 位置：当前动作标题/目标之后、组数输入之前。
- `ExerciseAnimationCard`
  - 静音、自动循环、无系统播放控件；
  - 白色素材面板，跟随当前素材的浅色背景；
  - 点击进入全屏；
  - 加载中先显示海报；
  - 失败时回退到海报或「动作演示准备中」；
  - Reduce Motion / 非 active 场景显示海报并暂停。
- `ExerciseMediaStore`
  - 训练开始一次性预取当天全部动作；
  - 切换动作直接读内存缓存；
  - 网络失败不阻塞训练，前台恢复时重试。
- `SilentLoopingVideoPlayer`
  - `AVPlayerLayer` + `AVPlayerLooper`；
  - `AVAudioSession` 使用 `.ambient` + `.mixWithOthers`，不打断用户音乐；
  - 视图销毁时停止播放并释放 looper。

## 5. 素材构建脚本

`tools/media/build_vital_sample.py`：

```powershell
$env:FFMPEG_BIN = "<ffmpeg.exe>"
backend\.venv\Scripts\python.exe tools\media\build_vital_sample.py `
  --source "C:\Users\<user>\Downloads\VitalAnimations (1)\VitalAnimations" `
  --sql-out backend\media\exercises\vital\insert.sql
```

输出：

```text
backend/media/exercises/vital/<slug>/male-phone.mp4   720p H.264, 30fps
backend/media/exercises/vital/<slug>/male-watch.mp4   480p H.264, 24fps
backend/media/exercises/vital/<slug>/male-poster.jpg  720p JPEG
backend/media/exercises/vital/manifest.json
backend/media/exercises/vital/insert.sql
```

`backend/media/` 已被 `.gitignore` 忽略，原始 1080p 和转码文件都不入库。

## 6. 当前免费 sample 的映射

只发布动作完全一致的样本：

| 动作 slug | 素材 | 性别 |
|---|---|---|
| `squat` | Free50 0054 barbell back squat | male |
| `hip_thrust` | Free50 0057 barbell hip thrust | male |
| `romanian_deadlift` | Free50 0060 barbell romanian deadlift | male |
| `goblet_squat` | Free50 0064 dumbbell goblet squat | male |
| `leg_press` | Free50 0074 leg press machine | male |
| `rowing_machine` | Free50 0077 rowing machine | male |
| `triceps_pushdown` | Free50 0085 triceps pushdown (rope) | male |
| `treadmill_walk` | Free50 0086 walk on treadmill | male |
| `shoulder_press` | Free50 0090 dumbbell overhead | male |
| `lateral_raise` | Free50 0096 lateral raises (dumbbell) | male |
| `crunch` | Character Samples 0473 | female |

样例素材是白底灰色 3D 人体；`crunch` 是女性红色肌肉高亮，风格和 Free50 不同，
仅用于验证性别匹配和播放链路。

## 7. 生产状态（2026-11-07）

- 11 条 `published` 记录已写入生产 `exercise_media_assets`。
- 文件已上传到 `/opt/fitai/media/exercises/vital/`。
- `/exercise-media` 已部署，`test_reviewer` 返回 4 条（squat / hip_thrust /
  leg_press / crunch）。
- `/watch/bootstrap` 已返回 `crunch` 媒体。
- 媒体 HTTP 支持 Range，返回 206，可渐进播放/循环。
- 后端：211 tests passed，Ruff 通过。
- GitHub Actions：`Backend Tests` success @ `341981f`；`iOS Build` success @
  `341981f`。

未验证：

- 真机 iPhone 内嵌循环、全屏、Reduce Motion、音乐不中断。
- 真机 Watch 下载/播放/排队。
- 弱网、离线、切后台/回前台。
- `test_reviewer` 当前计划只含 `crunch` 匹配；要验证 squat/leg press 等，
  需生成含器械动作的计划或换测试账号。

## 8. 正式素材购买后的工作

1. 确认 VitalAnimations Complete 的 1,500 是动作数还是动画条数。
2. 确认每个动作是否都有 male + female，是否包含肌肉高亮。
3. 确认授权允许 App 内使用、自托管 CDN、转码、Pro 功能。
4. 用同一脚本扩展映射，源文件只保留在本地/NAS，不入库。
5. 先映射当前动作库，再生成覆盖率报告：
   - 完全匹配；
   - 变式复用（UI 标「近似示范」）；
   - 无匹配。
6. 批量转码、上传、按 `exercise_slug + sex + version` 写表。
7. 先灰度 20–50 个高频动作，再全量。

当前生产库只有 27 个旧 seed 动作，iOS 动作库已切到 57 个训记动作；
在铺 1,500 条素材前，需要先决定是否把完整训记动作库导入生产
`exercises` 表，否则媒体外键无法覆盖 iOS 新动作。
