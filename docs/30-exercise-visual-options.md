# 30 · 动作演示视觉方案对比

## 1. `@bryllim/workout-guide`

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

## 2. Three.js / model-viewer / SceneKit / RealityKit

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

## 3. 结论

对 FitAI 当前以固定器械为主的 80 个动作：

1. **首选仍是 MoveKit 的 3D MP4**：已有免费 sample 接入，风格统一、可直接播放。
2. **Workout Guide 适合做低成本补充**：如果不想为每个动作购买视频，可以用三帧线稿做动作卡/离线占位。
3. **不建议现在自建 Three.js/RealityKit 动作库**：渲染不难，难的是 80–400 个准确、统一、授权的动作动画；成本远高于购买现成视频。
4. 如果未来只做少量“重点动作”的交互式 3D，可以在 RealityKit/Three.js 里单独做 3–5 个 hero 动作，不必全量迁移。
