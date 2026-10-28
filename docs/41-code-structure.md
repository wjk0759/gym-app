# 代码结构与复用约定

这份文档记录 2026-10 的第一轮结构优化，避免新功能继续堆回几个超大文件。

## 网络层

- `APIModels.swift`：服务端 DTO，只描述协议形状，不包含请求逻辑。
- `APITransport.swift`：URL 拼接、鉴权头、401 刷新、超时、错误转换、解码。
- `APIDateCoding.swift`：服务端日期格式的唯一入口。
- `MultipartFormData.swift`：单图/多图上传共用的 multipart 编码。
- `APIClient.swift`：业务端点，只负责 payload 和调用 transport。

新增接口时：

1. DTO 放 `APIModels.swift`。
2. 端点放 `APIClient.swift`（后续可按 capability 拆 extension）。
3. 不要在端点里直接写 `URLSession`、日期格式或 multipart 边界。
4. 相同 payload 形状抽成一个 builder，例如训练记录的 `workoutPayload`。

## AppStore

`AppStore.swift` 只保留：

- 存储状态与生命周期
- 跨域编排
- 持久化/同步
- 确实无法归属到单一能力的逻辑

领域能力放 extension：

- `AppStore+Derived.swift`：只读派生状态
- `AppStore+Nutrition.swift`：饮食记录
- `AppStore+Equipment.swift`：个人器械库
- `AppStore+BodyAnalysis.swift`：体型分析应用
- `AppStore+Coach.swift`：教练结果写回

规则：

- 新的领域行为优先加到对应 extension，不继续膨胀主文件。
- extension 不应依赖其他文件的 `private` 成员；需要共享的内部能力显式改成模块内可见，并写清楚原因。
- 跨领域编排仍留在 `AppStore.swift`，避免 extension 之间互相调用形成隐式环。

## 教练 UI

- `CoachComponents.swift`：
  - `CoachCard`
  - `CoachCardHeader`
  - `CoachInlineBanner`
  - `CoachLoadingLabel`
  - `CoachQuickActionButton`
  - `CoachChatBubble`
- `CoachAttachmentPolicy.swift`：附件数量/大小规则与错误文案。
- `CoachAttachmentDraftBar.swift`：待发送附件展示，只接收数据和回调。
- `CoachAttachmentDraft.swift`：暂存图片模型。
- `CoachImageViews.swift`：气泡内图片/视频缩略图与缓存。

规则：

- 新能力卡先复用 `CoachCard` 和 `CoachCardHeader`，不要复制 padding/圆角/描边。
- 重试、撤销这类“一行提示 + 一个动作”统一用 `CoachInlineBanner`。
- 附件限制只在 `CoachAttachmentPolicy` 里改，视图不要再写 6 / 8MB / 24MB。
- 纯规则优先写成无 SwiftUI 依赖的类型，方便单测。

## 验证

- Swift 语法：tree-sitter（本机无 Xcode 时的最低检查）。
- iOS 真机编译：Mac 上 `cd ios && xcodegen generate` 后用 Xcode 构建。
- 后端：`ruff check app tests scripts`、`pytest -q`。
- 新增纯规则时补 `FitAITests`，例如 `CoachAttachmentPolicyTests`。
