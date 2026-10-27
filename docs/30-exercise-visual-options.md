# 30 · 动作演示视觉方案对比

## 1. RepDB Free（当前最推荐的低成本方案）

- 仓库：<https://github.com/RepDB/exercise-dataset>
- 免费版：701 个动作，512×512 WebP 平面插画
- 每个动作通常有 `start` 和 `peak` 两张图，可做双帧切换或淡入淡出
- 数据包含目标肌群、器械、MET、英文/德文/西班牙文说明
- 许可：**免费用于个人和商业 App**，但必须显示
  **“Exercise data by RepDB (repdb.co)”** 链接；不能把数据集重新打包成数据集/API 再分发
- 付费版：Stills $299（701 张静态图）；Standard $499（含 544 个循环动画、肌肉高亮；一次性付款）
- 适合 FitAI 的地方：固定器械动作覆盖明显比 Workout Guide 更全，画风更像普通健身 App
- 限制：免费版不是动画，需要自己用两张图做轻微切换；中文名称和说明要自己补

本地预览：

```text
preview/repdb-demo.html
```

## 2. `@bryllim/workout-guide`

- 仓库：<https://github.com/bryllim/workout-guide>
- 规模：302 个动作，每个动作 3 帧，共 906 张透明 PNG/SVG
- 风格：白色线稿人体，不是 3D；适合做轻量动作卡、列表缩略图或 3 帧循环
- 接入：npm 包 `@bryllim/workout-guide`，框架无关，提供 React Native/Expo 的资源导入说明
- 许可：代码 MIT；视觉素材 **CC BY-SA 4.0**，需要署名、链接许可，改编素材按相同许可共享
- 体积：npm tarball 约 30MB，当前版本 1.0.0
- 优点：免费、统一、无需 3D 引擎、加载轻
- 限制：只有三帧，不能像视频一样连续；风格与 MoveKit 的灰色 3D 人体差异明显

本地预览：

```text
preview/workout-guide-demo.html
```

## 3. Three.js / model-viewer / SceneKit / RealityKit

这是一组渲染技术，不是动作内容库：

| 技术 | 平台 | 作用 | 是否自带动作 |
|---|---|---|---|
| Three.js | Web / React Native WebView | 加载 glTF/GLB、播放骨骼动画、相机交互 | 否 |
| `<model-viewer>` | Web | 最简单的 glTF/USDZ 展示组件 | 否 |
| SceneKit | iOS/macOS | Apple 原生 3D 场景 | 否，且新项目更推荐 RealityKit |
| RealityKit | iOS/macOS/visionOS | Apple 现代 3D/AR 渲染和动画 | 否 |

要显示卧推、器械推胸等动作，必须另找或制作：

1. 带骨骼的 3D 人体模型；
2. 每个动作的骨骼动画；
3. 动作与器械、肌群、中文说明的映射；
4. 授权和体积管理。

### 当前可用的演示资产

`shlomorsh/desk-break` 提供了 **435 个 MIT 授权的木人偶 GLB 动画**，适合验证 Three.js/RealityKit 的渲染和交互，但它主要是桌面拉伸、瑜伽、低冲击动作，**不是健身房器械动作**，不能直接当作 FitAI 的卧推/推胸动画库。

本地预览：

```text
preview/threejs-demo.html
```

预览页从 CDN 加载 `exercises.glb`，支持旋转、缩放、切换动画；它证明“渲染器可用”，同时说明“内容仍要单独解决”。

## 4. 其他免费/低成本来源

| 来源 | 内容 | 授权 | 评价 |
|---|---|---|---|
| [free-exercise-db](https://github.com/yuhonas/free-exercise-db) | 873 个动作、英文说明、2 张 JPG/动作 | 文本 Unlicense；图片来源和再分发需单独核实 | 数据很全，但图片不是统一插画，且图片授权不如文本清晰 |
| [wger](https://github.com/wger-project/wger) | 939 个动作、约 374 张图片、约 78 个视频 | CC BY-SA；自托管 | 数据开放，但媒体覆盖稀疏，整理成本高 |
| ExerciseDB / Gym visual | 1,500+ GIF / 视频 | 商业授权；免费层/样例限制多 | 视觉成熟，但完整商用要付费，不能当作免费来源 |
| [Desk Break](https://github.com/shlomorsh/desk-break) | 435 个 GLB 拉伸/瑜伽/低冲击动画 | MIT | 适合做 3D 技术验证，不适合健身房器械动作 |
| Pexels / Pixabay / StockSnap | 通用健身视频和照片 | 免费授权 | 不是按动作整理的，难以稳定对应 80 个动作 |

## 5. 结论

对 FitAI 当前以固定器械为主的 80 个动作：

1. **低成本首选 RepDB Free**：701 个动作、固定器械覆盖好、免费商用；需要署名，接受平面插画风格即可。
2. **备选 Workout Guide**：302 个动作、3 帧线稿，风格更“说明书”，适合缩略图或轻量动画。
3. **要真正的 3D 动画，MoveKit 仍最省事**：免费 sample 已验证，正式 Gym Pack 约 ¥879、Complete Pack 约 ¥1099，一次性购买。
4. **不建议现在自建 Three.js/RealityKit 动作库**：渲染不难，难的是 80–400 个准确、统一、授权的动作动画；成本远高于购买现成素材。
5. 如果未来只做少量“重点动作”的交互式 3D，可以在 RealityKit/Three.js 里单独做 3–5 个 hero 动作，不必全量迁移。
