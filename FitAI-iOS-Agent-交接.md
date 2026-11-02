# FitAI 交接给 iOS / OpenCode Agent

> 目标：在 `develop` 的基础上继续完成 Pro、试用、付费墙、滑动会话、防滥用和模块化收尾。
>
> 原则：服务端是权限唯一来源；客户端只负责展示与交互。不要为了“做完”伪造外部验收，不要把新代码堆成屎山。

---

## 1. 当前工作区与状态

- 仓库：`E:\Projects\FitAI`
- 分支：`develop`（`feat/pro-access-trial-2026-11` 已合并）
- 合并提交：`afd4afc feat(api): serialize agent turns per user`
- 工作区：干净
- 已同步 `develop`；正式发布前仍需真实数据库和真机验收

> 2026-11-02 本地 Agent 进展：从 `develop` 新建 `feat/pro-access-followup-2026-11`，
> 未合并回 `develop`。本次完成 App Store Server API 本地实现、拍照幂等缓存、
> 设备会话兼容/客服文档、SwiftLint CI 与三机型模拟器截图；iOS 单元测试 29 个全部通过，
> SwiftLint 0 violation。外部凭据/真机项标 BLOCKED。

最近 CI：

- Backend Tests #102：✅ `afd4afc`
- iOS Build #224：✅ `314cd49`（之后的提交只改后端/文档）
- Admin CI #27：✅ `296b3eb`（之后的提交只改后端/iOS/文档）

当前运行中的开发环境：

- MySQL 8（Docker）：`127.0.0.1:3307`，健康
- FastAPI：`http://127.0.0.1:8000`
- Admin Server：`http://127.0.0.1:8080`
- 后台页面：`http://127.0.0.1:5173/admin/`
- 后台账号：`admin`，密码见 `deploy/admin/.env` 的 `FITAI_BOOTSTRAP_PASSWORD`
- 开发库已实际执行 Flyway V14–V20
- 回填核对：7 个已引导用户对应 7 个训练试用；4 个饮食周计划对应 4 个饮食试用

测试账号：

- 用户 ID：`05cdf2e3-eb7e-46ed-aef0-4378911b78d8`
- 已标记 `is_test=true`
- 已授予 30 天 Pro，当前到期约 `2026-12-02`
- 后台真实登录、授予、延长、撤销、审计已在本机验证过

---

## 2. 已经完成，不要重做

### 权益与收费
- `user_entitlements`、`feature_trials`、`feature_usage`
- 训练计划 onboarding 一次性试用；后续生成/调整/下周期 Pro
- 饮食周计划和单日计划共用一次免费体验；后续 Pro
- AI 教练 3 条/周；安全/医疗回复不占额度、不弹付费墙
- 饮食拍照、身材拍照、教练视觉/视频分析 Pro 直拦
- 高级周复盘 Pro
- 计划调整、Agent 草案应用、周复盘已补服务端 Pro 拦截
- 客户端统一 `FeaturePolicy` / `FeatureAccessStore` / `ProPaywallCoordinator`
- `AppStore.paywallFeature` 已移除

### StoreKit
- 客户端购买/恢复后把 Apple JWS 同步到 `POST /me/storekit/transactions`
- 服务端校验证书链、Apple Root CA G3 指纹、ES256、Bundle ID、商品、环境、有效期、退款/撤销
- 交易必须绑定当前账号的 `appAccountToken`
- `POST /iap/app-store/notifications` 已支持退款、撤销、续订，续订支持通过 `appAccountToken` 找回账号
- 已用合成 Apple 证书链补 JWS 验签、过期、撤销、续订绑定测试

### 防滥用
- `feature_generation_state`：服务端冷却、并发 1、幂等回放
- V20 支持按功能冷却：计划/饮食 60 秒，拍照/视觉 5 秒
- V18 `rate_limit_buckets`：数据库 token bucket，多 worker 共享
- 计划、饮食、拍照、教练文本、Agent 都有并发保护
- AI 全局日/月 token 预算，70/90% 告警，100% 自动降级
- V19 `ai_runtime_control`：后台暂停/恢复 AI，测试账号白名单
- 同设备重登撤销旧会话、单账号最多 5 个活跃设备、异常多账号/批量 IP 登录写 `auth_events`
- Refresh 复用/设备不匹配写告警和事件

### 客户端与后台
- AppStore 已拆 `AppStore+Sync`、`AppStore+Agent`、`FeatureAccessStore`
- PlanHistory、PlanHomeTrainingData、CoachChatActionCards 已拆出
- 教练输入栏显示每周额度
- 后台用户列表支持测试账号筛选
- 后台 AI 用量支持 token、运行开关、暂停原因
- 结构化错误 `PRO_REQUIRED` / `COACH_QUOTA_EXHAUSTED` / `RATE_LIMITED` / `GENERATION_*`
- iOS 已解析 `APIError.code`、`retry_after`，429 不再一律弹付费墙

---

## 3. 用户的质量要求

用户原话：

> 多用高级语法，尽量少用判断语句。

落实标准：

1. **Swift**
   - 优先 `guard`、`switch`、模式匹配、`Optional.map/flatMap`、`Set`、`async let`、`TaskGroup`、`@Observable`、值类型。
   - 少写多层 `if let ... { if ... { } }`；先提前返回，再处理主路径。
   - View 只做展示和交互，不直接调 `APIClient`，不写业务计算。
   - 新逻辑优先放 service/store/coordinator；依赖通过参数或 environment 注入。
   - 不要用 `try?` 吞掉用户能感知的错误；该提示就提示，该记录就记录。

2. **Python**
   - 用 early return、dataclass、context manager、推导式、`match`、依赖注入。
   - 不在事务里调用 LLM/短信/天气。
   - 新错误必须结构化；不要新增裸字符串业务错误。
   - 新 service 不要内部随手 `commit()`，事务边界放在 router 或明确的服务方法。

3. **通用**
   - 禁止重复序列化、重复查询、重复 UI 组件、重复常量。
   - 禁止 God object、超大函数、魔法数字、死代码。
   - 每完成一项都要自查：是否符合周边风格？是否能更简单？是否引入新耦合？
   - 注释只写“为什么”，不要写显而易见的“做了什么”。
   - 不提交 `.env`、密钥、`smoke.db`、媒体文件。

---

## 4. 待完成项（按优先级）

### P0 收费与外部验收

- [x] **App Store Server API 校验与定期订阅对账（本地实现完成；真实调用 BLOCKED）**
  - 已实现 `backend/app/services/app_store_api.py`、`POST /iap/app-store/reconcile`、`scripts/reconcile_storekit.py` 与 mock 测试。
  - 真实 Apple 请求 BLOCKED：缺少 App Store Connect 的 Key ID、Issuer ID、p8 私钥。
  - 建议新增 `backend/app/services/app_store_api.py`：
    - 生成 ES256 JWT（`aud=appstoreconnect-v1`，`bid` 为 Bundle ID）
    - 查询 `/inApps/v1/subscriptions/{transactionId}`
    - 用现有 `app_store.verify_signed_transaction` 校验返回的 JWS
    - 写 `user_entitlements`，幂等
  - 未配置密钥时返回 503 + 明确错误码，不要伪造成功。
  - 增加后台或定时任务入口做对账；不要把长 HTTP 调用放进数据库事务。
  - 用 mock HTTP 补测试；真实调用等凭据。

- [ ] **BLOCKED · App Store Connect 配置 Notifications V2 URL**
  - 缺少 App Store Connect 权限和可公网访问的域名/隧道；本地 webhook 代码已存在并有验签测试。
  - URL：`https://<你的域名>/api/v1/iap/app-store/notifications`
  - 本地验证可用隧道；真实配置需要 App Store Connect。
  - 验证退款、撤销、续订、订阅成功事件都能更新台账。

- [ ] **BLOCKED · TestFlight / StoreKit 沙盒真实购买、恢复、退款**
  - 缺少真实 Apple 账号、App Store Connect 商品和 TestFlight 环境。
  - 购买后确认：
    - 客户端拿到 verified transaction
    - 服务端 `/me/access` 变 Pro
    - 退款/撤销后变免费
    - 恢复购买能重新同步
  - 需要真实 Apple 账号和 App Store Connect 商品配置，不能本地伪造。

- [ ] **BLOCKED · 给测试账号 30 天 Pro 真机端到端验证**
  - 真机 `Wu-Tang` 已配对且 DDI 可用，但本机 Xcode 未登录 Apple ID、无开发证书，无法签名安装。
  - 测试账号已设置，见第 1 节。
  - 真机验证免费体验、付费墙、AI 额度、StoreKit 购买、恢复、退款。

- [ ] **BLOCKED · V14–V20 在预发/生产 MySQL 执行并核对回填**
  - 缺少预发/生产 MySQL 连接与 Flyway 权限；本次只新增了 V21 迁移，未在生产执行。
  - 开发库 3307 已完成，不要重复改开发库。
  - 预发/生产只通过 Flyway 执行，不手工改表。
  - 核对 `feature_trials` 与历史 onboarded/meal week 数量。

### P1 iOS 收费体验

- [x] **拍照分析幂等键**
  - 已实现 `feature_result_cache` V21 + `photo_cache` 服务，覆盖体型、饮食、器械、教练视觉；只缓存脱敏 JSON 文本，TTL 300 秒，不落原图。
  - 客户端在体型/饮食/器械/教练视觉请求带 `Idempotency-Key`；免费用户仍先过 Pro 校验并返回 403。
  - 服务端已有同用户并发 1 和 5 秒冷却，现在同 key 重试会返回同一份结果。
  - 如果实现真正幂等：
    - 不落原图
    - 只缓存脱敏后的文本结果，TTL 很短（例如 5 分钟）
    - 同 key 重试不再次调用视觉模型
    - 免费用户仍然 403
    - 清理策略和隐私说明要同步更新
  - 如果决定不做结果缓存，要在文档里明确：并发锁 + 冷却已覆盖防重复扣费，不能假装有幂等回放。

### P2 防滥用与成本

- [ ] **BLOCKED · App Attest / DeviceCheck**
  - 需要 Apple 团队配置、App Attest capability 和真机；未编写未经验证的声明式接口，避免假装上线。
  - 不要在未验证的情况下声称已上线。
  - 建议先设计 challenge/attestation 接口和开关，默认关闭。

- [ ] **BLOCKED · 重复提示词、批量注册的后台筛选与告警看板**
  - 本机没有 Java/Node/admin 测试数据库，无法运行 admin-server/admin-web；本次未改后台代码。
  - 检测而不是直接封禁；家庭共享设备/运营商 NAT 会误报。
  - 后台可按设备、IP、提示词 hash、时间窗筛选。
  - 所有处置必须写审计日志。

- [ ] **DEFERRED · Redis 可选后端（非阻塞）**
  - 按文档只有吞吐成为瓶颈时再接；当前数据库 token bucket 已支持多 worker，本次不引入新依赖。
  - 只有吞吐成为瓶颈时再接 Redis；不要让 Redis 成为单点依赖。

### P3 滑动会话

- [ ] **BLOCKED · 真机测试**：并发 401、断网、刷新响应丢失、旧 refresh token 复用、多设备同时在线。
  - 后端单元测试已覆盖刷新轮换宽限、旧 token 复用撤销、设备不匹配、最大设备数；真机需要可签名安装。
- [x] **设备 ID 缺失/变更的兼容策略与客服路径**
  - 新增 `docs/46-device-session-support.md`，写明兼容策略、`auth_events` 排查和客服撤销 SQL。
  - 旧客户端缺少 `X-Device-ID` 时兼容放行，并补了后端测试。
  - 客户端收到 401/403 刷新拒绝时清除 token、发出 `.fitaiSessionExpired` 并回到登录页，不静默丢本地数据。

### P4 模块化与大文件拆分

- [x] `AppStore` 剩余 Plan / Nutrition / Workout / Profile 子域拆分
  - 已抽出 `PlanGenerationService`、`WorkoutSyncService`、`NutritionService`；Profile/Plan/Workouts/Settings/Export 方法拆到 extension，主文件只保留状态、生命周期与持久化，已低于 lint 阈值。
  - 已拆：Sync、Agent、Access
  - 目标：AppStore 只做状态容器和协调，不继续长成 God object

- [x] 抽 `PlanGenerationService`：远程/本地生成已下沉到 `Core/Services/PlanGenerationService.swift`
- [x] 抽 `WorkoutSyncService`：API 调用与远端映射已下沉；合并策略仍留在 `AppStore+Sync`
- [x] 抽 `NutritionService`：饮食记录同步与远端映射已下沉到 `Core/Services/NutritionService.swift`
- [x] 拆 `PlanHomeView`
  - 已拆：History、TrainingData；Header、QuickActions、MonthCover、Calendar、SelectedDay、Plan/Empty、Data 拆到 7 个 extension 文件
- [x] 额外拆分 `WorkoutDetailView`：只读摘要/动作卡拆到 `WorkoutDetailCards.swift`，移除该文件 lint 豁免
- [x] 额外拆分 `EquipmentPickerView`：动作卡/选择控件/肌群图标拆到 `EquipmentPickerCards.swift`，移除该文件 lint 豁免
- [x] 额外拆分 `HomeV2View`、`SettingsView`、`LoginView`、`CoachChatView`、`NutritionView`、`ProgressOverviewView`、`WorkoutHistoryView`：按 extension 拆分，代码中已无 lint 豁免
- [x] 额外拆分 `AppStore`：Profile / Plan / Workouts / Settings / Export 方法拆到 extension；Agent 拆 Chat/Actions
- [x] 拆 `CoachOnboardingView`：已按 Layout / Steps / Report / Components / Derived 拆到 5 个 extension 文件
- [x] 拆 `WorkoutSessionView`：Header / 动作卡 / SetCard / Rest / ActionBar / Summary / 输入弹窗拆到 `WorkoutSessionComponents.swift`
- [x] 拆 `EquipmentDetailView`：Media / Points / Stats / Hero 拆到 4 个 extension 文件，Stats 类型独立
- [x] 拆 `Models.swift`：按 Profile / Training / Nutrition / Equipment 四个文件拆分
- [x] 按需拆 Nutrition / Settings / Progress / HomeV2 / EquipmentLibrary / Login
  - Settings/HomeV2/Login/Nutrition/Progress/EquipmentLibrary 等均已完成拆分；当前 SwiftLint 0 violation。
- [x] iOS 单元测试修复：`PRODUCT_NAME` 补到测试 target；`PlanGeneratorTests` 改为验证当前 `PlanGenerator.adjustment` API，29 个测试全部通过
- [x] SwiftLint：
  - `file_length` warning 600 / error 1000
  - `type_body_length` warning 400 / error 600
  - 已加 `.swiftlint.yml` 和 iOS CI 检查
  - 现有大文件已完成拆分，代码中不再有 `swiftlint:disable file_length type_body_length`；本地 lint **0 violations**
- [x] 新 View 禁止直接调用 `APIClient`；权益判断禁止写在 View
  - `ios/FitAI/Features` 下 `APIClient.shared` 调用已清零，体型/饮食/器械/设置/饮食计划等均走 service。
  - Pro 锁定 UI 仍统一走 `store.requirePro/requestPro`；服务端 gate 未改。
  - 不要为了“没 if”把逻辑藏进 View extension 里

### P5 验证与发布

- [ ] PARTIAL · iPhone SE / 16 / 16 Pro Max 全页面截图验收
  - 已在三类模拟器安装运行并截图首页/登录；逐页视觉验收仍需人工完成。
- [ ] 登录、表单、弹窗、键盘回归
- [ ] BLOCKED · 真机验证登录、免费体验、付费墙、AI 额度、滑动会话
- [ ] BLOCKED · TestFlight / StoreKit 沙盒购买与恢复
- [ ] PARTIAL · 防连点、并发、重装、换设备、批量注册测试
  - 本次补了拍照幂等、刷新设备不匹配、缺设备头兼容等后端测试；真机与批量注册仍需环境。
- [ ] PARTIAL · 最后做一次服务端 Pro 绕过审计，确认 LLM Key 只在服务端
  - 已确认 iOS 端没有模型 Key；完整服务端绕过审计仍需真实预发环境。

---

## 5. 已知陷阱

1. **跨文件 Swift extension 不能访问 `private`**
   - 已在 `PlanHomeTrainingData` 踩过：`trainingDataCard` 必须改成 internal。
   - 不要无脑把所有 `private` 删掉；优先用明确的 internal 接口或参数注入。

2. **AppStore 不是 `@MainActor`**
   - `FeatureAccessStore.refresh/consume` 标了 `@MainActor`。
   - 移动 AppStore 方法时注意 actor isolation，不要引入数据竞争。
   - 嵌套 Observable 的刷新依赖动态追踪，UI 改动后要真机/模拟器确认。

3. **生成状态表**
   - `feature_generation_state` 的幂等回放要求 `last_result_ref` 非空。
   - 不要为了回放塞假 ref；拍照结果如果没持久化就不能假装可回放。
   - 计划/饮食 60 秒，拍照 5 秒；改冷却用 `cooldown_seconds` 字段，不要再写全局常量。

4. **StoreKit**
   - 不要关闭证书链校验或 root 指纹校验。
   - 不要接受无 `appAccountToken` 的跨账号交易。
   - 退款/撤销必须走通知或 Server API，不能只靠客户端。
   - 合成证书测试在 `backend/tests/test_app_store.py`，不要删。

5. **安全与额度顺序**
   - 安全/医疗回复必须先于额度判断和付费墙。
   - 付费墙 UI 不是授权；服务端 gate 不能删。
   - 429 要区分 `GENERATION_COOLDOWN`、`GENERATION_IN_PROGRESS`、`RATE_LIMITED`、`COACH_QUOTA_EXHAUSTED`。

6. **MySQL / Flyway**
   - 后端启动不会自动跑迁移；Admin Server 启动时才跑 Flyway。
   - 改迁移后重启 Admin Server，确认 `flyway_schema_history`。
   - 开发库是 Docker 3307；不要连错到本机 3306。

7. **后台**
   - 页面 base path 是 `/admin/`。
   - 管理员密码在 `deploy/admin/.env`，不要打印到日志/提交。
   - 后台“延长 Pro”必须从当前到期时间往后加，不能从 now 重新算。

8. **Git/网络**
   - GitHub 网络偶尔不稳定；push 失败要重试，别把“本地提交成功”说成“CI 通过”。
   - 不要合并 `develop`，等真机和预发验收。
   - 不要动 `F:\FitAI-body-shapes` 备份目录。

---

## 6. 验证命令

### Backend

```powershell
cd E:\Projects\FitAI\backend
.\.venv\Scripts\python.exe -m ruff check app tests scripts
.\.venv\Scripts\python.exe -m pytest -q
$env:PYTHONIOENCODING='utf-8'
$env:ALLOW_DEV_USER_HEADER='true'
$env:GENERATION_COOLDOWN_SECONDS='0'
.\.venv\Scripts\python.exe scripts/smoke.py
```

### Admin

```powershell
cd E:\Projects\FitAI\admin-server
mvn -B -ntp verify

cd E:\Projects\FitAI\admin-web
npm run typecheck
npm test -- --run
npm run build
```

### iOS

- Windows 本地不能跑 Xcode；以 GitHub Actions `iOS Build` 为准。
- XcodeGen 工程：

```bash
cd ios
xcodegen generate
xcodebuild -project FitAI.xcodeproj -scheme FitAI \
  -sdk iphonesimulator -destination "generic/platform=iOS Simulator" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

### 健康检查

```powershell
Invoke-WebRequest http://127.0.0.1:8000/health/ready
Invoke-WebRequest http://127.0.0.1:8080/actuator/health/readiness
Invoke-WebRequest http://127.0.0.1:5173/admin/
```

---

## 7. Git 与提交要求

- 从 `develop` 拉新分支再改，例如 `feat/pro-access-followup-2026-11`
- 小步提交，前缀：
  - `feat(api): ...`
  - `fix(ios): ...`
  - `refactor(ios): ...`
  - `test(...): ...`
  - `docs: ...`
- 每个提交前：
  - `git status`
  - `git diff --check`
  - 对应 lint/test
- 涉及数据流/权益/试用的改动，同步更新：
  - `docs/44-long-term-data-model.md`
  - `docs/45-engineering-standards.md`
  - 涉及隐私时更新 `docs/43-legal-docs.md` 和 `LegalDocuments.swift`
- 不提交：
  - `.env`
  - 密钥、p8、证书私钥
  - `smoke.db`
  - 媒体/上传文件
- 不合并 `develop`，不删除备份目录，不 force push。

---

## 8. 完成标准与汇报格式

每一项完成时按这个格式汇报：

```text
做了什么：
- ...

关键文件：
- ...

验证：
- 本地测试：
- CI：
- 真机/外部验证：

剩余风险：
- ...
```

只有满足验收标准才从清单删除。外部条件缺失时：

- 明确写出缺什么（Apple Key、Issuer、p8、真机、TestFlight、预发库）
- 写清已经验证了什么
- 不要写“应该可以”“理论上支持”当作完成

---

## 9. 最后提醒

这个项目最怕三件事：

1. **客户端假装权限**：所有 Pro/试用/额度最终必须服务端拒绝。
2. **重复扣费**：生成/拍照要有并发锁、冷却、必要的幂等；失败不能扣额度。
3. **大文件继续膨胀**：新功能不要继续塞进 `AppStore`、`PlanHomeView`、`CoachChatView`。先抽 service/子 View，再接 UI。

按这个标准做，不要只追求“能跑”。
