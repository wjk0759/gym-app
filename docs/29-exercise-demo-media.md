# 29 · 动作演示素材接入（MoveKit 免费示例）

## 1. 当前状态

已接入 MoveKit 免费示例的 2 个动作，用于本地评估：

| FitAI 动作 | MoveKit 示例 | 文件 |
|---|---|---|
| `pullup` / 引体向上 | Pull Ups | `pull-ups.mp4` |
| `dumbbell_fly` / 哑铃飞鸟 | Dumbbell Chest Fly | `dumbbell-chest-fly.mp4` |

示例 MP4 和海报**没有提交到仓库**，脚本会下载到本地被忽略的
`backend/media/exercises/movekit/`，并写入已发布的 `exercise_videos` 记录。

## 2. 安装与查看

从仓库根目录执行：

```powershell
backend\.venv\Scripts\python.exe tools\media\install_movekit_sample.py
```

脚本会自动下载 MoveKit 免费 sample、校验 SHA-256、复制视频和海报，并更新
`pullup`、`dumbbell_fly` 两个动作的官方视频记录。

查看接口：

```text
http://127.0.0.1:8000/api/v1/videos/pullup
http://127.0.0.1:8000/api/v1/videos/dumbbell_fly
```

在 iOS 的「动作详情」页打开「引体向上」或「哑铃飞鸟」，会通过现有
`officialVideoURL` 流程加载循环视频。当前播放器是 `AVPlayer`，视频本身是
H.264 MP4，适合 App 内播放。

Windows 上也可以直接打开 `preview/movekit-demo.html`，它会在浏览器里循环播放
两条示例（需要 FastAPI 运行在 `:8000`）。

评估完成后清理：

```powershell
backend\.venv\Scripts\python.exe tools\media\install_movekit_sample.py --remove
```

## 3. 为什么先用 MoveKit

- 500+ 个统一灰色 3D 人体模型动作，和很多健身 App 的视觉风格接近
- Gym Pack 424 个、Complete Pack 582 个，覆盖固定器械和自由重量
- 一次性购买，允许在 App 中商用和自托管
- 循环 MP4，当前 iOS `AVPlayer` 和 Web `/media` 流程可以直接使用
- 免费 sample 与付费包使用相同 schema，后续替换文件即可

价格参考（以官网实时显示为准）：

- 单个动作：约 ¥19
- Gym Pack：约 ¥879 / 424 个
- Complete Pack：约 ¥1099 / 582 个

## 4. 验收重点

1. 动作起始和结束是否自然，循环播放是否有明显跳帧；
2. 3D 人体风格是否符合 FitAI 的深色界面；
3. 手机弱网下首帧和播放是否流畅；
4. 视频加载失败时是否回退到动作说明，不影响训练；
5. 素材授权是否覆盖正式 App、CDN 和未来付费功能。

## 5. 购买前建议

先用免费 sample 在 Mac/iPhone 上实际看一次「引体向上」和「哑铃飞鸟」。
如果风格和播放体验可以接受，再购买 Gym Pack；如果只想覆盖当前 80 个动作，
也可以按单个动作购买，但通常 Gym Pack/Complete Pack 更划算。

后续正式接入建议：

- 视频放到 OSS/CDN，`exercise_videos.video_url` 使用稳定 URL；
- 保存 `source`、`license_note` 和购买凭证；
- 海报作为首帧，视频懒加载；
- 不在 App 包里打包全部视频，按动作下载或流式播放。
