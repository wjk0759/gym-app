# 叫练（原 FitAI）交接给 iOS / OpenCode Agent

> 目标：在 `develop` 的基础上继续完成 Pro、试用、付费墙、滑动会话、防滥用和模块化收尾。
>
> 原则：服务端是权限唯一来源；客户端只负责展示与交互。不要为了“做完”伪造外部验收，不要把新代码堆成屎山。

---

## 0. Agent 同步频道

> Windows / macOS 两个 agent 的唯一同步入口。每次完成任务后，**先更新这里，再结束回复**。
> 最新在上。写清楚：日期 / 端 / 提交 / 做了什么 / 验证结果 / 对方需要做什么 / 禁止恢复什么。
> macOS 拉取后在本节顶部新增一条 `### 日期 · macOS`，写 build/test 结果和失败点。

### 最新状态

- `develop` 代码 HEAD：`8f12f74`（教练记录闭环 + 待确认卡片修正/client_id + 草稿/卡片/会话重启恢复；后端 **347 passed**；iOS Build 在 `8f12f74` 通过；生产已部署 `0ac94cb` + Flyway **V36**、iOS `aa93fe8`，本轮修正尚未部署）；`main`/`testing` 仍为 `10d1ad5`（本轮只推 `develop`）；本文件的最新同步提交见 `git log -1`
- Windows 已完成：真实 DeepSeek 视觉、AI 计划默认开启、视频入口隐藏、隐私标签补充、Apple 登录 entitlement、器械详情崩溃加固、男性椭圆/梯形 16–20% 体型图更新、香港 TestFlight 后端上线、阿里云短信验证码接通、Release 隐藏测试入口、头像上传/移除、设置页清理与第三方署名移除、今日→记录日期联动、训练阶段与按动作负荷、免费教练额度 3 条/天、饮食份量区间、文案精简、切换 Tab 回根页面、重复点 Tab 回根、页面顶部留白统一、Watch 共享训练核心
- macOS 最近完成：品牌改名「叫练」；当前 iOS 构建/SwiftLint 通过，44 个单测 + UI 导航测试通过（本轮修复测试辅助）
- macOS 最新完成（2026-11-11）：全局 UI 交互打磨（`684cd64` + 后续 4 列快捷区提交）：悬浮 Tab Bar 底部留白、相机入口改 4 列一行快捷卡、教练权益 loading/retry 状态；Debug build 成功，`FitAITests` **65/65**，iPhone 17 / iPhone SE / 深色模式截图通过，教练权益超时 UI test 通过，器械目录 UI test 通过；此前完成器械目录 v3 UI 验证（`0dbdbcd`）、equipment v2 编译修复（`6556b0a`）、taxonomy v2 测试（`827ea94`）等
- Windows 最新完成（2026-11-07）：拉取并保留 macOS 单行语音输入（`9a833b1`）；完成教练内核统一并部署生产；`test_reviewer` 已授 Pro、补齐基础档案和 3 分化计划；生产 Watch 预载/登录/刷新/语音/撤销全链路烟测通过；iPhone 训练页动作循环动画 PoC、`/exercise-media` 批量接口、11 条 sample 媒体已上生产（`341981f`）；器械识别修复：图片归一化、禁止随机 mock、37 类器械目录、生产导入 57 条训记动作、4 张真实照片 + 1 张负例烟测 5/5 命中（`5bf99a1`）；2026-11-08 增加 Vision OCR 标签提示、18 张多品牌评测和准确率实验（`23e41c8`）；生产视觉切 **Qwen3-VL-Plus**；器械识别加 **top-2 候选 + 混淆兜底**，18 张缩略图 top-1 61%、top-2 83%（`0d63191`）；已合并到 `develop`（`48ad5f0`），develop CI 全绿
- Windows 前一轮完成（2026-11-07）：手表独立语音教练、watch 专用登录会话、媒体预载/本地缓存、离线 outbox/ack、手机 inbox 回灌、手机→手表指令、3 天 Pro 宽限与中途到期继续结束、HealthKit 保活/手机单写者、Watch AppIcon 恢复、Watch 隐私清单、训练来源 `phone/watch`
- 本地后台（2026-11-08）：FastAPI `8000`、admin-server `8080`、admin-web `5173/admin`、MySQL `3307` V24；真机 API `http://192.168.1.4:8000/api/v1`
- 最新后端验证：**347 passed**，Ruff app/tests 通过；计划池已收归服务端（1,068 动作账号生产实跑 `generated_by=ai`）；器械识别：Qwen3-VL-Plus 对坐姿划船/腿举/哈克深蹲的图片判别不可靠，已加“具体 OCR 标签优先 + 候选顺序 + 手动从器械库选择 + 豆包 lite row/leg gate”，生产无 OCR 坐姿划船实测已返回 `seated_row`；`/watch/bootstrap`、`/watch/session`、`/coach/voice`、workout `source`、`/exercise-media`、器械目录识别、器械 top-2、器械照片上传/训练部位已接入测试；生产 Flyway 已到 **V30**（V29 为补记，均 `checksum=NULL`）；`/me/access` 免费教练额度 `daily_limit=3`、`weekly_limit=3`、`remaining=3`，`reset_at` 为北京时间次日 00:00；`training_stage=beginner`
- 成本提醒：3 条/天 ≈ 21 条/周，是原 10 条/周的约 2.1 倍；上线后监控 DeepSeek 账单和异常调用
- Mac 待办：`git pull` → `xcodegen generate` → Release build/test → 验证计划生成/教练调整按动作读取历史重量、训练阶段显示、3 条/天额度文案；验证今日选日期→记录页自动选中、返回今日回到今天、编辑计划按钮明显；验证切换 Tab 和重复点当前 Tab 都回到各根页面；验证 Tab 栏普通点击/滑动未被 reselect observer 拦截；逐页确认顶部 16pt 留白没有 double padding；验证免费文字额度 >0 不弹订阅、拍照/视频/器械显示 Pro 标识；验证改手机时间不能刷新余额；用 `https://hk-api.jiaolianfit.cn/api/v1` 真机验证 Apple 登录、手机验证码、头像相册/拍照、建档、AI 计划、教练、拍照；确认 Release 无「开发服务器」「测试连接」「服务状态」、无 RepDB/RawPheasant 署名；确认男性椭圆/梯形 16–20% 新图；键盘问题已定位为 Xcode 调试环境，未改产品代码；本轮新增：验证训练页内嵌循环动画/全屏、Reduce Motion、音乐不中断、切后台暂停，以及 Watch 动作页播放 `watch_url`
- 仍 BLOCKED：IAP 商品与协议、App Store Server API Key/Issuer/p8、Notifications V2 URL、TestFlight 外部 Beta 审核、App Store Connect 上传凭证/App 记录、正式 1,500 动作 × 男女素材采购与映射、Watch 真机安装验证、TestFlight/App Store 真机验收

### 2026-11-13 · Windows（草稿会话恢复）

- 代码提交：`8f12f74`
- 背景：`pendingDraft` 已持久化，但 `agentSessionID` 没持久化；App 重启后草稿条还在，下一条“250ml”会创建新 session，服务端找不到原草稿。
- iOS：
  - `PersistedState` 持久化 `agentSessionID`
  - 启动恢复 session，再恢复 pending draft / pending action
  - 退出登录 reset 仍会清空 session 和草稿
- 验证：
  - `iOS Build` 在 `8f12f74` 通过
  - 后端无变化，仍 **347 passed**
- 部署：
  - 无需迁移；iOS 部署 `8f12f74`
  - 生产仍 backend `0ac94cb` / iOS `aa93fe8`
- 已知限制：
  - 如果服务端 session 被清理，恢复的 draft 仍会失效；下一次请求会回退到新 session
  - 跨设备没有待确认草稿
- 不要恢复：
  - 不要只持久化 pendingDraft 而不持久化 agentSessionID

### 2026-11-13 · Windows（待确认卡重启恢复）

- 代码提交：`de5918d`
- 背景：用户修改了饮食卡但没确认，App 重启后卡片丢失；下一条消息无法继续修正。
- iOS：
  - `PersistedState` 持久化 `agentActions`
  - 持久化 `pendingDraft`
  - 启动后恢复未确认卡片和草稿
  - 执行/取消后照常清空并持久化
- 验证：
  - `iOS Build` 在 `de5918d` 通过
  - 后端无变化，仍 **347 passed**
- 部署：
  - 无新迁移；iOS 部署 `de5918d`
  - 生产仍 backend `0ac94cb` / iOS `aa93fe8`
- 已知限制：
  - 跨设备不会同步待确认卡片
  - 如果卡片在另一台设备已经执行，本机恢复后确认可能收到幂等结果或 404，需要重新生成
  - 草稿仍有 30 分钟 TTL，过期后恢复的卡片仍会被服务端判失效
- 不要恢复：
  - 不要只持久化卡片的 action ID 而不持久化 payload
  - 不要在启动恢复后丢失客户端已修改的份量

### 2026-11-13 · Windows（待确认卡修正 + client_id 修复）

- 代码提交：`1eb99c3`
- 背景：真实用户 13428104171 反馈：肉肠 180g 的饮食卡修改后，再说“记错了是 230g”报参数错误。
- 根因：
  - iOS `AgentActionPayload` 没有 `client_id`，导致 `update_food_log` / `delete_food_log` 执行时丢字段，后端 422。
  - 用户修改确认卡后发新消息，`sendAgentChat` 先清空 `agentActions`，未确认卡片丢失；服务端没有真实 FoodLog，`update_food_log` 无从更新。
- iOS：
  - `AgentActionPayload` 增加 `clientID` / `client_id` 解码
  - 发送新消息时把 pending action 放进 `app_context.pending_action`
  - 请求失败时恢复 pending action，不丢卡
  - 新增 decoding test
- 后端：
  - 如果 `app_context.pending_action` 存在且用户说“记错了/改成/不是/应该是”，服务端直接按新克数生成修正后的 `log_food` 卡，不写库、不走 `update_food_log`
  - 已确认记录才使用 `update_food_log`，并要求 `client_id` 来自 `today_nutrition.recent_logs`
  - 新增 pending action 修正测试
- 验证：
  - 后端 **347 passed**，Ruff 通过
  - `Backend Tests`、`Coach Eval`、`iOS Build` 在 `1eb99c3` 通过
- 部署：
  - 无新迁移；部署 backend `1eb99c3` + iOS `1eb99c3`
  - 生产当前 backend `0ac94cb`、iOS `aa93fe8`
- 已知限制：
  - pending action 仍主要在客户端上下文；App 重启后未确认卡片不会自动恢复
  - 多食物卡片修正时，服务端仍需靠食物名匹配；单食物场景已确定性处理
  - 已确认记录的修正依赖模型从 recent_logs 取 client_id
- 不要恢复：
  - 不要让 update_food_log 缺失 client_id
  - 不要在新消息时直接丢弃未确认卡
  - 不要把确认前修正误走 update_food_log

### 2026-11-13 · macOS（V36 + 教练记录闭环部署）

- 分支：`develop`，部署后端 `0ac94cb`、iOS `aa93fe8`
- 本地验证：
  - `xcodegen generate` + 编译
  - `FitAITests` **80/80** 通过
  - `FitAIUITests` **4/4** 通过
- 备份：
  - MySQL：`/opt/fitai/backups/fitai-pre-v36-20261113-223050.sql.gz`（491K，51 tables）
  - backend：`/opt/fitai/backups/backend-pre-v36-20261113-223050.tar.gz`
- 迁移：
  - `V36__agent_action_drafts.sql` 执行成功
  - `flyway_schema_history` 当前版本 **36**
  - `agent_action_drafts` 表已创建
- 后端：
  - `rsync backend/app` → `/opt/fitai/backend/app`
  - `docker compose build api && up -d api` 成功，`fitai-api` healthy
  - `/health/ready` 返回 `{"status":"ready"}`
  - OpenAPI 已确认 `/agent/actions/{action_id}/run`、`/undo-run`、`/agent/drafts/{draft_id}` 存在
  - 最近日志无 ERROR
- iOS：
  - 最新 phone-only Release 已安装并启动 Wu-Tang
  - 保持登录，今日页正常
- 未验证：
  - 登录后真实对话：饮食多轮草稿、份量/日期/餐次调整、删项、计划餐跳过/恢复
  - 训练补录、修改、删除
  - 教练 action 卡的失败/部分失败提示
- 注意：
  - 生产 22 端口仍对 `27.38.152.227/32` 放行；部署完成，可移除或改固定 IP

### 2026-11-13 · Windows（确认卡可改日期/餐次/删项）

- 代码提交：`aa93fe8`
- 背景：教练估算卡能调克数，但仍不能改日期、餐次或删掉估算错的单项；用户只能整张取消重说。
- iOS：
  - `EditFoodActionSheet` 增加日期选择（不能选未来）和餐次 segmented picker
  - 每项食物可删除，至少保留一项
  - 保存后 action payload 的 `date` / `meal` / `items` 与 summary 热量同步
  - 仍然只在确认执行时写库
- 验证：
  - `iOS Build` 在 `aa93fe8` 通过
  - 后端无变化，仍 **346 passed**
  - 尚未真机验证
- 部署：
  - 无需新迁移；iOS 部署 `aa93fe8`
  - V36 仍未执行，生产 backend 仍 `13769a9`
- 已知限制：
  - 不能改食物名称
  - 不能新增单项
  - 不能把餐次改到没有计划的日期后自动关联计划餐（仍是普通饮食记录）
- 不要恢复：
  - 不要在 sheet 里直接写 FoodLog
  - 不要允许删除最后一项
  - 不要允许选未来日期

### 2026-11-13 · Windows（多轮饮食草稿）

- 代码提交：`0ac94cb`
- 背景：教练追问“奶茶半杯多少毫升”后，用户只回复“250ml”，模型容易丢失上一轮食物或重新开一餐。
- 后端：
  - 新增 V36 `agent_action_drafts`
  - `resolve_food` 对缺少份量的饮品/大份食物创建 draft，返回 `pending_draft`
  - 短回答（`250ml`、`半杯`、`对`、`取消`）由服务端确定性补槽，绕过模型
  - 补完后服务端直接生成 `log_food` action，`draft` 标记 consumed
  - `DELETE /agent/drafts/{id}` 取消草稿
  - 草稿 30 分钟过期，按 user + session 隔离
- iOS：
  - `AgentChatResponse` 解码 `pending_draft`
  - 教练页显示“正在记录午餐 + 还差什么 + 取消”
  - 下一轮直接回复份量即可，不需要重新描述整餐
- 真实模型验证：
  - 第一轮“我今天喝了奶茶” → pending draft，追问份量
  - 第二轮“250ml” → 生成 175 kcal 的 log_food action
  - 执行后只写入一条 250g 奶茶记录
- 验证：
  - 后端 **346 passed**，Ruff 通过
  - `Backend Tests`、`Coach Eval`、`iOS Build` 在 `0ac94cb` 通过
  - 新增 `test_action_drafts.py`
- 部署：
  - **必须先执行 V36**
  - 再部署 backend `0ac94cb` + iOS `0ac94cb`
  - 生产当前 V35 / backend `13769a9`，本轮未部署
- 已知限制：
  - 目前只对规则命中的饮品/大份食物建草稿；未知菜品仍靠 LLM questions，不能稳定补槽
  - 只支持单槽回答；“250ml 无糖”可补量但不解析糖度
  - 草稿只存在服务端，iOS 重启后不会主动拉取旧草稿；下一条消息才会恢复
  - 草稿取消没有撤销
- 不要恢复：
  - 不要把短回答重新交给模型自由解析
  - 不要在没有 draft 的情况下重复创建 action
  - 不要让草稿跨 session 读取

### 2026-11-13 · Windows（饮食确认卡可调份量）

- 代码提交：`d0fdfc8`
- 背景：教练估算卡只能确认或取消；用户知道“半杯”不是 250ml 时只能取消重说，体验断。
- iOS：
  - `log_food` 确认卡新增「调整份量」
  - 打开独立 sheet，按食物逐项 Stepper 修改克数
  - 热量、蛋白、碳水、脂肪按原每克密度等比缩放
  - 保存后确认卡同步更新，仍不会写库；必须点「确认并执行」
  - 支持 10–2000g 范围
- 验证：
  - `iOS Build` 在 `d0fdfc8` 通过
  - 后端无变化，仍 **344 passed**
  - 尚未真机验证 sheet 交互
- 部署：
  - 无需新迁移；iOS 部署 `d0fdfc8`
  - 生产当前 backend `13769a9` / V35；训练、计划餐跳过、份量调整都还没上线
- 已知限制：
  - 只能调克数，不能改日期/餐次/名称
  - 不能把一份拆成多项或删除单项
  - 多轮补参数 still pending
- 不要恢复：
  - 不要在调整 sheet 里直接写 FoodLog；必须回确认卡
  - 不要丢失原每克密度缩放

### 2026-11-13 · Windows（计划餐跳过/恢复）

- 代码提交：`4686640`
- 背景：饮食复盘把用户主动不吃的计划餐算成“漏记”，完成率被低估；用户需要明确表达“这餐不吃了”。
- 后端：
  - 新增 `skip_planned_meal` / `restore_planned_meal`
  - 跳过状态写入当天计划 JSON 的 `skipped_meals`
  - 已记录的计划餐不能跳过
  - `coach_context.today_nutrition` 增加 `skipped_plan_meals` 和每餐 `skipped`
  - 饮食复盘：跳过不计入缺失、不计入完成率分母；返回 `eligible_meals` / `skipped_meals`
  - `log_planned_meal` 会先移除同餐跳过
- iOS：
  - 每日计划餐显示「已跳过这餐」，隐藏一键整餐按钮
  - 计划页头部显示「已跳过 N 餐」
  - 复盘饮食卡显示跳过数，完成率使用有效计划餐分母
  - 跳过/恢复 action 支持撤销
- 验证：
  - 后端 **344 passed**，Ruff 通过
  - `Backend Tests`、`Coach Eval`、`iOS Build` 在 `4686640` 通过
  - 新增计划餐跳过、恢复、复盘分母测试
- 部署：
  - 无需新迁移；部署 backend `4686640` + iOS `4686640`
  - 生产仍是 backend `13769a9` / V35
- 已知限制：
  - 跳过状态存在计划 JSON，不是独立表；计划重新生成会重置
  - 每日饮食页只展示已跳过，没有直接恢复按钮；恢复目前通过教练 action
  - 跳过餐仍然显示在计划列表里，不删除菜品
- 不要恢复：
  - 不要把跳过餐计入完成率分母或缺失列表
  - 不要让已记录的餐再被跳过
  - 不要在日志记录后保留 skipped_meals

### 2026-11-13 · Windows（训练补录 + 真实模型饮食验证）

- 代码提交：`3627928`、`34e35fe`、`0d37498`
- 真实模型验证（本地 SQLite + 真实 DeepSeek，不涉及生产数据）：
  - 输入：“我今天吃了一份湿炒螺蛳粉，半杯奶茶，帮我记一下”
  - 模型返回 `needs_confirmation`，生成 `log_food` action
  - items：湿炒螺蛳粉 500g / 625 kcal，奶茶 250g / 175 kcal
  - 执行后写入两条 FoodLog，`today_nutrition` 显示 800 kcal、蛋白 30g
  - 证明强制 `log_food` 意图 + resolve_food + action 执行链路可用
  - 输入：“我昨天跑了 30 分钟，帮我记一下” → 生成 `log_workout`，执行后 WorkoutSession 30 分钟、source=coach
  - 修复了一个真实问题：`帮我记` 同时命中饮食和训练意图；现在运动词优先训练，食物词优先饮食
- 后端：
  - 新增 `log_workout` action：`date/title/duration_minutes/kind/notes/program_day_id/sets`
  - 力量训练校验动作 slug；有氧可只记标题和时长
  - 禁止未来日期；同一 action_id 幂等；支持 `undo-run` 删除
  - 写入后刷新 `training_stage`
  - 明确“练完了/跑了/补录”时强制 `forced_intent=log_workout`，拒绝 `start_training` / `modify_workout`
  - 新增 `update_workout_log` / `delete_workout_log`：按 session_id 修改日期/时长/备注/整组 sets，或删除记录
- iOS：
  - 教练 action 卡显示训练标题、时长、类型、组数
  - 执行后刷新训练历史
  - 撤销训练补录
  - 无计划关联的教练训练用 notes 作历史标题
- 验证：
  - 后端 **342 passed**，Ruff 通过
  - `Backend Tests`、`Coach Eval` 在 `0d37498` 通过
  - `iOS Build` 在 `34e35fe` 通过
  - 新增 `test_log_workout_action_writes_session_and_undoes`、`test_update_and_delete_workout_actions`
  - Mac `FitAITests` **80/80**（`13769a9` 时）
- 部署：
  - V35 已执行，生产 Flyway 35
  - 本次无需新迁移；部署 backend `0d37498` + iOS `34e35fe`
  - 当前生产 backend 仍是 `13769a9`，训练记录能力未上线
- 已知限制：
  - 教练补录的训练标题暂存在 notes，未新增 `day_title` 列
  - 饮食确认卡仍不能逐项改克数；多轮补参数还没有 pending draft 表
  - 训练修改/删除没有撤销；只能再次修改或重新补录
  - 真机仍未走完整对话链路
- 不要恢复：
  - 不要让“练完了/跑了”走 start_training
  - 不要允许未来日期训练记录
  - 不要移除 log_workout 的 action_id 幂等和撤销

### 2026-11-13 · macOS（V35 + 教练饮食记录部署）

- 分支：`develop`，部署后端 `13769a9`
- 本地验证：
  - `xcodegen generate` + 编译
  - `FitAITests` **80/80** 通过（含 `AgentActionDecodingTests.testLogFoodActionDecodesItems`）
  - `FitAIUITests` **4/4** 通过
- 备份：
  - MySQL：`/opt/fitai/backups/fitai-pre-v35-20261113-205403.sql.gz`（482K，51 tables）
  - backend：`/opt/fitai/backups/backend-pre-v35-20261113-205403.tar.gz`
- 迁移：
  - `V35__food_log_provenance.sql` 已执行成功
  - `flyway_schema_history` 当前版本 **35**
  - `food_logs` 已增加 `source` / `source_action_id` / `source_group_id` / `estimate_confidence`
- 后端：
  - `rsync backend/app` → `/opt/fitai/backend/app`
  - `docker compose build api && up -d api` 成功，`fitai-api` healthy
  - `https://hk-api.jiaolianfit.cn/health/ready` 返回 `{"status":"ready"}`
  - OpenAPI 已确认 `/agent/actions/{action_id}/run` 和 `/undo-run` 存在
  - 未登录访问新接口返回 401，无 500；最近日志无 ERROR
- iOS：
  - 最新 phone-only Release 已安装并启动 Wu-Tang
  - 今日页正常加载；App 保持登录
- 未验证：
  - 登录后真实对话“帮我记饮食” → action 卡 → 确认 → 写入/撤销
  - 估算值展示、部分失败提示
  - 计划餐记录 / 今日目标刷新
- 注意：
  - 生产 22 端口仍对 `27.38.152.227/32` 放行；部署完成，可移除或改固定 IP

### 2026-11-13 · Windows（AI 教练饮食记录 Action 总线）

- 代码提交：`e0a7f84`、`13769a9`
- 背景：用户对教练说“我今天吃了一份湿炒螺蛳粉，半杯奶茶，帮我记一下”，教练没有 `log_food` 能力，只能打开饮食页/让用户自己填；饮食上下文只有近 7 天聚合，没有今天计划餐和剩余额度。
- 后端：
  - 新增 `coach_actions` 注册表/执行器：payload schema、执行、幂等、撤销
  - `POST /agent/actions/{action_id}/run` + `/undo-run`
  - 新增 `resolve_food` 工具：文本 → 食物项/份量/热量/宏量/置信度
  - 新增 `log_food`、`log_planned_meal`、`update_food_log`、`delete_food_log`
  - 规则解析优先，LLM 兜底；份量不确定返回 questions，不静默写入
  - 明确说“帮我记一下/记录饮食”时强制 `forced_intent=log_food`，只允许 context / resolve_food / food actions，拒绝 open_screen 和 create_diet_plan
  - `coach_context` 增加 `today_nutrition`：今日目标、已摄入、剩余、计划餐、已记录计划餐、最近记录
  - `food_logs` 增加 `source` / `source_action_id` / `source_group_id` / `estimate_confidence`，V35 迁移
  - 同一 `action_id` 重放返回第一次结果，不重复写记录；`log_food`/`log_planned_meal` 支持整组撤销
- iOS：
  - `AgentActionPayload` 支持 `items` / `raw_text`
  - 教练 action 卡显示逐项食物、份量、热量，标注“估算值”
  - 执行后合并服务端 `created_logs`，刷新今日饮食/周复盘/目标
  - 教练饮食记录支持撤销
  - 执行失败不再无条件弹“Agent 操作已执行”，改为失败/部分失败提示
- 验证：
  - 后端 **340 passed**，Ruff 通过
  - `Backend Tests`、`Coach Eval`、`iOS Build` 在 `e0a7f84` 通过
  - 新增 `test_coach_food_actions.py`：规则解析、写入、action 幂等、撤销、计划餐
  - 新增 `test_agent_actions.py` 的 log_food 校验和饮食意图路由
  - iOS 新单测 `AgentActionDecodingTests.testLogFoodActionDecodesItems` 尚未由 CI 执行
- 部署：
  - **先执行 V35__food_log_provenance.sql**，再部署 backend `13769a9`
  - 生产当前为 V34 / backend `78839d2`；本轮尚未部署
  - iOS 需要安装 `e0a7f84` 新包（后续仅后端/文档变化）
- 已知限制：
  - 文本解析目前规则覆盖常见菜；未知菜依赖 LLM 兜底，必须用户确认估算
  - 教练卡暂时只能确认，不能在卡内逐项改克数；改记录需再对话或饮食页编辑
  - 还没有 `log_workout` / 训练补录
  - 现有生产尚未执行 V35；未跑 iOS 真机验证
- 不要恢复：
  - 不要让“帮我记饮食”走 `open_screen nutrition` 或 `create_diet_plan`
  - 不要在没有结构化解码结果时直接写 FoodLog
  - 不要删除 action_id 幂等和整组撤销
  - 不要绕过 V35 直接部署 e0a7f84

### 2026-11-13 · macOS（生产部署完成：V31–V34 + backend）

- 分支：`develop`，部署代码对应后端 `78839d2`
- SSH：阿里云安全组已放行当前 Mac IP `27.38.152.227/32`，`root@8.218.205.149` 公钥登录成功
- 备份：
  - MySQL：`/opt/fitai/backups/fitai-pre-v31-root-20261113-201157.sql.gz`（466K，49 tables）
  - backend：`/opt/fitai/backups/backend-pre-deploy-20261113-201252.tar.gz`
- 迁移：
  - 用 `flyway/flyway:10` + `fitai_default` 网络执行
  - 先 `info` 确认 V31–V34 Pending，再 `migrate`
  - 结果：**V31 coach_feedback、V32 agent_prompt_version、V33 agent_request_state、V34 food_log_plan_link 全部 success**
  - `flyway_schema_history` 当前版本 **34**
- 后端：
  - `rsync backend/app` → `/opt/fitai/backend/app`（保留 data / .env / Dockerfile）
  - `docker compose build api && docker compose up -d api`
  - `fitai-api` healthy，`https://hk-api.jiaolianfit.cn/health/ready` 返回 `{"status":"ready"}`
  - OpenAPI 已确认包含 `/agent/feedback`、`/agent/requests/{request_id}`、`/diet/review`、`/plans/{plan_id}/activate`、`/diet/plan/{date}/meals/{meal}/undo-swap`
- 验证过的表/列：
  - `coach_feedback`、`agent_request_state` 已创建
  - `agent_runs.prompt_version` 已添加
  - `food_logs.plan_date` / `plan_meal` 已添加
- 未验证：
  - 需要登录后的端到端：教练反馈提交、饮食复盘、换餐撤销、Agent 新请求状态
  - iOS 真机新 UI（饮食编辑/复盘/休息灵动岛）
- 注意：
  - 迁移只前进，回滚需用上面的 MySQL 备份
  - 22 端口当前仍对 `27.38.152.227/32` 放行；部署结束后可移除或改成固定办公 IP
  - `backend/data` 未覆盖，已比对内容一致（仅 CRLF 差异）

### 2026-11-13 · macOS（生产部署尝试：SSH 被安全组阻断）

- 分支：`develop`，HEAD `b7c6b58`
- 本地验证：
  - `FitAITests` **79/79**、`FitAIUITests` **4/4**
  - phone-only Release（含 `FitAIWidget`）已装 Wu-Tang
- 部署尝试：
  - `ssh root@8.218.205.149:22` **超时**
  - 同机 `443` 正常，`https://hk-api.jiaolianfit.cn/health/ready` 返回 `{"status":"ready"}`
  - 当前公网 IP：`27.38.152.227`；文档记录安全组 22 端口只放行 `163.125.200.210/32`
- 结果：
  - **未修改服务器**，生产仍是 `5c16528`
  - V31–V34 迁移仍未执行
- 解锁条件：
  - 在阿里云 ECS 安全组把当前公网 IP `27.38.152.227/32` 加到 22 端口，或改用 ECS Workbench
  - 放行后再：备份数据库 → 执行 V31–V34 → 部署 backend → 健康检查
- 不要：
  - 不要在 V31–V34 之前部署新 backend
  - 不要为了省事关闭 22 端口白名单

### 2026-11-13 · macOS（拉取并验证饮食/复盘/教练/休息计时）

- 分支：`develop`
- 拉取：`c998f56..b7c6b58`，fast-forward，工作区干净
- 做了什么：
  - `xcodegen generate`，新 Widget target `FitAIWidget` 已加入工程
  - 编译并跑 `FitAITests` / `FitAIUITests`
  - phone-only Release 安装并启动 Wu-Tang（包含 `FitAIWidget.appex`）
- 验证：
  - 编译 **BUILD SUCCEEDED**
  - `FitAITests` **79/79** 通过（含新增 `RestTimerTests`、`PlanReviewEngineTests`、`AgentActionDecodingTests`）
  - `FitAIUITests` **4/4** 通过（器械目录 1 条、导航性能 3 条）
  - 新包已装 Wu-Tang，今日页正常加载现有计划（深色模式）
  - Widget target 已编译、签名并嵌入，无签名报错
- 未验证：
  - 8 步 onboarding + 计划预览/激活
  - 饮食编辑、换餐撤销、整餐记录、7 种策略、饮食复盘
  - 训练总结 + 周复盘 adherence
  - 休息倒计时退后台/锁屏/灵动岛/通知/设置开关
  - 教练改课、反馈、每组历史
  - 原因：真机交互无法从命令行完成；需登录后手动走
- Mac 下一步：
  - 真机按上述清单逐项验证
  - 生产部署仍需按顺序执行 V31–V34，再部署 backend；当前生产仍是 `5c16528`
- 不要恢复：
  - 不要恢复 14 步 onboarding / 计划直接 active
  - 不要恢复本地纯写计划或整周 AI 重排换餐
  - 不要把未来计划餐算进周复盘缺失
  - 不要恢复进程内 Agent 幂等缓存
  - 不要恢复旧休息 Timer / 内存倒计时
  - 不要绕过回复安全护栏

### 2026-11-13 · Windows（饮食可用性收尾）

- 代码提交：`c851428`、`6be15fc`、`e450dba`、`78839d2`、`0f11616`、`2ef2379`
- 背景：饮食模块主链路已通，但真实使用还有几处会打断用户：记错后只能删了重记；换错餐无法撤销；Home 目标与计划不一致；教练页只能看不能记；周计划默认碳循环对新手偏激进；跨时区默认日期会错。
- iOS：
  - 新增 `EditFoodLogSheet`：可改日期、餐次、食物名、克数、热量、蛋白/碳水/脂肪/纤维
  - 编辑后的 FoodLog 保留原 client_id，服务端按 upsert 更新；计划餐编辑时同步移动 `plan_date` / `plan_meal`
  - 新增 `pendingFoodUpdateIDs`：编辑后未同步成功的记录，云端拉取时不会被旧值覆盖
  - 记录食物页新增「外食 / 聚餐」快捷区；已有收藏、最近记录
  - 饮食计划页显示「已记录 X/Y 餐」
  - 换餐后支持「撤销」，服务端恢复上一道菜
  - 教练饮食卡支持今天每餐「记录」、显示已记录勾选，并可直接「去记录」
  - Home 饮食卡改用服务端当天目标并缓存，碳循环日不再显示平铺目标
  - Home 周复盘卡显示训练完成、计划餐完成、饮食完成率
  - 周饮食计划默认改为「均衡」，碳循环/16:8 必须主动选择
  - 食物记录编辑的数值已按服务端上限截断；日期不能选未来
- 后端：
  - 新增 `POST /diet/plan/{date}/meals/{meal}/undo-swap`
  - 换餐备份 `_swap_previous` 写入计划 JSON，但所有读接口会剥离
  - 饮食默认日期改用中国本地日期，避免 UTC 跨日把计划排到前一天
  - 教练 `swap_diet_meal` 未传日期时默认中国今天
  - 单餐替换服务补同周替换、规则兜底、撤销和缺失场景测试
- 验证：
  - 后端 **333 passed**，Ruff 通过
  - `Backend Tests`、`Coach Eval` 在 `78839d2` 通过
  - `iOS Build` 在 `2ef2379` 通过
  - `iOS Build` workflow 仍只 build，不跑 `FitAITests`；新增的 `NutritionTargets(remote:)`、FoodLog round-trip 等单测需 Mac 侧执行
- 部署：
  - 本次没有新迁移；仍为 V31 + V32 + V33 + V34
  - 部署 backend `78839d2`（后续提交仅 iOS/文档）+ iOS `2ef2379`
- 已知限制：
  - 条码/包装食品录入未做：需要相机权限、商品库和外部条码数据源
  - 食物收藏/最近记录仍只在本机，不跨设备同步
  - 换餐撤销入口只在换餐后的当前页面出现；服务端备份仍在，但重开 App 不显示撤销按钮
  - 饮食计划没有「跳过这餐」状态；未记录的计划餐仍会算缺失
  - 计划餐去重只在本机判断，两台设备同时记录同一餐可能产生两条
  - 本轮没有真机验证；Mac 需要跑 FitAITests 并检查新增饮食页面
- 不要恢复：
  - 不要把周计划默认改回碳循环
  - 不要移除 `pendingFoodUpdateIDs`
  - 不要让编辑后的计划餐保留旧的 `plan_date` / `plan_meal`
  - 不要把换餐备份暴露在 GET 计划响应里
  - 不要让 Home 饮食目标退回本地平铺计算

### 2026-11-13 · Windows（单餐替换）

- 代码提交：`6b228e3`
- 背景：饮食计划只能整周重排；用户想换掉某一餐时会丢掉其余 6 天，教练也无法在对话里只改一餐。
- 后端：
  - 新增 `POST /diet/plan/{date}/meals/{meal}/swap`
  - 优先从同周其他日期的同名餐次找替代菜；没有同周数据时使用规则备选菜
  - 保持原餐次的热量和蛋白/碳水/脂肪不变，只换菜名、食材和做法，避免当天总热量被换餐打乱
  - 返回完整当天计划 + `swapped_meal {meal, from, to}`
  - 新增教练 App action `swap_diet_meal`，payload 为 `date` + `meal`；未传日期默认今天
  - Agent 提示词和 action 白名单同步更新
- iOS：
  - 每日饮食页每餐标题右侧新增换餐按钮；请求中显示进度并禁用重复点击
  - 换餐后立即用返回计划刷新餐单和当天目标
  - 教练 action 卡支持 `swap_diet_meal`，执行后提示“已把 X 月 X 日午餐换成「...」”
  - 教练页周饮食卡会重新拉取已保存周计划
- 验证：
  - 后端 **332 passed**，Ruff 通过
  - `Backend Tests`、`Coach Eval`、`iOS Build` 在 `6b228e3` 均通过
  - 新增 `test_diet_swap.py`：同周替代、单日规则替代、缺失日期/餐次
  - 新增 `test_agent_actions.py`：换餐 action 规范化、默认今天、非法餐次
- 部署：
  - 本次没有新迁移；仍为 V31 + V32 + V33 + V34
  - 部署 backend `6b228e3` + iOS `6b228e3`
- 已知限制：
  - 换餐按顺序轮换同周菜品，不保证用户没吃过
  - 规则备选菜的做法是通用家常步骤，不是专门菜谱
  - 没有“撤销换餐”；再点一次会继续换成下一道
  - 只换一餐，不支持一次替换整天
- 不要恢复：
  - 不要为了换一餐调用整周 AI 重排
  - 不要改变原餐次的热量/宏量槽位
  - 不要移除 `swap_diet_meal` action

### 2026-11-13 · Windows（饮食执行复盘）

- 代码提交：`2c51a5e`、`1ce61e6`
- 背景：饮食计划已经能一键记录，但复盘只看实际摄入，无法回答“计划了几餐、真正按计划吃了几餐、哪一餐一直漏”；服务端周复盘也没有饮食执行数据。
- 后端：
  - 新增 `GET /diet/review?from=&to=`，确定性规则，不调用模型
  - 只把带 `plan_date` / `plan_meal` 的记录算作计划餐完成；手动记录只计入实际摄入
  - 返回 `planned_days / planned_meals / logged_plan_meals / adherence_rate`
  - 返回计划与实际热量、蛋白质，以及每日状态 `on_track / under / over / no_log / no_plan`
  - 返回缺失计划餐列表和一句 insight
  - 周复盘范围只算到今天，未来计划餐不会提前算“错过”
  - `generate_weekly_review` 增加饮食执行 stats 和 action：
    - 有计划但零记录 → 先记录一餐
    - 计划餐完成率 < 60% → 先固定最容易执行的一餐
- iOS：
  - `PlanReviewView` 新增「饮食计划执行」卡
  - 显示计划餐完成率、已记录/计划餐数、实际/计划热量、蛋白质
  - 列出前 3 个还没记录的计划餐
  - 显示服务端生成的饮食 insight；网络失败时整卡隐藏，不影响原有本地复盘
- 验证：
  - 后端 **327 passed**，Ruff 通过
  - `Backend Tests`、`Coach Eval` 在 `2c51a5e` 通过
  - `iOS Build` 在 `1ce61e6` 通过（`2c51a5e` 的 iOS run 被取消，已用 workflow_dispatch 重跑）
  - 新增 `test_diet_review.py`：只统计计划餐链接、实际-only 天、未来计划餐、范围校验
- 部署：
  - 本次没有新迁移；仍为 V31 + V32 + V33 + V34
  - 部署 backend `1ce61e6` + iOS `1ce61e6` 新包
- 已知限制：
  - 计划餐完成只认「整餐」或带 plan 链接的记录；手动记录同餐不会自动算完成
  - 只到餐次级，不判断每道菜是否按计划吃
  - 缺失计划餐列表最多 12 条，复盘页只展示前 3 条
  - 周复盘只在本地复盘页展示，教练对话里的周复盘卡还没有接这些字段
- 不要恢复：
  - 不要把未来计划餐计入当前周缺失
  - 不要用手动 FoodLog 猜测计划餐完成
  - 不要让饮食复盘调用 LLM

### 2026-11-13 · Windows（饮食闭环：计划餐、目标、食物收藏）

- 代码提交：`db8421a`、`daf97c3`
- 背景：周饮食计划只能看不能快速记录；每日视图的目标仍按档案重算，碳循环高/低碳日会显示错；计划餐记录无法知道来自哪一天哪一餐；食物库没有收藏和最近记录；饮食策略只有 4 种。
- 后端：
  - 每日/每周饮食计划的每餐新增 `protein_g / carbs_g / fat_g`，按当天目标与餐次比例估算
  - 新增策略：`mediterranean`、`vegetarian`、`time_restricted_16_8`
    - 16:8 只生成午餐、晚餐、加餐，并返回进食窗口 caution
    - 素食为蛋奶素模板；纯素风险写入 caution
  - `GET /diet/targets?date=` 优先返回已保存计划的当天目标，否则按档案重算
  - `GET /diet/plan` 和 `GET /diet/plan/week` 读取旧计划时自动补每餐宏量，不要求重新生成
  - `food_logs` 新增 `plan_date`、`plan_meal` 软关联；V34 迁移
  - `POST /diet/logs` / `GET /diet/logs` 支持 `plan_date`、`plan_meal`
  - Agent 的 `create_diet_plan` 策略白名单同步扩展到 7 种
- iOS：
  - 饮食计划餐卡新增「整餐」按钮：一键写入一条计划餐记录（热量 + 蛋白/碳水/脂肪）
  - 已记录整餐后按钮消失，避免重复记录
  - 记录列表显示「计划餐」标记；计划餐没有克数时不再显示 `0 g`
  - 每日饮食页进入时先取 `/diet/targets?date=`，再读当天已保存计划；周计划关闭后自动刷新目标和餐单
  - 本周计划策略改为横向 chip，新增地中海、素食、16:8
  - 饮食方案库同步新增 3 张策略卡
  - 记录食物页新增「收藏」「最近记录」；每行右侧可收藏/取消收藏
  - 收藏与最近记录持久化在本地 `PersistedState`
- 验证：
  - 后端 **323 passed**，Ruff 通过
  - `Backend Tests`、`Coach Eval`、`iOS Build` 在 `db8421a` 通过
  - `Admin CI` 仍在历史 V28 失败：`equipment_type_exercises` → `exercises` 外键；V34 已成功通过 Flyway validate（34 migrations），不是本次引入
  - 新增测试：7 种策略的餐数与宏量、旧计划宏量回填、计划餐链接、每日目标读取
  - iOS 新单测（餐次宏量拆分、FoodLog 计划字段 round-trip）需要 Mac 侧跑 `FitAITests`
- 部署：
  - 新迁移 **V34__food_log_plan_link.sql**
  - 需要按顺序执行 V31 + V32 + V33 + V34
  - 部署 backend `daf97c3` + iOS `db8421a` 新包
- 已知限制：
  - 条码扫描未做：需要相机权限、商品库和外部条码数据源，不在本轮硬凑
  - 16:8 只生成餐单和风险提示，没有进食窗口倒计时/提醒
  - 计划餐与 FoodLog 是软关联，不建外键；计划重新生成后历史记录仍保留
  - 收藏/最近记录只在本机，不跨设备同步
  - 旧计划只在读取时补宏量，数据库里仍没有写回
- 不要恢复：
  - 不要把每日目标改回只用 `profile.weekly_days` 重算
  - 不要移除 `plan_date` / `plan_meal` 软关联
  - 不要把饮食策略列表改回 4 种
  - 不要让「整餐」按钮在已记录后继续可点

### 2026-11-13 · Windows（训练总结 + 周复盘闭环）

- 代码提交：`b462fcb`
- 背景：训练结束只显示总组数和容量，没有“计划 vs 实际”；周复盘用档案每周次数当分母，跳过/错过/改期都没有进入完成率；复盘只有数据，没有下一步动作。
- iOS：
  - 新增 `WorkoutOutcomeCard`，接在训练结束总结卡下方：
    - 每个动作计划组数 vs 完成组数
    - 本次容量 vs 上次同动作容量
    - 新 PR 标记
    - 下次建议：补组 / 降 5% / 控 RPE 8 / 加 2.5% 或 +1 次
  - `PlanReviewEngine` 新增 `PlanAdherence`：计划日、完成、跳过、错过
  - 跳过日不计入完成率分母；未来计划日不算错过
  - 只有训练记录覆盖计划组数才算完成计划日，练一半仍算错过
  - 复盘新增「计划完成率」KPI 和「训练明细」里的跳过/错过行
  - 复盘新增一个 `ReviewNextAction`：补一次错过训练 / 降低每周频率 / 降强度 / 记录饮食 / 保持并加重
  - 行动卡按钮直接切到教练页或首页
- 后端：
  - 新增 `_plan_week_adherence`：按 `plan_day_states.assigned_date` 统计，没有排期时按计划创建周回退
  - 周复盘改为使用实际计划日，不再只用 `profile.weekly_days`
  - 计划日完成判定：关联 `program_day_id` 的训练记录完成组数 >= 计划组数
  - `stats` 增加 `planned_days` / `completed_plan_days` / `skipped_plan_days` / `missed_plan_days` / `adherence_rate`
  - 复盘文案和 action 同步改成“计划 N 次、完成 X、跳过 Y、错过 Z”
- 验证：
  - 后端 **319 passed**，Ruff 通过
  - 新增 `test_weekly_review.py`：完成/跳过/错过/完成率
  - 新增 `PlanReviewEngineTests`：跳过不进分母、练一半不算完成、错过训练优先成为下一步
  - `Backend Tests`、`Coach Eval` 在 `b462fcb` 通过
  - `iOS Build` 在 `8420dde` 通过（`8420dde` 仅补 RPE 类型标注、测试断言和文档）
- 部署：
  - 本次没有新迁移；仍需 V31+V32+V33
  - 部署 backend `b462fcb` + iOS `8420dde` 新包
- 已知限制：
  - 复盘完成率只统计当前 active 计划覆盖的日期；旧计划/旧训练没有 `program_day_id` 时不计入计划日完成
  - 服务端计划日回退仍按计划创建周推算，客户端未上传 `assigned_date` 的旧数据可能偏差一天
  - 训练总结卡只显示前 4 个动作，完整明细仍在训练详情
  - 行动卡只负责跳转，不会自动替用户改计划
- 不要恢复：
  - 不要把 `profile.weekly_days` 当作周复盘唯一分母
  - 不要把跳过日算作未完成
  - 不要用“完成训练次数”替代“完成计划日”判断 adherence
  - 不要删除训练总结里的下次负荷建议

### 2026-11-13 · Windows（Onboarding 压缩 + 计划预览确认）

- 代码提交：`0bc6509`
- 背景：首次建档 14 步、体型/体脂必选，用户看到计划前输入太多；生成后计划直接生效，没有预览确认；生成任务不可恢复。
- iOS：
  - onboarding 从 14 步降到 8 步：
    1 称呼
    2 性别
    3 年龄/身高/体重
    4 目标
    5 伤病
    6 器械
    7 经验
    8 每周次数/单次时长
  - 体型、体脂、重点部位、训练地点不再阻塞首版计划，可在之后补充
  - 新增 `PlanPreviewSheet`：展示计划标题、周期、第一周安排；按钮「开始这个计划 / 先调整 / 重新生成」
  - 生成后进入 pending preview，用户确认后才成为当前计划
  - pending preview 持久化，App 重启后仍可确认
  - 本地 fallback 计划确认时走 `PUT /plans/{id}` 上传
  - `2a52eb4`：pending 使用显式 `preview=true`，旧客户端只传 `onboarding=true` 仍直接生成 active，避免旧包/测试账号计划失效
- 后端：
  - onboarding 生成计划保存为 `pending`，不再直接 active
  - 新增 `POST /plans/{plan_id}/activate`：pending 计划激活并归档旧 active 计划
  - `GET /plans/current` 仍只返回 active 计划
- 验证：
  - 后端 **318 passed**，Ruff 通过
  - `Backend Tests`、`iOS Build` 在 `2a52eb4` 均通过
  - `test_plan_sync.py` 增加 pending preview/activate 测试
- 部署：
  - 本次没有新迁移；仍需 V31+V32+V33
  - 部署 backend `0bc6509` + iOS 新包
- 已知限制：
  - preview 的「稍后」会关闭确认页，但服务端 pending 计划会留在库里；没有定时清理任务
  - 体型/体脂/重点部位不再出现在 onboarding，可后续在体型分析/档案中补充
  - 计划预览只展示第一周摘要，不是完整 4 周逐日预览
  - 复盘/饮食计划餐次关联/食物库仍是后续批次
- 不要恢复：
  - 不要恢复 14 步必填 onboarding
  - 不要把 onboarding 计划直接设为 active
  - 不要删除 pending preview 持久化

### 2026-11-13 · Windows（P0 计划服务端化 + 饮食计划回读）

- 代码提交：`93adcf0`
- 背景：训练计划手动编辑只写本地；服务端 PATCH 接口存在但 iOS 没接；本地 fallback 计划服务端没有；训练日期变更会错误递增计划内容版本；饮食计划离开页面后丢失；删除饮食记录会被云端旧数据拉回来。
- 后端：
  - `PATCH /plans/{id}/days/{day_id}` 增加 `expected_plan_version`，冲突返回 409 `PLAN_VERSION_CONFLICT`
  - PATCH 成功后 `Program.version + 1`；同日重复动作 422
  - 新增 `PUT /plans/{id}`：导入本地模板/离线计划/恢复计划；按当前伤病、器械、频率重新校验
  - 导入尽量保留客户端提供的训练日 ID，避免排期状态丢失
  - 新增 `GET /diet/plan?date=YYYY-MM-DD`：回读已保存的当日饮食计划
- iOS：
  - `AppStore.updateDay()` 改为乐观更新 + PATCH；成功合并服务端训练日，失败回滚
  - 本地 fallback、体型分析、本地教练改计划会标记 `planNeedsServerSync`，下次同步自动 `PUT` 上传
  - 登录/回前台拉取 `GET /plans/current`，计划内容可跨设备恢复
  - 训练日期/跳过只更新 `scheduleUpdatedAt`，不再递增计划内容版本
  - 档案保存拆成“仅更新档案 / 更新并重排计划”，不再静默重生成
  - 有训练草稿时禁止优先重生成、恢复计划和应用新计划，避免草稿被静默清空
  - 体型分析应用计划不再重建 day id，保留训练历史和排期引用
  - 饮食页打开时读取已保存计划，不再回到通用本地模板
  - 有服务端每日 targets 时使用服务端目标
  - 客户端热量目标补 1200/1500 kcal 安全下限和 BMI <18.5 减脂保护
  - 饮食记录删除增加 pending 队列，同步成功前不会被云端拉回
- 验证：
  - 后端 **317 passed**，Ruff 通过
  - `Backend Tests` 在 `93adcf0` 通过
  - `iOS Build` 在 `93adcf0` 通过
  - 新增 `test_plan_sync.py`：版本冲突、PATCH 版本递增、本地 ID 导入、旧计划归档、重复动作
  - 新增 `test_diet_plan_saved.py`：每日饮食计划回读和 404
- 部署：
  - 本次没有新迁移；仍需先执行 V31+V32+V33
  - 部署 backend `93adcf0`；iOS 装 `93adcf0` 新包后手动改计划才会走服务端
- 已知限制：
  - 还没有计划预览确认页，onboarding 仍是 14 步
  - 老版本 App 已经存在的“仅本地计划编辑”没有自动迁移标记；需要用户再编辑一次或重新生成才会进入服务端
  - 复盘仍未读取实际计划完成率/跳过/错过；本地复盘和服务端周复盘仍并存
  - 周计划的目标还没有驱动每日饮食页；计划餐一键记录、食物最近/收藏/条码仍未做
  - 计划历史仍是本地最多 5 个版本，没有服务端 revision 表
- 不要恢复：
  - 不要恢复 `updateDay` 的纯本地写入
  - 不要在训练日期变更时递增计划内容版本
  - 不要在档案保存时静默重生成计划
  - 不要在训练草稿存在时清空草稿或替换计划
  - 不要删除饮食记录时忽略远端删除失败

### 2026-11-13 · Windows（P1-8 Agent 请求状态 + 持久幂等 + fallback）

- 代码提交：`e975815`
- 背景：`/agent/chat` 的 `request_id` 幂等缓存只在进程内存里；重启丢缓存，多 worker 各自缓存。模型失败时只返回“请重试”。
- 后端：
  - 新增 `agent_request_state`（V33）：按 `(user_id, request_id)` 保存 `running / completed / failed`、`attempts`、`run_id`、完整响应、过期时间
  - 已完成请求重试直接返回保存的原响应，不再次调用模型、不创建第二条 AgentRun
  - 进行中的重复请求返回 **409** `AGENT_REQUEST_IN_PROGRESS` + `retry_after`
  - 失败请求可立即用同一 `request_id` 重试；超过 330 秒的 running 行视为 worker 崩溃，可接管
  - 过期行在 claim 时清理；TTL 600 秒
  - 新增 `GET /agent/requests/{request_id}`：查询 `running / completed / failed`，running 带 `retry_after`
  - 删除原来的进程内 `_agent_result_cache` / `_agent_request_locks`
  - 模型不可用或调用异常时，优先走 `_mock_reply` 的确定性本地回复（今日训练、动作替换、蛋白等），而不是只给“请重试”
  - 完全无法回答时才返回 failed；失败轮次不写 ChatMessage，避免重试后上下文重复问答，并退回已预占的免费教练额度
- 验证：
  - 后端 **310 passed**，Ruff app/tests 通过
  - `Backend Tests`、`Coach Eval` 在 `e975815` 通过
  - 新增 `test_agent_requests.py`：并发重复、完成回放、失败重试、stale takeover、过期重建、用户隔离
  - 新增 `test_agent_request_routes.py`：重复请求只跑一次、进行中 409、失败轮次不落消息
  - `test_profile_safety.py` 新增模型异常降级、无 LLM 配置降级测试
  - `c8166d2`：输出护栏允许“膝盖疼可以继续练上肢”这类非疼痛部位建议，只拦继续练疼痛动作/带伤加重量
  - 本次没有 iOS 代码变化，未触发 iOS Build
- 部署：
  - **必须先执行 V33**，再部署 backend `e975815`；否则 `/agent/chat` 会因缺表失败
  - 生产待执行迁移现在包括 **V31 + V32 + V33**
  - 旧 iOS 包可继续用；新增 `GET /agent/requests` 暂未被 iOS 调用
- 已知限制：
  - 进行中的重复请求立即返回 409，不在服务端排队等待；客户端可稍后重试或用状态接口查询
  - 失败轮次不落库，后台会话历史只保留成功/待确认轮次
  - Admin CI 仍卡历史 V28 全新库 FK，V33 没有在 Admin CI 里实际跑过；生产 V33 需 Mac 部署时确认
  - `agent_request_state` 的过期清理是 claim 时顺带执行，没有独立定时任务
- 不要恢复：
  - 不要恢复进程内 `_agent_result_cache` / `_agent_request_locks`
  - 不要在没有 `agent_request_state` 表的库上部署 `e975815`
  - 不要在失败轮次后把用户/助手消息写进会话历史
  - 不要把模型失败直接变成用户必须重试；先走确定性本地回复

### 2026-11-13 · Windows（P1-5 生成后安全 + citations）

- 代码提交：`ab12716`
- 背景：前置 `assess_safety` 只能拦用户输入；模型仍可能在正常输入下输出“带伤继续练”、极端饮食、补剂剂量或替代就医。动作引用也只有 mock 回复有，LLM 回复没有可追溯来源。
- 后端：
  - 新增 `reply_guard.py`：回复落库/返回前确定性扫描
  - 覆盖：带伤继续练/疼也加重量、极端断食/催吐/超低热量、补剂或药物剂量、替代就医、直接下诊断
  - 命中后整段替换为安全回复；危险原文不返回、不落库
  - 复用现有 `safety_flag`：`injury_guard` / `medical_referral` / `minor_guard` / `supplement_guard`，没有新增客户端枚举
  - Agent 命中时清空 `actions`，把草案标为 `superseded`，并写一条 `safety` AgentStep
  - `/coach/chat`、`/coach/chat/stream`、`/agent/chat`、`/coach/voice` 都接输出护栏
  - 视觉分析 `coach_vision` 与体型分析 `body_analysis` 的文本建议也过输出护栏
  - 新增 `citations.py`：根据回复文本 + 当前计划 + 服务端动作库生成动作引用
  - 引用带 `slug/name_zh/source/license`；模型编造的动作不会产生引用
  - `/coach/chat` 和 `/agent/chat` 的 assistant `ChatMessage.citations` 落库；Agent 响应新增 `citations`；流式 done 事件也带 `citations`
  - `apply_proposal` 应用前按**当前**伤病、器械、训练频率重新校验；条件变化返回 409，要求重新生成草案
- 验证：
  - 后端 **298 passed**，Ruff app/tests/scripts 通过
  - GitHub `Backend Tests` 和 `Coach Eval` 在 `ab12716` 通过
  - 新增 `test_reply_guard.py`：疼痛继续练、极端饮食、补剂剂量、替代就医、诊断、否定语境、跨句否定
  - 新增 `test_citations.py`：当前计划引用、动作库来源、幻觉动作不引用、数量限制
  - 新增 `test_plan_safety.py`：新增伤病后重新校验、草案应用拒绝、正常草案仍可应用
  - `test_profile_safety.py` 新增 Agent / Coach 输出护栏集成测试
  - `eval.runner --dry-run` 正常加载 100 条场景
  - 本次没有 iOS 代码变化，未触发 iOS Build
- 部署：
  - 本次没有新数据库迁移；仍需先执行 V31 + V32
  - 部署 backend `ab12716` 后生效；iOS 旧包会忽略新增 `citations` 字段，不需要重新装包
- 已知限制：
  - 输出护栏是规则扫描，不是语义审核；它只拦明确危险建议，不替代模型质量评测
  - citations 目前覆盖动作，不覆盖营养/医学外部文献；营养建议仍走确定性计算 + 安全护栏
  - iOS 端还没有渲染 citations 的 UI；当前先保证 API 和落库可追溯
  - 计划草案应用前重新校验会拒绝“生成后档案变化”的旧草案，这是有意的
- 不要恢复：
  - 不要绕过 `reply_guard` 直接把模型原文落库或返回
  - 不要在输出护栏命中后保留待确认 actions / draft proposal
  - 不要把 citations 交给模型自己生成
  - 不要在 `apply_proposal` 里跳过当前档案的重新校验

### 2026-11-13 · Windows（P1-6 上下文预算 + prompt 版本 + 可观测）

- 代码提交：`077823a`
- 背景：教练每组历史和本地 app_context 越来越大，内容会挤占 profile / 当前计划 / 安全上下文；同时无法按 prompt 版本看质量和成本
- 后端：
  - `coach_context_max_chars=24000`；`fit_context_to_budget()` 在上下文进入模型前按优先级裁剪
  - 裁剪顺序：app_context.plan 其他训练日动作 → memories/equipment/recent sessions/body metrics → current_plan.recent/notes → 更激进的列表裁剪 → 最后才动 last/best
  - 今天/进行中的训练日动作始终保留；调用方对象不会被修改
  - 每次上下文带 `context_meta`：`max_chars` / `estimated_chars` / `truncated` / `timezone` / `data_as_of` / `plan_version`
  - 新增 `prompt_registry.py`：prompt 版本 = `kind@sha256(prompt)[:8]`，改文案自动换版本，不靠手改数字
  - `AIJob.prompt_version` 从写死 `v1` 改为真实版本，覆盖 agent / coach / coach_watch / plan / diet_plan / diet_week / memory / coach_vision / food_vision / body_vision / equipment_scan / equipment_gate
  - `AgentRun.prompt_version` 新增；`CoachFeedback.prompt_version` 从对应 run 带入
  - 新增 `V32__agent_prompt_version.sql`；SQLite 开发库由 `ensure_schema()` 补列
  - 新增只读报表：`scripts/coach_observability.py --days 7 [--json]`，聚合 AI 任务状态/延迟/token、Agent 步数/时长、点赞点踩原因和按 prompt 版本的质量
- 验证：
  - 后端 **276 passed**，Ruff app/tests/scripts 通过
  - 新增上下文预算测试（小上下文不动、超大 app_context 裁剪、调用方对象不变）
  - 新增 prompt 版本稳定性/长度/agent 版本测试
  - 新增反馈记录 run prompt 版本测试
  - 新增可观测报表聚合、窗口过滤和文本输出测试
  - GitHub Actions：`Backend Tests` 通过，`Coach Eval` 通过；`Admin CI` 仍卡历史 V28 全新库 FK（`equipment_type_exercises` → `exercises`），与 V31/V32 无关；本次无 iOS 改动，未触发 iOS Build
- 部署：
  - Mac 拉 `077823a` 后先执行 Flyway **V31 + V32**，再部署 backend
  - V31 仍必须先上，否则反馈接口 500；V32 不上则 AgentRun 查询/写入会缺列
  - 本次没有 iOS 代码变化；旧 iOS 包可继续用
- 已知限制：
  - 报表只有 token，没有按模型单价算钱；历史反馈的 `prompt_version` 可能为空
  - 上下文预算只约束 `coach_context`，不含 history（最多 10 条 × 1000 字）和用户消息（最多 4000 字）
  - `context_meta.truncated` 目前只回给模型/日志，还没有做教练端“上下文透明”UI
- 不要恢复：
  - 不要把 `AIJob.prompt_version` 写回固定 `v1`
  - 不要在裁剪时删除今天/进行中训练日的动作
  - 不要在没有 V31/V32 的数据库上部署新的 feedback / AgentRun 代码

### 2026-11-12 · macOS（拉取并验证器械识别 / 动作库格子）

- 分支：`develop`
- 拉取：`fd8e1cf..48539e9`，fast-forward，工作区干净
- 做了什么：
  - `xcodegen generate`，编译并跑 `FitAITests` / `FitAIUITests`
  - phone-only Release 安装并启动 Wu-Tang
- 验证：
  - 编译 **BUILD SUCCEEDED**
  - `FitAITests` **71/71** 通过
  - `FitAIUITests` **4/4** 通过（器械目录 1 条、导航性能 3 条）
  - 新包已安装到 Wu-Tang；首次启动被系统安全拦一次，重试后正常启动
  - 打开后停在登录页（手机号已预填），需要重新收短信验证码登录；不是崩溃
- 未验证：
  - 器械识别实拍：坐姿划船有无 `SEATED ROW` OCR、候选顺序、手动从器械库选择
  - 动作库 1:1 缩略图与卡片等宽等高
  - 训练页 B 版真实交互（仍需登录后手动走）
- Mac 下一步：
  - 登录后拍坐姿划船，检查是否返回 `seated_row`；无 OCR 时走「识别不对？从器械库选择」
  - 动作库看横版/方形/竖版缩略图是否都在 1:1 居中框
  - 继续训练页 B 版验证
- 不要恢复：
  - 不要恢复 `scaledToFill` 裁剪/横版撑宽
  - 不要移除「从器械库选择」兜底
  - 不要在无 OCR 时声称坐姿划船已自动解决

### 2026-11-12 · macOS（TestFlight 分发签名验证）

- 分支：`develop`
- 做了什么：
  - 用 `xcodebuild archive` + `-exportArchive`（`app-store-connect`）验证分发签名
  - 生成 `ios/build/testflight/叫练-0.1.0-1.ipa`（17MB，未提交，`build/` 已忽略）
- 验证：
  - `ARCHIVE SUCCEEDED`、`EXPORT SUCCEEDED`
  - IPA 签名：**Apple Distribution: wu jiekang (ZCHURNA4CM)**
  - 分发证书：Cloud Managed Apple Distribution，到期 2027-11-12
  - 主 App profile：`iOS Team Store Provisioning Profile: com.wjk.fitai`，`beta-reports-active=true`，`get-task-allow=false`
  - Watch App 也在 IPA 内，使用同一分发证书和 Store profile 签名
  - 版本：`0.1.0` / build `1`
- 未完成：
  - 未上传 TestFlight；`altool` 当前没有 App Store Connect API key 或 Apple ID app-specific password
  - 未确认 App Store Connect 是否已创建 `com.wjk.fitai` App 记录
  - 未做 Apple 服务端 validate/upload
- 下一步：
  - 在 App Store Connect 创建/确认 App 记录，Bundle ID `com.wjk.fitai`
  - 提供 ASC API Key（Issuer ID + Key ID + `.p8`）或 Apple ID app-specific password
  - 首次上传 build `1`；若已被占用则递增 `CURRENT_PROJECT_VERSION` 后重 archive
  - 内部 TestFlight 可先上；外部测试再走 Beta App Review
- 注意：
  - TestFlight 安装本身不需要 IAP 商品；但要在测试版里测订阅，仍需 IAP 商品、协议和 App Store Server API Key/p8

### 2026-11-13 · Windows（AI 改课收归服务端）

- 代码提交：`53fdd8c`
- 背景：`modify_workout` 之前只在 iOS 本地改计划，服务端计划不更新；无效/过期/重复动作没有服务端拦截
- 后端：
  - 新增 `workout_actions.py`：swap/sets/reps/weight/rest/remove/add 的服务端校验与执行
  - 校验：动作存在、同日不重复、至少保留一个动作、器械清单、伤病禁忌、sets/weight/rest 范围
  - 版本：`expected_plan_version` 不匹配返回 409 `PLAN_VERSION_CONFLICT`；成功后 `Program.version + 1`
  - 新增 `POST /agent/actions/{id}/dry-run`、`/execute`、`/undo`
  - 幂等：同 `user_id + action_id` 已 executed 直接返回上次结果；undo 后不能重复执行
  - 复用 `AgentActionEvent.detail` 存 `before` / `after_version` / 结果，不需要新迁移
  - `report_action_result` 合并 detail，避免客户端回执覆盖服务端快照
- iOS：
  - `AppStore+AgentActions` 的 `modify_workout` 改为调用 execute API，不再本地 apply
  - 服务端返回计划后，只把目标训练日的动作合并进本地计划，保留本地日期/跳过状态
  - undo 改为调用 undo API；新增 `AppStore+AgentUndo.swift`，避免 type body 超 600
  - `AgentUndoState.serverWorkoutAction(actionID, planID, dayID)`
  - `scope=plan` 暂不支持，明确提示按训练日改
- 验证：
  - 后端 **266 passed**，Ruff 通过
  - `Backend Tests` 和 `iOS Build` 在 `53fdd8c` 均通过
  - 新增 `test_workout_actions.py`（校验/执行/冲突/撤销）和 `test_workout_action_routes.py`（幂等/undo）
- 已知限制：
  - 没有完整 plan sync；如果本地计划版本和服务端不一致，execute 返回 409，需要重新生成改课方案。下一步补 `PUT /plans/{id}` 或按天同步。
  - 服务端返回计划只合并目标训练日，其他本地编辑保留。
  - Admin CI 仍卡在历史 V28 全新库 FK 问题，和本次无关
- 部署：
  - 部署 backend `53fdd8c` 即可；本次没有新数据库迁移
  - 旧 iOS 包仍走本地改课；要服务端执行必须装新包

### 2026-11-12 · Windows（教练消息反馈闭环）

- 代码提交：`cf147b2`
- 后端：
  - `/agent/chat` 返回助手消息 `message_id`（同时保留 `run_id`）
  - 新增 `coach_feedback` 表和 `V31__coach_feedback.sql`；按 `(user_id, message_id)` 唯一，重复提交更新
  - 新增 `POST /agent/feedback`（message 归属、assistant 角色、rating/reason 校验）和 `GET /agent/feedback`
  - 反馈原因白名单：`inaccurate` / `unsafe` / `too_long` / `not_understood` / `other`
- iOS：
  - `ChatMessage` 增加 `serverMessageID` / `serverRunID` / `feedbackRating` / `feedbackReason`
  - 助手消息下显示“有帮助 / 没帮助”；“没帮助”菜单选原因
  - 本地乐观更新，API 失败回滚并 toast
  - `AgentChatResponse` 解码 `message_id`；新增 `APIClient.agentFeedback`
  - 新增 `CoachChatFeedback.swift`、`AppStore+CoachFeedback.swift`；`bubble` 拆成 `bubbleContent + 反馈行`
- 验证：
  - 后端 **262 passed**，Ruff 通过
  - `Backend Tests` 在 `cf147b2` 通过
  - `iOS Build` 在 `cf147b2` 通过
  - 新增 `test_coach_feedback.py` 覆盖创建/更新、跨用户、user 消息、非法 reason
- 注意：
  - `Admin CI` 在 `cf147b2` 失败，但失败点是历史 `V28` 在全新库上的 FK 问题（`equipment_type_exercises` → `exercises`），不是 V31；生产已在 V30，V31 只会追加执行
  - 生产部署需要让 admin-server 跑 Flyway（或手工执行 V31），否则 `/agent/feedback` 会因缺表 500
- Mac 待办：
  - 装新 iOS 包，测每条助手消息的“有帮助 / 没帮助”、失败回滚
  - 部署 backend + V31 migration
- 仍未做：
  - 反馈后台队列/运营页面（当前只有用户自己的 GET）
  - 把 down 样本自动灌入 eval bank（下一步）

### 2026-11-12 · Windows（教练评测 CI 门禁）

- 代码提交：`174d027`
- 做了什么：
  - `eval/runner.py` 新增 `--fail-under` / `--fail-on-safety` / `--baseline`；`--dry-run` 提前到模型 key 检查之前，PR 无 key 也能跑
  - `gate_failures()` 抽成纯函数并加单测；安全门禁只拦截安全内容失败（缺就医/康复师边界），不拦截“安全场景只是句子太长”
  - 新增 `.github/workflows/coach-eval.yml`：
    - PR/push：确定性教练测试 + `eval.runner --dry-run`
    - 夜间/手动：`history_2.jsonl` 必须 100%，`calibration_100.jsonl` 跑 100 条，`--fail-under 0.90 --fail-on-safety --baseline eval/baselines/coach.json`
    - 没配置 `LLM_API_KEY` secret 时跳过真实模型步骤，不误报；结果上传 artifact
  - 新增 `eval/baselines/coach.json`（0.90）
  - 补 prompt 规则 17：关节/腰/颈/肩/膝/肘/腕疼痛必须先停止/减量，并说明何时需要医生/康复师
- 验证：
  - 后端 **259 passed**，Ruff 通过
  - 本地 calibration 20 条：20/20，成本 ¥0.11
  - 本地 calibration 100 条（规则 17 之前）：93/100，安全 12 条中 2 条失败
  - 规则 17 之后单独重跑 `rehab_009` / `rehab_011`：2/2 通过，安全失败 0
  - GitHub Actions `Backend Tests` 和 `Coach Eval` 在 `174d027` 均通过
- 待办：
  - 在 GitHub repo secrets 配 `LLM_API_KEY`，夜间真实模型评测才会运行
  - 下一轮夜间跑完 100 条后，把实际 baseline 固化；当前 0.90 是保守值
  - 后端生产仍未部署；部署 `174d027` 后线上才有每组历史工具 + 评测改动
- Mac / 对方：本轮无 iOS 改动；休息倒计时真机验证仍按上一条执行

### 2026-11-12 · Windows（教练每组训练数据 + 历史工具 + 时区）

- 背景：教练之前只能看到会话级汇总（session_count / total_volume / average_rpe），看不到每组重量、次数、RPE；用户问“卧推为什么没进步”只能猜
- 代码提交：`a751b4c`
- 后端：
  - `training_history.py` 保留原 `load_exercise_history`，新增：
    - `exercise_performance`：每个动作 last / best / recent（最近 3 次，最多 6 组/次）/ session_count
    - `exercise_history_payload`：`get_exercise_history` 工具用；支持自定义动作（不在共享目录也能查）
    - `workout_detail_payload`：`get_workout_detail` 工具用；按动作分组，校验 session 归属
  - `coach_context.py`：当前周计划每个动作带 `last` / `best` / `recent` / `session_count`
  - `agent.py`：`ALLOWED_TOOLS` 增加 `get_exercise_history` / `get_workout_detail`；prompt 加示例和规则 15–16
  - 时区：`build_coach_context` 的 `today` 按 `profile.timezone`（默认 `Asia/Shanghai`）；`run_agent.current_date` 直接用 context 的 today；训练历史日期按 UTC+8
- 验证：
  - 后端 **254 passed**，Ruff 通过
  - 真实 DeepSeek 两条 eval 2/2：
    - “我深蹲最近练得怎么样？” → 调 `get_exercise_history`，回答 `20kg×10×3，RPE 7`，并建议加 2.5kg
    - “我上次训练具体练了什么？” → 调 `get_workout_detail`，回答日期、45 分钟、高脚杯深蹲 3×10
  - 新增 `backend/eval/scenarios/history_2.jsonl`
- 未做：
  - 上下文 token 预算 / 压缩（P1）
  - 服务端 action 验证、反馈闭环、评测 CI（后续 P0）
  - 后端生产未部署；`a751b4c` 需要部署后线上才生效
- Mac / 对方：本轮无 iOS 改动；继续按休息倒计时条目做真机验证

### 2026-11-12 · Windows（休息倒计时后台 / 灵动岛 / 通知 + 设置双开关）

- 背景：用户反馈组间休息倒计时退出 App 后停止；要求灵动岛显示、到 0 震动，并给不喜欢灵动岛的人一个开关
- 代码提交：`3d467a3` + `a612242` + `8b8362b` + `2bfef85` + `09c01e3`（代码 HEAD `09c01e3`）
- 实现：
  - 休息计时从内存 Timer 改为墙钟 `restEndDate`，写入 `WorkoutDraft`；后台/回前台/重启按真实时间恢复
  - 新增 `FitAIWidget` app-extension：锁屏 + 灵动岛 Live Activity，`Text(timerInterval:)` 自动倒计时
  - 新增 `RestLiveActivityManager`；休息开始/更新/跳过/换动作/结束/暂停/完成时 start/update/end
  - 本地通知：App 进后台按 endDate 排 `rest-` 通知，到 0 通知/震动；回前台取消并重算；前台用 `Haptics.warning()`
  - `WorkoutDraft` 新增 `restEndDate`/`restTotalSeconds`；App 重启恢复
  - 设置页新增“休息提醒”卡：`锁屏与灵动岛倒计时` + `休息结束提醒` 两个独立开关
  - 训练提醒“关闭”改为只取消 `workout-`，不再误杀 `rest-`
  - 灵动岛/锁屏点击回训练：`fitai://workout?day=<dayID>` + `RootView.onOpenURL`
  - 顺手修复 `EquipmentRecognitionView` SwiftLint type body error（拆 `matchesSection`），iOS Build 恢复绿
  - 新增 `RestTimerTests`（墙钟取整/夹 0）；iOS Build 只编译不跑单测，需 Mac 跑 `FitAITests`
- 验证：
  - iOS Build CI 在 `09c01e3` 通过；`FitAIWidget.appex` 已构建并嵌入 `FitAI.app/PlugIns`
  - 未做真机验证（Windows 无 Xcode）：需要在 Mac 上 `xcodegen generate`、真机安装
- Mac 待办：
  - `git pull` → `cd ios && xcodegen generate` → Release build/install
  - 首次会注册 `com.wjk.fitai.widget` / `com.wjk.fitai.dev.widget` App ID；确认自动签名
  - 验证：
    1. 完成一组，休息 60s，退后台/锁屏 → 灵动岛/锁屏倒计时继续
    2. 到 0 → 通知/震动；回 App 休息条消失
    3. 休息中跳过/换动作/结束训练/暂停 → Live Activity 立即消失
    4. 下一组重置倒计时
    5. 设置页关掉“锁屏与灵动岛倒计时” → 下一次休息不显示；休息中关掉立即消失；重开恢复
    6. 关掉“休息结束提醒” → 到 0 不通知；App 内前台也不震动
    7. 关闭训练提醒 → 不影响休息提醒
    8. 强制退出 App → 灵动岛继续，通知仍触发
    9. 手表领训 → 手机不重复显示
    10. 点锁屏 Live Activity → 回到当前训练
    11. 无灵动岛机型 → 锁屏显示
- 注意：
  - 后台震动依赖系统通知权限；静音/专注模式可能不震；Live Activity 依赖系统“实时活动”开关
  - 旧包没有 Widget target；必须装新包
  - 未做首次使用提示；如果用户找不到开关，可后续加一次轻提示

### 2026-11-12 · Windows（AI 教练改课 `modify_workout`）

- 背景：用户用账号 `13428104171` 测试“AI 教练改课”，教练只给文字建议，没有出现可确认的改课卡
- 根因：后端 `APP_ACTION_TYPES` 没有 `modify_workout`；用真实 DeepSeek 复现时，模型 reasoning 明确写“没有编辑动作的 action type”，只能 `final` 文字建议。不是模型/网络/账号问题
- 代码提交：`31b2d80`
- 后端：
  - 新增 `modify_workout` action，payload 为 `day_id`/`date` + `scope`（`day`/`plan`）+ `changes[]`
  - `changes` 支持 `swap` / `sets` / `reps` / `weight` / `rest` / `remove` / `add`；最多 8 条；`sets` 1–10、`weight_kg` 0–500、`rest_sec` 0–300；slug 正则校验
  - prompt 增加示例和规则 11–13：改课必须走 `modify_workout`，不能只给文字；换/加动作前先 `lookup_exercise`；默认 `scope=day`
  - `app_context.plan.days` 增加 `exercises`；prompt 注明手机端计划与 `coach_context.current_plan` 冲突时以手机端为准
  - 新增 `test_agent.py` 覆盖合法/非法改课；后端 **248 passed**，Ruff 通过
- iOS：
  - `AgentActionPayload` 增加 `scope`/`changes`；新增 `AgentWorkoutChange`
  - `AppStore+AgentActions` 新增 `modify_workout`：解析目标训练日（默认今天/下一个未完成）、应用 swap/sets/reps/weight/rest/remove/add、`scope=plan` 批量、版本 +1、保存撤销快照
  - `AgentUndoState` 增加 `.plan(TrainingPlan)`，撤销时恢复整份计划
  - `agentAppContext` 的 `plan.days` 增加 `exercises`
  - 新增 `ios/FitAITests/AgentActionDecodingTests.swift`
  - 同时修复 iOS Build 的 SwiftLint `type_body_length` error：把 `EquipmentRecognitionView.matchesSection` 拆到 `EquipmentRecognitionView+Matches.swift`，`scan()` 改为 internal
- 验证：
  - 后端单测/Ruff 通过；真实 DeepSeek 两步实跑：先 `lookup_exercise("哑铃卧推")`，再产出合法 `modify_workout`，`_normalize_app_actions` 通过
  - Backend Tests CI 在 `021e891` 通过；iOS Build CI 在 `69986da` 通过（SwiftLint + simulator build）
  - 仍未做 Mac 真机验证：需要在账号 `13428104171` 上重试“改课”，确认卡片出现、确认后计划动作真的变化、撤销可用
- 部署：
  - 本机 SSH 22 到 `8.218.205.149` 被阻断（TCP timeout），后端 **尚未部署**
  - Mac 需要：`git pull` → `scp`/同步 `backend/app` 到 `/opt/fitai/backend` → `cd /opt/fitai && docker compose build api && docker compose up -d api` → `curl -fsS https://hk-api.jiaolianfit.cn/health/ready` → `cd ios && xcodegen generate` → build/install iOS
  - 部署后确认生产 `POST /api/v1/agent/chat` 能返回 `modify_workout` action；旧 App 会显示“暂不支持操作”，必须装新包
- 注意 / 未做：
  - `modify_workout` 目前只改**本地计划**；服务端计划动作不会同步，教练上下文靠 `app_context.plan.days.exercises` 覆盖
  - 旧 App 不认识新 action，会显示“暂不支持操作：modify_workout”；必须装新包
  - 未做训练中 active session 改课；当前只改计划日
  - 账号 `13428104171` 的具体对话日志未能拉取（SSH 被阻断）；根因由代码 + 真实模型复现确认

### 2026-11-12 · Windows（豆包 lite 坐姿划船/腿类复核 gate 上线）

- 代码提交：`64e3ac0` + `5c16528`；生产已部署 `5c16528`
- 背景：两个 key 都解析到同一账号 `2134326457`；pro 模型仍 `ModelNotOpen`。lite 做全量目录识别又慢又错，但做“坐姿划船 vs 腿举/哈克深蹲”的二元问题很稳
- 实测：
  - lite 二元问题：坐姿划船 → `seated_pull`，哈克深蹲/腿举 → `leg_press`（3/3），单次 6.9 秒
  - 全量目录/短名单在 lite 上不稳定，不能作为主识别
- 后端实现：
  - 新增 `VISION_GATE_*`（base/model/key/enabled/timeout），默认关闭，生产启用
  - 主视觉结果落在腿类且 OCR 没有具体名称时，调用 gate
  - gate 返回 `seated_pull`：主结果改成 `seated_row`，候选只保留 `seated_row` + 原腿类首选（兼容旧 App 的两胶囊布局）；返回 `needs_confirmation=true` 和 warning
  - gate 返回 `leg_press`：保留主结果；gate 失败/超时不影响主结果
  - 同时保留具体 OCR 标签优先、候选顺序、手动从器械库选择
- 生产验证（2026-11-12，部署 `5c16528` 后）：
  - `seated_row-2.jpg` 无 OCR → **`seated_row` 0.9，9.1 秒**，options `["seated_row","hack_squat"]`（修复）
  - `hack_squat-1.jpg` → `leg_press_45` 0.65，options 含 `hack_squat`（Qwen 主结果仍不稳；需手动/候选确认）
  - `leg_press_45-1.jpg` → `leg_press_45` 0.65
  - `chest_press_seated-1.jpg` → `chest_press_seated` 0.92
  - `seated_row-2.jpg` + OCR `SEATED ROW` → `seated_row` 0.95（gate 跳过，4.9 秒）
- 说明：这不是“视觉全量替换 Doubao”。pro 开通后可以把 `VISION_*` 指到 pro；当前 gate 用已开通的 `doubao-seed-2-1-lite-260915` 解决坐姿划船误判
- Key 未写入仓库/交接文档；用户决定不接豆包后已从服务器和本地 `.env` 移除
- 2026-11-12 用户决定：**先继续用 Qwen，豆包暂不接**。已从服务器/本地 `.env` 移除全部 `VISION_GATE_*`，强制重建 API；`vision_gate_enabled=false`、`vision_model=qwen3-vl-plus`，健康检查 ready。代码保留但默认关闭，以后要接再加 `VISION_GATE_*`

### 2026-11-12 · Windows（豆包视觉 API 接入测试）

- 用户提供火山方舟 API key；仅用于本次测试，未写入仓库/交接文档
- 测试结果：
  - key 有效，`GET /api/v3/models` 可以列出模型
  - 但账号 `2134326457` 只开通了 `doubao-seed-2-1-lite-260915`
  - `doubao-seed-2-1-pro-260915`、`doubao-seed-2-0-pro-260215`、`doubao-seed-2-0-lite-260428`、`doubao-seed-2-1-turbo-260628`、Ark 的 DeepSeek v4.1 都返回 `ModelNotOpen`
  - 用已开通的 `doubao-seed-2-1-lite-260915` 跑同一张 `seated_row-2.jpg`：`chest_press_iso` 0.92（错），单张 >50s，不能直接替换生产
  - 用户后来又给了一个 key；实测仍解析到同一个账号 `2134326457`，pro 模型还是 `ModelNotOpen`。换 key 不会改变模型开通状态
- 结论：
  - 不是“只换 key”就能解决；需要先在火山方舟控制台开通豆包 App 实际使用的视觉模型（很可能是 `doubao-seed-2-1-pro-260915`，或用户提供接入点 ID）
  - 开通后用同一批坐姿划船/哈克深蹲/腿举/推胸图做 A/B，通过后再切生产
- 代码层：当前 `VISION_BASE_URL` / `VISION_MODEL` / `VISION_API_KEY` 已是 OpenAI 兼容；lite 模型调用、JSON 解析、`response_format` 都通，开通 pro 后只需改 `.env`
- 生产：Qwen3-VL-Plus + 具体 OCR 标签优先 + 手动从器械库选择 + 豆包 lite row/leg gate（见上一条）；没有全量切到豆包 lite

### 2026-11-12 · Windows（器械识别回归 + 动作库格子统一）

- 分支：`develop`
- 代码提交：`ef4c2f0`（后端 OCR 优先）、`801f0d6`（iOS 格子 + 手动选择）、`d459515`（后端候选顺序修正）、`999466b`（iOS 候选换行）、`b66feb2`（腿类识别歧义提示）、`cba2980`（条件括号整理）；生产已部署 `84c1046`（rebase 前，内容与 `d459515` 等价）
- 器械识别根因（详细实测）：
  - 生产视觉配置正常：`vision=qwen3-vl-plus`、key 已配置、非 mock；最近扫描 `ok`、3–6 秒
  - 但 v3 目录实测：坐姿划船图不带 OCR → `squat_press`/`leg_press_45`；哈克深蹲图 → `leg_press_45`；腿举图 → `leg_press_45`；模型顶层还经常统一给 `hack_squat`。Qwen3-VL-Plus 对这三类器械的图片判别本身不可靠，不是单纯候选顺序问题
  - 提示词、参考图、多图对比、两段式“胸垫/脚踏板”提问都试过，仍不稳定；CLIP 零样本/图搜也区分不了
  - 唯一稳定信号是机身印刷标签：同一张坐姿划船图带 OCR `SEATED ROW` → `seated_row` 0.95（2/2）
- 后端最终策略：
  - `_unique_ocr_match`：OCR 只有唯一命中一个**具体**目录名称时才覆盖视觉结果；`SEATED ROW` 生效，`LEG PRESS`/`ROW` 这类通用词不覆盖
  - 恢复候选优先顺序：腿举图默认仍 `leg_press_45`；模型顶层 `hack_squat` 作为额外候选保留，App 可一键切换
  - 设备扫描日志记录 `model / ocr / primary / options`，方便下次复查
  - 没有启用 temperature 0：实测会让模型更稳定地错判成 `hack_squat`
- iOS：
  - 动作库 `EquipmentPickerExerciseCard`：固定 1:1 图片区，`scaledToFit` 居中，统一底色；所有格子等宽等高，标题固定两行
  - 器械识别新增「识别不对？从器械库选择」：打开 `EquipmentTypePickerView`，选中后填充同样的 candidates/options，保存/计划池逻辑不变
  - 候选胶囊改成自适应网格，模型顶层和候选不一致时能看到 2–3 个选项
- 验证：
  - 后端 **245 passed**，Ruff 通过
  - 生产：`SEATED ROW` OCR 2/2 → `seated_row`；腿举候选优先；无 OCR 坐姿划船仍会被判成腿举/哈克深蹲（模型能力上限，必须靠手动选择）
  - GitHub Actions iOS Build：`999466b` / `b66feb2` / `cba2980` 已 push，macOS runner 排队中；Mac 仍需真机看格子
- Mac 需要做：
  - `git pull` → `xcodegen generate` → 编译 → `FitAITests`
  - 动作库：横版/方形/竖版缩略图都应在一个 1:1 居中框里，所有卡片同宽同高
  - 器械识别：拍一台坐姿划船，确认是否有 `SEATED ROW` OCR；没有就点「识别不对？从器械库选择」→ 搜索坐姿划船 → 看动作候选
  - 训练页 B 版按上一条继续真机验证
- 不要恢复：
  - 不要恢复 `scaledToFill` 裁剪/横版撑宽；用户要的是格子统一、图片居中
  - 不要移除「从器械库选择」兜底；无标签的坐姿划船当前模型分不出来
  - 不要盲目 primary-first（实测会把腿举判成哈克深蹲）
  - 不要在无 OCR 时声称坐姿划船已自动解决；长期需要更强视觉模型或专用 79 类分类器

### 2026-11-12 · macOS（拉取并验证训练页 B 版 / 服务端计划池 / 缩略图）

- 分支：`develop`
- 拉取：`1c83fb2..95fe496`，fast-forward，工作区干净
- 做了什么：
  - `xcodegen generate`，新的训练页文件已加入工程，旧 `WorkoutSetCard` 已移除
  - 编译并跑 `FitAITests` / `FitAIUITests`
  - phone-only Release 安装并启动 Wu-Tang
- 验证：
  - 编译 **BUILD SUCCEEDED**
  - `FitAITests` **71/71** 通过
  - `FitAIUITests` **4/4** 通过（器械目录 1 条、导航性能 3 条）
  - 真机今日页正常加载计划（深色模式），新包已替换旧训练页代码
- 未验证：
  - 训练页 B 版真实交互：左右滑动、底栏记录器、休息胶囊、总结页、演示页视频
  - 首次建档生成计划是否包含 onboarding 器械
  - 动作库 1:1 缩略图与本地媒体兜底
  - 原因：模拟器无登录/计划，真机自动化无法点按
- Mac 下一步：
  - 真机点「开始训练」逐项验证 B 版
  - 建档流程生成一次计划，检查器械动作
  - 动作库横版/方形/竖版缩略图应为 1:1，卡片等宽
- 不要恢复：
  - 不要恢复旧训练页大卡 / 两份输入
  - 不要让客户端上传全量候选池
  - 不要恢复 v1 媒体或横版缩略图

### 2026-11-12 · Windows（问题 2：训练页 B 版 2 页横滑 + 底栏组记录器）

- 分支：`develop`
- 代码提交：`2ac9c08` + `d74857f` + `f22cd87` + `959b6f9`
- 方案：用户选定 B 版
  - 对比稿：`docs/mockups/workout-session-bottom-logger.html`
  - A 版对照：`docs/mockups/workout-session-2page.html`
  - 共享样式：`docs/mockups/workout-mockup.css`
- 做了什么：
  - 训练页从纵向长列表改为 `数据 / 演示` 两页横向滑动（`TabView(.page)`），进度头 / 动作头 / 页签固定
  - 重量、次数、步进、完成全部移到底部固定记录器；休息倒计时并入底栏（脉冲点 + 顶部 2px 进度线 + 跳过）
  - 数据页：今天已完成组、上次/最佳、RPE 步进、换器械、撤销
  - 演示页：1:1 原生比例视频、动作要点、教练提示；视频只在演示页播放，切走自动暂停
  - 删除旧的 `WorkoutSetCard`、`WorkoutRestCard`、`WorkoutSessionActionBar`、`WorkoutSessionExerciseCard`、`WorkoutWeightStepPicker`
  - 新文件：`WorkoutSessionChrome.swift`、`WorkoutSessionDataPage.swift`、`WorkoutSessionDemoPage.swift`、`WorkoutSessionLoggerBar.swift`
  - 交互：页签滑动指示器 + lime 点、数值 contentTransition、长按连续步进、休息脉冲、Reduce Motion、底部渐隐
- 验证：
  - 所有改动的 Swift 文件 tree-sitter 语法通过
  - GitHub Actions `iOS Build` **success**（`959b6f9`）：xcodegen、SwiftLint、FitAIWorkoutCore 测试、iOS 模拟器编译全部通过
  - CI 顺带发现并修复了之前问题 3 的编译错误：`ExerciseMediaStore.installLocalFallbacks` 的 `compactMap` 多语句闭包需要显式 `[ExerciseMediaItem]` / `ExerciseMediaItem?` 类型（`959b6f9`）
  - 本地 Windows 无 Xcode / 无模拟器；`FitAITests` 和真机交互仍未跑
  - `WorkoutSetCard.swift` 已删除，Mac 仍建议 `xcodegen generate` 后再开工程
- Mac 需要做：
  - `git pull` → `xcodegen generate` → 编译 → `FitAITests`
  - 真机重点：
    - 数据/演示左右滑动是否跟手；调重量时不会误切页
    - 底栏重量/次数 +/-、长按连续、点数值精确输入、步进菜单
    - 完成一组：休息胶囊出现；切到演示页仍能看到并跳过
    - 自重动作：重量控件隐藏，只显示次数
    - 数据页：今天组、上次/最佳、用上次、RPE、换器械、撤销
    - 演示页：视频只在当前页播放，切走暂停，切后台暂停；1:1 留白透明
    - 完成最后一个动作 → 下一个动作 / 训练总结；总结页底栏「保存并结束」
    - iPhone SE / 深色模式 / 动态字体 / Reduce Motion
    - Watch-led：完成、跳过、撤销、结束仍走手表
  - 旧 `WorkoutSetCard.swift` 删除后若 Xcode 工程仍引用，重新 `xcodegen generate` 即可
- 不要恢复：
  - 不要把视频放回数据页上方
  - 不要恢复大号动作卡 / “本组数据”标题 / 步进整行 / RPE 横向 Slider
  - 不要恢复旧的底部 action bar；输入只在固定记录器里，避免两份输入
  - 不要让演示页视频在非当前页继续播放

### 2026-11-12 · Windows（计划生成：候选池收回服务端）

- 分支：`develop`
- 代码提交：后端 `26ba205`、iOS `f33d335`；生产已部署后端 `26ba205`
- 问题 4 根因：
  - iOS 把 1,068 个候选 slug 作为 `plan_pool_slugs` 上传；`PlanGenerateIn` 限制 500 → 422（31–86ms），AI 从未被调用
  - 更深一层：候选池有两个事实源（客户端 planPoolSlugs / 服务端 `user_plan_pool_slugs`），客户端可传任意 slug；1,068 个 ID 本来就是重复计算
- 后端修法：
  - 删除 `PlanGenerateIn.plan_pool_slugs` / `equipment_slugs`
  - `generate_plan` / `build_template_plan` 统一用 `user_plan_pool_slugs` 从 DB 派生
  - 新账号（只有默认徒手、没有固定器械）返回空池，按 `profile.equipment` 大类回退，避免新手只拿到徒手计划
  - AI 候选仍由 `_candidate_pool` 均衡采样，上限 96
- iOS 修法：
  - `APIClient.generatePlan` / `PlanGenerationService.generateRemote` 不再发送 pool
  - 生成前 `syncEquipmentForPlanGeneration()` 先同步器械库 + 通用器械；失败直接本地模板并提示「器械库未同步」
  - 422 显示服务端具体原因；其他失败提示「网络或服务异常」，不再一律说「AI 服务不可用」
- 验证：
  - 后端 `pytest` **243 passed**，Ruff 通过
  - 生产容器内：1,068 动作账号 pool=1068、allowed=1068、AI 候选=84
  - 生产 `generate_plan` 实跑：`generated_by=ai`、`model=deepseek-flash`、12 天、0 警告
  - 生产 OpenAPI `PlanGenerateIn` 只剩 force / onboarding / strict_equipment / split / focus
  - 健康检查 ready
- 未验证：
  - iOS 无 Xcode，未编译；真机未跑
- Mac 需要做：
  - `git pull` → `xcodegen generate` → 编译 → `FitAITests`
  - 首次建档后生成计划：确认计划包含 onboarding 选的器械动作，不再只有徒手
  - 同时验证上一条的缩略图 1:1 和本地媒体兜底
- 不要恢复：
  - 不要让客户端上传全量候选池
  - 不要用 500/2000 这类请求上限当业务规则
  - 不要把 422 一律显示成「AI 服务不可用」

### 2026-11-12 · Windows（动作库缩略图 1:1 + 本地媒体兜底）

- 分支：`develop`
- 代码提交：`e549599`
- 问题 1（缩略图横版）：
  - 根因：`EquipmentPickerExerciseCard` 缩略图只固定 `height: 102`，没有宽度/满宽约束；横版图按 intrinsic width 撑开，卡片宽度不齐；纯文字卡缩到内容宽度
  - 修法：缩略图固定 1:1，`AsyncImage` `scaledToFill` + `clipped`；卡片 `frame(maxWidth: .infinity)`；标题 `lineLimit(2, reservesSpace: true)`
- 问题 3（有些动作没视频）：
  - 数据核对：1,394 个动作 / 1,571 条媒体；每个动作都有 `media` / `thumbnail`；`L坐支撑`、`L坐起` 的 v2 poster/video 均返回 200
  - 不是缺媒体；旧 App 仍用 v1 URL/缓存，v1 文件已删除
  - 修法：`ExerciseMediaStore` 先用 `Exercise.mediaVariants` 本地 v2 兜底，再请求 API；API 变体 priority 更高
- 验证：
  - Swift 文件 tree-sitter 通过
  - Windows 无 Xcode，未编译
- Mac 需要做：
  - `git pull` → `xcodegen generate` → 编译 → `FitAITests`
  - 动作库网格：横版/方形/竖版缩略图都是 1:1，卡片宽度一致
  - 训练页：无视频动作应能本地兜底播放/显示 poster
- 未处理：
  - 问题 4（`plans/generate` 422）和问题 2（重量/次数输入）按用户要求下一轮再聊

### 2026-11-12 · macOS（拉取并验证 Windows 媒体 v2 + 器械替换）

- 分支：`develop`
- 拉取：`a88bc04..a324b98`，fast-forward，工作区干净
- 做了什么：
  - `xcodegen generate`，新文件已加入工程
  - 编译并跑 `FitAITests` / `FitAIUITests`
- 验证：
  - 编译 **BUILD SUCCEEDED**
  - `FitAITests` **71/71** 通过（含新增 `ExerciseSubstitutionTests` 6 条）
  - `FitAIUITests` **4/4** 通过（器械目录 1 条、导航性能 3 条）
  - 首页 4 列快捷区、器械详情页截图正常
  - phone-only Release 已安装并启动 Wu-Tang；今日页正常加载现有「推」计划（深色模式）
- 未验证：
  - 训练页「器械被占了」真实交互：需在真机点「开始训练」后手动走候选、替换、跳过
  - 动作视频原生比例 / 1:1 透明盒子的实际播放：需在真机打开动作详情/训练卡确认
  - 本验证基于 `a324b98`，未含 `e549599` 的缩略图 1:1 / 本地媒体兜底
- Mac 下一步：
  - 再拉一次 `e549599`，验证动作库横版缩略图 1:1、卡片宽度一致
  - 真机点「开始训练」→ 动作卡下方「器械被占了？换一个」：验证候选、组数拆分、跳过剩余组
  - 真机看动作详情/训练卡：横版上下透明、竖版左右透明、方形占满，无控制条、不可点
- 不要恢复：
  - 不要恢复 v1 媒体或白边转码
  - 不要用 `VideoPlayer` 黑底
  - 不要在候选为 0 时放宽器械限制

### 2026-11-12 · Windows（原生比例媒体 + 1:1 透明盒子）

- 分支：`develop`
- 代码提交：`c947734`（播放器/转码）+ `17b427e`（资源 v2）
- 根因：
  - `import_vital_catalog.py` 用 `pad=...:color=white` 把竖屏源视频塞进 1080×1080，白边是转码加上去的
  - 详情页用 SwiftUI `VideoPlayer`（默认 fit + 黑底），又套了一层黑边
- 做了什么：
  - 转码改为 `scale={width}:-2`，不 pad、不 crop；方形/横版/竖版保持原生比例
  - 新增 `ExerciseMediaBox`：1:1 透明盒子，`SilentLoopingVideoPlayer` + `resizeAspect`，空余露页面底色
  - 详情页/动作轨迹/训练卡统一使用；去掉白底、padding、全屏点击
  - 播放器 `isUserInteractionEnabled = false` + `.allowsHitTesting(false)`，无控制条
  - 本地缓存 key 加入媒体版本目录，v2 不再命中 v1
  - 导入脚本新增 `--slug` / `--media-version`
- 数据核对：
  - `data/vital/media_manifest.json` 1,571 条，`source_file` 全部能在 `E:\3d健身素材\1500VitalAnimations` 找到
  - 样本：
    - `200-0101` 竖版 720×1072 → 1080×1608
    - `430m-1518` 横版 1310×720 → 1080×594
    - `430f1-1244` 方形 1080×1080 → 1080×1080
  - 桌面样片：`C:\Users\Administrator\Desktop\native_media_samples\`
- 验证：
  - 转码脚本 `py_compile` 通过
  - `200-0101` 脚本样片 1080×1608，无白边
  - Swift 文件 tree-sitter 通过
  - Windows 无 Xcode，未编译
- 全量重导/上传（已完成）：
  - 1,571 条全部重导，`missing=0`；phone/watch/poster 各 1,571，共 4,713 个文件 / 945MB
  - 上传到 `/opt/fitai/media/exercises/vital/**/v2/*`，服务器 v2 文件 4,713 个
  - 备份 `exercise_media_assets` → `/opt/fitai/media_table_backup_20261112.sql`
  - 应用 `data/vital/media_insert.sql`：1,571 条 / 1,571 个 v2 URL / 0 个 v1 URL
  - 生产抽查 `200-0101` v2：HTTP 200，1080×1608
  - `vital_exercises.json` 的 `media` / `thumbnail_url` / `video_url` 5,930 处已从 v1 切到 v2
  - 服务器和本地 v1 目录已删除（各 1,571 个）；服务器媒体目录剩 973MB / 4,713 个 v2 文件
- Mac 需要做：
  - `git pull` → `xcodegen generate` → 编译 → `FitAITests`
  - 真机看详情页/训练卡：1:1 盒子，横版上下透明、竖版左右透明、方形占满；无控制条、不可点
  - 旧 App 缓存可能还命中 v1；新构建的 cache key 已带 v2，必要时删除 App 重装/清缓存
  - 生产媒体已切 v2，不需要再跑批量
- 重跑命令（如需）：
  ```text
  python tools/media/import_vital_catalog.py --transcode \
    --source "E:\3d健身素材\1500VitalAnimations" \
    --media-version v2 --ffmpeg D:\EVCapture\ffmpeg.exe --preset veryfast --jobs 6
  ```
- 回滚：
  - v1 文件已删除；DB 备份 `/opt/fitai/media_table_backup_20261112.sql` 只保留旧 URL，回滚需从源视频重新导出 v1
- 不要恢复：
  - 不要恢复 `pad=...:color=white`
  - 不要把 1:1 裁切/补背景烘进视频
  - 不要用 SwiftUI `VideoPlayer` 做详情页
  - 不要把空余区域填黑

### 2026-11-11 · Windows（训练中器械被占替换）

- 分支：`develop`
- 代码提交：`5d64d44`
- 做了什么：
  - 训练页动作卡下方新增「器械被占了？换一个」入口
  - 底部 sheet 默认给 3 个候选，最多 9 个可「换一批」
  - 候选来源：
    - 70 类固定器械用 `equipment_catalog` 的 exact/similar 动作
    - 哑铃/杠铃/绳索/弹力带等通用器械用 `ExerciseLibrary` 过滤
    - 过滤个人器械、伤病、planEligible、今天已排动作
    - 严格模式只用个人器械；非严格模式不足 3 个时补「非我的器械」候选
  - 个人器械候选 = 0 时，切人工自重兜底：
    - 胸/背/肩/腿/臀/核心分别有白名单
    - 排除负重、跳跃、波比、手枪、倒立、单臂等变式
    - 二头没有自重替代时返回空，不拿三头动作凑
  - 「自己选」是过滤后的轻量列表，不是完整动作库浏览器
  - 替换规则：
    - 已完成 0 组：直接替换当前动作，组数不变
    - 已完成 N 组：原动作保留 N 组，插入替代动作，组数 = 原组数 - N
    - `plannedTotalSets` 保持原总数
    - 历史按 slug 正常分组，先显示原动作 X 组、再显示替代动作 Y 组
  - 跳过改成「跳过剩余组」：未开始则移除动作，已开始则只保留已完成组，不扣完成率
  - `PlanExercise` 新增可选 `sessionSets`，只用于本次训练固定组数，不改后端 schema
- 验证：
  - 用 Python 按同一规则模拟关键数据：
    - 只有坐姿推胸机 -> 个人候选 0 -> 自重兜底
    - 有哑铃但没卧推凳 -> 不出哑铃卧推
    - 有卧推凳 + 哑铃 -> 出哑铃卧推
    - T 杠划船 -> 不出直立划船
    - 牧师凳弯举 -> 二头无自重替代 -> 空
  - 新增 `ExerciseSubstitutionTests` 6 条
  - Swift 文件通过 tree-sitter 解析；Windows 无 Xcode，未编译
- Mac 需要做：
  - `git pull` → `xcodegen generate` → 编译 → `FitAITests`（含 `ExerciseSubstitutionTests`）
  - 真机/模拟器训练页验证：
    - 点「器械被占了」出 3 个候选
    - 换动作后组数/休息不变，重量按新动作历史重置
    - 已完成 1 组再换：记录显示原动作 1 组 + 替代动作剩余组
    - 跳过剩余组：完成率不被扣
    - 严格模式开/关：候选范围不同，非我的器械有标记
    - 个人库为空：出 3 个自重动作
  - 注意 `PlanExercise.session_sets` 只存在本地/草稿；后端忽略，不需要迁移
- 不要恢复：
  - 不要在候选为 0 时静默放宽器械限制
  - 不要用三头动作替代二头
  - 不要把自重兜底混进正常的 3 个器械候选
  - 不要把替换写回下周计划

### 2026-11-11 · macOS（全局 UI 交互打磨）

- 分支：`develop`
- 代码提交：`684cd64`（4 列快捷区随后续提交）
- 做了什么：
  - 新增 `AppLayout.tabBarContentInset = 96`，应用到今日/记录/发现/我的；修复 iOS 26 悬浮 Tab Bar 永久遮挡底部内容
  - 今日页移除 `CaptureFAB`，快捷区改为 4 列一行：记录身体 / 变化 / 问教练 / 拍照识别；消除相机按钮压住「问教练」的点击冲突
  - 教练权益徽章支持 `success` / `loading` / `warning`：加载中显示 ProgressView，8 秒超时显示「权益确认失败 · 重试」，成功才显示 checkmark
- 验证：
  - Debug build **BUILD SUCCEEDED**；`FitAITests` **65/65**
  - UI 截图：iPhone 17 / iPhone SE 4 列快捷区正常；深色模式下今日/教练/我的正常；记录/我的滚动到底内容完整
  - 教练权益超时 UI test 通过（`http://127.0.0.1:9`，8 秒后出现「权益确认失败 · 重试」）
  - 真机：phone-only Release 已安装并启动 Wu-Tang（首次启动因锁屏被拒，解锁后重试成功）
- Windows 需要做：
  - 保留 `tabBarContentInset` 和 4 列一行快捷区；不要恢复悬浮 FAB
  - 真机复测教练权益失败/重试态
- 不要恢复：
  - 不要恢复相机 FAB 覆盖快捷卡
  - 不要把权益确认状态画成 checkmark

### 2026-11-11 · Windows（教练语气：亲切、热情、专业）

- 分支：`develop`
- 代码提交：`fc25555`
- 做了什么：
  - `backend/app/prompts/coach_system.md` 新增「温度」段：
    - 亲切、热情、专业三条边界
    - 每条回复按「接住 → 结论 → 下一步」，可合成 1–2 句
    - 语气跟随：只回“嗯/好”、焦虑、想听解释、开玩笑
    - 饮食回答必须给具体食物和一份的量（鸡胸 100g、鸡蛋 2 个、牛奶 250ml），不能只给克数
    - 训练安排至少给组数/次数/重量/RPE 中的两项
  - 语气示例改暖，新增 PR、饮食、疼痛三个示例
  - `coach_core.py` 的 `_FALLBACK_CORE` 同步
  - `coach.py` 的 `_mock_reply` 同步：没计划、替代、饮食、疼痛、营养/康复 skill、通用
  - `CoachService.swift` 的本地兜底同步
- 验证：
  - backend **237 passed**，Ruff app/tests 通过
  - `coach_core_prompt()` 已包含「温度」；`SYSTEM_PROMPT` 同样包含，iPhone/Watch 共用
  - Watch 仍受 `WATCH_VOICE_INSTRUCTIONS` 的 1–3 句限制
  - Swift 文件通过 tree-sitter 解析；Windows 无 Xcode，未编译
- Mac 需要做：
  - `git pull` → `xcodegen generate` → 编译 → `FitAITests`
  - 真机看教练对话：累、疼痛、蛋白、器械被占四种问法
  - 确认回复不超过 3 句、有数字/动作、无「宝子/亲爱的/兄弟」等禁词
- 不要恢复：
  - 不要把饮食回答退回只给克数
  - 不要让教练用「小白/宝子/亲爱的/兄弟」称呼
  - 不要为了热情连用感叹号或 emoji

### 2026-11-11 · Windows（器械动作白名单 + 同类动作拆分）

- 分支：`develop`
- 代码提交：`f343ea0`
- 问题根因：
  - T 杠划船机使用旧 `seated_row` 分组，组里混入了直立划船、硬拉接直立划船等动作
  - 同类问题还影响低位/高位/杠杆划船、胸推、助力双杠、三头、二头、后踢、颈部等
- 做了什么：
  - 70 类器械全部改为人工核对的 `exercise_slugs`（可练动作 = 这台器械直接能做的动作）
  - 显式空数组表示“没有专用动作”，不再回退到旧 `exercise_group`
  - 新增 `similar_exercise_slugs`：同类动作单独展示，标注“不同器械，仅供参考”，**不默认启用、不进计划池**
  - T 杠划船机现在：
    - 可练动作：`T杆划船`
    - 同类动作：俯身杠铃划船、哑铃单臂划船、潘德雷划船、耶茨划船、梅多斯划船、器械划船
    - 不再出现直立划船、硬拉接直立划船
  - 器械详情新增「同类动作」区块，与「可练动作」分开
  - 新增 `EquipmentCatalogActionTests`：T 杠/划船机不得把直立划船作为直接动作；显式动作必须存在且 planEligible
- 数据验证：
  - 70 类目录、70 份 guide、81 张图；所有 exact/similar action slug 均存在且 planEligible
  - 生成了 146 条同类动作映射
  - 无后端改动、无数据库迁移、未重新上传图片
- 未验证：
  - Windows 无 Xcode，iOS **没有编译和真机运行**；只做了 tree-sitter 和 JSON 校验
- Mac 需要做：
  - `git pull` → `xcodegen generate` → `FitAITests`（含新增的 `EquipmentCatalogActionTests`）→ `EquipmentCatalogUITests`
  - 打开 T 杠划船机详情确认：可练动作只有 T杆划船；同类动作单独一块；不生成直立划船
  - 抽查坐姿/低位/高位/杠杆划船、坐姿推胸机、助力双杠、后踢腿机
- 不要恢复：
  - 不要在 `exercise_slugs` 为空时回退到旧 `exercise_group`
  - 不要把「同类动作」默认启用或写入计划池

### 2026-11-11 · Windows（共享目录组件 + 器械页布局修复）

- 分支：`develop`
- 代码提交：`7d468da`
- 做了什么：
  - 抽取 `CatalogComponents.swift`：
    - `CatalogSearchField`（含可选 trailing，动作库相机按钮继续复用）
    - `CatalogSidebarContainer` / `CatalogSidebarButton` / `CatalogSidebarSubButton` / `CatalogSidebarChildren`
    - `CatalogTwoColumnLayout`（可选侧栏）
    - `CatalogEmptyCard`
  - 动作库和器械库都改用同一套搜索框、侧栏、两栏布局；动作库的训练类型/器械筛选/多选逻辑不变
  - 器械库网格改为 adaptive 列 + 卡片/图片显式宽度约束，修复截图里的卡片横向重叠、文字左侧被裁
  - 器械详情 Hero 改为 1:1 容器内 `.fit`，不再用固定高度 + `.fill` 裁图；图片按完整比例显示
  - 卡片缩略图仍保持 fill + clipped
- 数据/接口：无后端改动，无数据库迁移
- 未验证：
  - Windows 无 Xcode，iOS **没有编译和真机运行**；只做了 tree-sitter 语法解析
  - Mac 侧的 `EquipmentCatalogUITests` 需要重跑并重新看截图
- Mac 需要做：
  - `git pull` → `xcodegen generate` → Debug build + `EquipmentCatalogUITests`
  - 重点看：器械库卡片是否两列不重叠、长名称不再被左侧裁切；详情 Hero 图片是否完整显示；动作库侧栏/搜索是否与改造前一致
- 不要恢复：
  - 不要恢复两套独立的搜索框/侧栏实现
  - 不要把详情 Hero 改回固定高度 + `scaledToFill`

### 2026-11-11 · macOS（器械目录 v3 UI 验证）

- 分支：`develop`
- 代码提交：`0dbdbcd`（UI test）
- 做了什么：
  - 拉取 `dd59304`，`xcodegen`；catalog validator **ok**；Debug build **BUILD SUCCEEDED**；`FitAITests` **62/62**
  - 新增 `EquipmentCatalogUITests`：QA bypass auth → 发现 → 我的器械库 → 从器械库添加 → Browser → 坐姿推胸机详情，并保存截图
  - 用 production API 覆盖 Debug API 后，70 类器械图片正常加载；部位计数、图片网格、详情图片、训练部位、使用方法均正常
  - phone-only Release 已安装并启动 Wu-Tang
- Windows 需要做：
  - 保留 UI test；可单跑 `-only-testing:FitAIUITests/EquipmentCatalogUITests`
  - Debug 默认 API 是 localhost；本地后端未启动时器械图片会一直转圈，这是预期，不是 catalog 数据问题；验证图片需生产 API 或本地后端
- 不要恢复：
  - 不要删除 `EquipmentCatalogUITests`
  - 不要恢复旧 95 类 App 目录

### 2026-11-11 · Windows（器械目录 v3：70 类图片目录）

- 分支：`develop`
- 代码提交：`d5292f0`、`3cfe563`（手动添加使用目录动作覆盖）、`dd59304`（Browser 标题/分页样式）
- 做了什么：
  - 以 `E:\Projects\无水印光板健身器械图` 为唯一来源，生成 **70 类物理器械**目录；旧 95 类从 App 目录移除
  - 81 张图 → 70 个名称（8 组多图），压缩到最长边 1000 / JPEG 82，上传到 `/media/equipment-catalog/`
  - 6 个新 slug：`leg_extension_iso`、`leg_curl_lying_iso`、`leg_curl_single`、`glute_bridge`、`deadlift_machine`、`ab_bench`；其余 64 类复用旧 slug
  - 新页面：`EquipmentBrowserView` 左侧按胸/背/肩/臂/腿/臀/核心/有氧/全身，右侧器械图片网格
  - 新 `EquipmentCatalogDetailView`：图片轮播、训练部位、不同部位使用方法（步骤 + 每个目标肌群的发力提示 + 安全提示）、可练动作
  - `EquipmentTypePickerView` / `EquipmentCatalogView` 改为同一个 Browser 的选择/添加模式
  - 通用器械 10 个仍在「我的器械库」勾选；Browser 不显示通用器械
  - 「我的器械库」列表/详情在用户没传照片时回退显示目录器械图片
  - 70 份 guide 生成到 `equipment_guides.json`；对深蹲架、绳索划船、腹部器械、腿屈伸/弯举组合、GHD 等补了显式动作映射
  - 手动添加表单也使用目录的显式动作映射，避免深蹲架/腹部器械默认启用整组动作
  - 新脚本 `scripts/vital/build_equipment_v3.py`；`build_ios_catalog.py` 不再覆盖器械目录
- 数据自测：
  - catalog 70 / guides 70 / iOS catalog 70，slug 集合一致
  - 81 张优化图全部存在；示例 URL `chest_press_seated-1.jpg`、`leg_press_45-3.jpg`、`glute_bridge-2.jpg` 等生产 HEAD **200**
  - 所有 guide 的目标肌群都有 cue；显式 action slug 全部能在 `vital_exercises.json` 找到
  - 后端 **235 passed** + Ruff 通过（本轮无后端代码改动，未重新部署）
- 说明：
  - 旧 95 类只在**后端/识别兼容层**保留，App 已不再展示；未做后端物理删除
  - 新 6 个 slug 目前是客户端目录类型；后端按 `category` 存，计划池仍按 `enabled_exercise_slugs` 走
  - 生产图片目录：`/opt/fitai/media/equipment-catalog/`（81 个文件）
- 未验证：
  - Windows 无 Xcode，iOS **没有编译和真机运行**；只做了 tree-sitter 语法解析和引用/数据检查
- Mac 需要做：
  - `git pull` → `xcodegen generate` → 编译运行
  - 验收：添加页左侧部位栏、右侧图片网格、点卡片进详情；详情图片轮播、部位 chips、使用方法切换；从详情添加/选用；通用器械勾选不变；我的器械库显示目录图片
  - 重点看 `EquipmentBrowserView`、`EquipmentCatalogDetailView`、`EquipmentTypeImageView`、`AddEquipmentView` 的类型选择 sheet
- 不要恢复：
  - 不要恢复旧 95 类 App 目录
  - 不要把通用器械放回 Browser
  - 不要运行 `build_ios_catalog.py` 重新生成旧器械目录（器械目录由 `build_equipment_v3.py` 生成）

### 2026-11-11 · Windows（自定义器械照片上传 + 必选训练部位）

- 分支：`develop`
- 代码提交：`a1c200a`
- 做了什么：
  - **V30**：`user_equipment.target_muscles JSON`；自定义器械（`equipment_type == null`）至少 1 个细分部位，标准目录类型不强制
  - 新增照片服务 `backend/app/services/equipment_photo.py` 和 `POST /equipment/items/{client_id}/photo`；存 `/media/equipment/`，换图删旧图，删器械删照片
  - `photo_url` 由照片接口独占；普通字段同步不再覆盖照片（`model_fields_set` 判断）
  - 教练上下文 / profile 导出带 `target_muscles` 和 `photo_url`
  - iOS：`EquipmentItem.targetMuscles`；添加/编辑自定义器械可选照片、必选多选训练部位；拍照识别补全默认使用刚拍的照片并可更换
  - iOS 同步：`photoData != nil && photoURL == nil` 视为待上传；pull 时同 URL 保留本地图片缓存，换设备/重装可读远端图
  - 器械库列表/详情展示训练部位和远端照片；自定义器械右上角新增「编辑」
- 生产自测（真实 token）：
  - 自定义器械无部位 → **422**
  - 带 `["胸大肌","下胸"]` → **201**，回读一致
  - 真实 JPEG 上传 → **200**，`photo_url` 公网可读且 `content-type=image/*`
  - 只改名称/备注再同步 → 照片保留
  - 换图 → 旧 URL **404**，新 URL **200**
  - 标准目录器械（leg_press）无部位 → **201**
  - 删除器械 → 照片 **404**，列表清除
  - 本地 **235 passed** + Ruff 通过
- 数据库 / 部署：
  - 生产已手动执行 V30，并补记 `flyway_schema_history`：V29（之前漏记）和 V30，均 `checksum=NULL`
  - 后端已重新打包部署 HK，`/health/ready` 正常
  - `/opt/fitai/media/equipment` 已创建，烟测文件已清理，无 `smoke-*` 器械残留
- 未验证：
  - Windows 无 Xcode，iOS **没有编译和真机运行**；只做了 tree-sitter 语法解析、括号/引用/API 存在性检查
- Mac 需要做：
  - `git pull` → `xcodegen generate` → 编译运行
  - 验收：手动添加「自定义」必须选至少 1 个细分部位；拍照识别补全自动带照片；编辑自定义器械可换图；杀进程/重新登录后照片仍在；器械列表显示「胸 · 胸大肌、下胸」
  - 重点看 `EquipmentPhotoCard`、`AddEquipmentView(editingItem:)`、`CustomExerciseAddSheet`、`PhysicalEquipmentDetailView` 的编辑入口
- 不要恢复：
  - 不要把照片只存在本机（会在 pull 时丢失）
  - 不要取消自定义器械的训练部位必选
  - 不要让普通器械字段同步覆盖 `photo_url`

### 2026-11-11 · Windows（动作库二级分类收进左侧栏）

- 分支：`develop`
- 代码提交：`812cb93`、`270989c`（没有二级的「全身」不渲染竖线）
- 做了什么：
  - 删除网格上方的二级分类横条 `categorySubChips`
  - 左侧栏改成手风琴：选中一级后，在它下面缩进显示二级（胸 → 胸大肌、下胸）
  - 切换一级时，上一个一级的二级自动收起；例如点「背」后「胸」的二级隐藏
  - 二级可再次点击取消；搜索时二级收起；侧栏宽度 72 → 80
- 验证：
  - 只做了静态检查（括号平衡、引用清理）；Windows 无 Xcode，**没有编译和 UI 运行**
- Mac 需要做：
  - `git pull` → `xcodegen generate` → 编译
  - 验证：胸/背切换时二级跟随；二级筛选生效；搜索时二级收起；拉伸/灵活性仍有侧栏；有氧/瑜伽/普拉提仍无侧栏
- 不要恢复：
  - 不要恢复 `categorySubChips` 顶部二级横条
  - 不要把二级分类放回网格上方

### 2026-11-11 · Windows（自定义器械流程 + 器械库路由统一）

- 分支：`develop`
- 代码提交：`037c43c`
- 做了什么：
  - `EquipmentLibraryView`：所有条目统一打开 `PhysicalEquipmentDetailView`，删除 `.detail` / 动作详情分支
  - `AddEquipmentView`：删掉「对应动作」，改成「器械类型（目录选择 / 自定义）+ 名称 + 备注 + 照片」；备注现在会持久化
  - 新增 `EquipmentTypePickerView`：可搜索目录类型；排除 10 个通用器械（哑铃/杠铃/徒手等仍在器械库首页勾选，避免重复建实物）
  - 新增 `EquipmentExercisePickerView`：多选 `planEligible` 动作，保存写回 `enabledExerciseSlugs`
  - `PhysicalEquipmentDetailView`：自定义器械展示已关联动作，可移除 / 继续添加；不再跳 `EquipmentPickerView`（训练编排）
  - 清理「个人动作库」旧文案：器械详情、器械识别、首页 toast、教练 notice
- 生产自测（真实 token）：
  - 创建无 `equipment_type` 的自定义器械 `201`，8 个动作回读一致
  - 只用这 8 个动作做 strict 池生成计划：12 天 × 4 动作 = 48，池外 0，8 个动作全部命中
  - 删除器械 `200`；`user_equipment_exercise` 残留 0，无孤儿动作
  - 本地 backend 224 tests + Ruff 通过（本轮无后端改动，无需重新部署）
- 未验证：
  - Windows 无 Xcode / Swift 编译器，iOS 只做了静态检查（括号平衡、引用/API 存在性），**没有编译和真机运行**
- Mac 需要做：
  - `git pull` → `xcodegen generate` → 编译运行
  - 验收：器械库点任意条目进器械详情；手动添加选目录类型 / 自定义；自定义器械加动作后出现在详情和计划池；标准器械动作开关正常；动作库「查看动作」仍进动作详情
  - 重点看 `AddEquipmentView` 的类型 sheet、`EquipmentExercisePickerView` 多选保存、自定义器械详情布局
- 不要恢复：
  - 不要恢复 `EquipmentLibraryView` 的 `.detail` 路由 / `EquipmentItemDetailView(itemID:)` 入口
  - 不要恢复 `AddEquipmentView` 的「对应动作」字段
  - 通用器械不要通过手动添加建成实物（会和首页勾选重复）

### 2026-11-11 · macOS（equipment v2 编译修复 + 真机安装）

- 分支：`develop`
- 代码提交：`6556b0a`（AppStore/PlanGenerator 修复）、`827ea94`（taxonomy v2 测试）
- 做了什么：
  - 拉取 15 个提交后，`build_phone_only.sh` 编译失败：`AppStore.swift` 不是合法 UTF-8，多行中文注释/字符串末尾被写成 `?`，换行丢失，触发 Unterminated string literal
  - 用 `3696b8f` 的合法 UTF-8 版本恢复 `AppStore.swift`，再补回新字段 `selectedUniversalSlugs` / `strictEquipmentMode`，移除 `useEquipmentLibraryForPlans`，`PersistedState` 同步
  - `PlanGenerator.allowedExercises` 中 `let pool` 和 `var pool` 重名，器械池改名为 `equipmentPool`
  - `ExerciseLibraryTests` 更新到 taxonomy v2：8 个一级部位分类、新二级名称、通用器械默认勾选；计划池包含 `other` 器械（TRX/药球等）是本次产品设计
  - 结果：`FitAITests` **62/62** 通过；phone-only Release 构建成功，已安装并启动 Wu-Tang
- Windows 需要做：
  - 检查 Windows 保存 Swift 文件的编码，必须是 UTF-8；本次远端 `AppStore.swift` 本身就是非法 UTF-8
  - 拉取 `develop` 后不要用损坏版本覆盖 `AppStore.swift`
  - 计划池现在是 **809** 条并包含通用器械 `other`，这是设计，不是回归；旧 taxonomy 的 16 分类/旧 L2 测试已更新为 8 分类
- 不要恢复：
  - 不要恢复 `useEquipmentLibraryForPlans`
  - 不要恢复旧的 16 个一级分类测试或旧 L2 名称
  - 不要用非 UTF-8 编码覆盖 `AppStore.swift`
### 2026-11-11 · Windows（生产自测 + 器械分类映射修复）

- 分支：`develop`
- 代码提交：`e5847a1`
- 自测发现：
  - `available_equipment_types` 返回的是器械分类（multi/free_weight），但动作的 `equipment` 是 machine/dumbbell，计划验证对不上
  - 严格池计划只生成了 3 个动作、重复 4 天
- 修复：
  - 器械分类 → 动作 equipment 映射：machine/cable/multi→machine，free_weight→按类型，cardio→bodyweight，accessory→other
  - 通用器械勾选也计入可用器械
  - 有 `plan_pool_slugs` 时，用池内动作的 equipment 作为验证允许集合，避免被裁掉
  - 通用器械 `PUT /equipment/universal` 后刷新 profile 缓存
- 生产自测（真实 token）：
  - `equipment/items` 200、创建器械 201、`universal` PUT/GET 200
  - `exercise-media` 200：3 个 variant，poster/phone 都有
  - `plans/generate` strict 池：12 天 × 4 动作 = 48，0 个池外动作
  - 计划池：bodyweight+dumbbell+smith = 1073
- 注意：
  - 生产 `user_equipment` 里有 Mac 测试加的腿屈伸机（user 13428104171），保留
  - `exercises.video_url` 全为 NULL；`/videos/{slug}` 返回空，iOS 走 catalog 的 `demoVideoURL`，不是回归

### 2026-11-11 · Windows（生产部署 + V29 清理）

- 分支：`develop`
- 代码提交：`90b5973`
- 做了什么：
  - 打包 `backend_deploy.tar.gz`（Dockerfile / requirements / app / data），上传香港服务器，执行 `docker compose build api && docker compose up -d api`
  - 健康检查 `/health` 和 `/health/ready` 均正常，日志无报错
  - 删除临时兼容视图 `equipment_library`（旧后端容器已被新代码替换）
  - **V29**：删除 `exercise_media_assets.license_expires_at` / `purchase_ref`
  - 保留 `sex`（Watch 媒体排序用）/ `source`；保留 `exercises.muscle_group` / `equipment`（计划生成、教练上下文、负荷估算仍在用）
- 验证：
  - 本地 **224 passed**，Ruff 通过
  - 生产健康检查通过；新后端使用 `user_equipment` / `equipment_types` / `equipment_type_exercises`
- 不要恢复：
  - 不要恢复 `equipment_library` 真实表或视图
  - 不要恢复 `exercise_media_assets.license_expires_at` / `purchase_ref`
- 遗留：
  - `exercises.muscle_group` / `equipment` 还要保留一版：计划/教练/负荷估算还在用；下一轮改成 `body_part_code` + 新器械分类后再删
  - `ExerciseVideo` Python model 还在（表已在 V28 删除），只被 legacy MoveKit 安装脚本引用，可后续清理

### 2026-11-11 · Windows（数据库整理 V28：分类/动作/器械入 DB）

- 分支：`develop`
- 代码提交：`301f19f`
- 做了什么：
  - **V28 表结构**：`taxonomy_terms`（68 个分类词）、`equipment_types`（95 类器械）、`equipment_type_exercises`（2648 条映射）
  - **exercises 加分类列**：`training_type_code` / `body_part_code` / `muscle_primary_code` / `muscle_secondary_codes` / `movement_pattern_code` / `plan_eligible` / `content_version`
  - **回填**：1,394 条动作 100% 有训练类型/部位/主肌群；`plan_eligible=1` 共 835 条
  - **清理**：`equipment_library` 改名 `user_equipment`；删除 1 条乱码测试器械；`DROP exercise_videos`；保留旧列一版兼容
  - **后端改为读 DB**：器械识别读 `equipment_types` / `equipment_type_exercises`；计划回退池用 `plan_eligible`；agent 池读 DB 映射；`/videos/{slug}` 改用 `exercises.video_url`
  - **种子脚本**：`scripts/vital/build_taxonomy_db_seed.py` + `data/vital/v28_ddl.sql`，可复现生成 V28
- 生产状态：
  - V28 已应用并记录 flyway `28`
  - **临时兼容视图** `equipment_library` → `user_equipment`：旧后端容器还在跑旧代码，等新后端部署后再 `DROP VIEW equipment_library`
- 验证：
  - 后端 **224 passed**，Ruff 通过
  - 分类：training_type 6 / body_part 8 / muscle 45 / movement_pattern 9
  - 动作：1394 条，分类覆盖 100%，plan_eligible 835
  - 器械：95 类；映射 2648 条，0 死 slug
  - 外键 `user_equipment_exercise.equipment_id` 已随改名指向 `user_equipment`
- macOS / 部署需要做：
  - 部署新后端代码后 `DROP VIEW equipment_library`
  - iOS 本次无代码改动；拉取后确认 catalog 正常
- 不要恢复：
  - 不要恢复 `exercise_videos`
  - 不要把 `equipment_library` 当真实表（只是临时视图）
  - 不要恢复旧的 1 条乱码器械数据

### 2026-11-11 · Windows（发现页重排 + 器械库浏览 + 动作详情清理）

- 分支：`develop`
- 代码提交：`23f92d9`（发现页）、`22ab8d9`（器械库浏览 + class→group）、`e1fb47f`（动作详情）
- 做了什么：
  - **发现页重排**：我的器械库提到 hero（已录入/计划池/覆盖部位/模式）；核心四宫格（动作库/训练方案/饮食方案/体型分析）；工具区（拍照识别/动作点评）；删掉重复的训练分化列表和底部器械库链接
  - **器械库浏览页**（`EquipmentCatalogView`）：复用动作库的搜索/分类 chips/网格卡片；95 类器械（含药球）；固定器械点添加 = 创建实例并默认启用全部力量动作；通用器械点添加 = 勾选
  - **class→group 匹配修复**：iOS 打包 `equipment_catalog.json`，`EquipmentCatalog.group(for:)` 把 94 类 slug 映射到 42 个动作组；`trainableExercises` 改用 group；修复固定器械 0 动作的 bug
  - **器械目录 category 修正**：后端 `category` 从肌肉分类（back/chest）改为器械分类（machine/cable/multi/free_weight/cardio/accessory/bodyweight）
  - **动作详情清理**：Hero 只留标题/名称/pills；删除「动作轨迹」（与教学视频重复）；「多角度示范」注释隐藏；「所需器械」删除「动作来源」，改为显示「你已有」匹配器械 + 去器械库；points tab 改名「动作要点」
- 验证：
  - 后端 **224 passed**，Ruff 通过
  - class→group 抽查：smith_machine→11、leg_press_45→11、chest_press_seated→11、dumbbell→126、barbell→89、bodyweight→387 eligible
- macOS 需要做：
  - `git pull` → `xcodegen` → 编译验证发现页、器械库浏览、动作详情
  - 真机：发现页 → 器械库 → 从器械库添加（搜索/分类/添加）→ 器械详情动作数正确
  - 动作详情：Hero 无重复正文、无动作轨迹、所需器械显示「你已有」
- 不要恢复：
  - 不要恢复发现页的大「AI 器械识别」hero 和训练分化列表
  - 不要恢复动作详情的 hero 正文 / 动作轨迹 / 动作来源
- 遗留：
  - 器械照片跨设备同步
  - 教练 tool

### 2026-11-11 · Windows（计划池改为器械内动作 + 通用器械勾选）

- 分支：`develop`
- 代码提交：`2895db2`
- 做了什么：
  - **删除扁平「个人动作库」**：`user_exercise_library` 表、`/me/exercise-library` 接口、`PersonalExerciseLibraryView`、`personalExerciseSlugs` 全部移除
  - **后端 V27**：新增 `user_equipment_exercise`（固定器械×动作）和 `user_universal_equipment`（通用器械勾选）；生产已应用并记录 flyway V27
  - **通用器械**：10 个勾选（徒手默认），`GET/PUT /equipment/universal`；器械库首页可勾选/取消
  - **固定器械**：`EquipmentItem.enabledExerciseSlugs` 按器械维护；详情页逐动作开关 + 全部加入/移除
  - **计划池**：固定器械启用动作 + 已勾选通用器械动作；器械库首页显示数量与覆盖部位
  - **两种模式**：关闭「只用我的器械」= 计划池 ≥8 用池、不足回退白名单；打开 = 只用计划池（缺部位用已勾选通用器械补），不足不回退
  - **后端计划**：`plan_pool_slugs` + `strict_equipment`；agent 路径从 DB 构建计划池（`user_plan_pool_slugs`）
  - **通用器械映射**：新增 `bodyweight` / `medicine_ball` 动作组，重新生成器械映射与 iOS catalog
  - **分类切换回到顶部**：动作库切换训练类型/部位、器械详情切换训练类型时，列表自动滚回顶部
- 验证：
  - 后端 **224 passed**，Ruff 通过
  - 生产 V27 已应用：`user_equipment_exercise` + `user_universal_equipment`，`user_exercise_library` 已删
  - 通用映射：徒手 942 / 哑铃 126 / 杠铃 89 / 壶铃 26 / 弹力带 50 / 单杠 7 / 双杠 14 / 战绳 6 / 药球 13 / 雪橇 1
- macOS 需要做：
  - `git pull` → `xcodegen` → 编译验证通用器械勾选、固定器械动作开关、计划池覆盖、两种计划模式
  - 真机走：新增器械默认全选 → 详情页取消几个 → 打开/关闭「只用我的器械」各生成一次计划
- 不要恢复：
  - 不要恢复扁平个人动作库（`user_exercise_library` / `personalExerciseSlugs` / `PersonalExerciseLibraryView`）
  - 不要把动作写进器械库；器械库只存器械
- 遗留：
  - 器械照片跨设备同步
  - 教练 tool：加器械 / 勾选动作 / 切换计划模式

### 2026-11-10 · Windows（器械库 v2 + 个人动作库）

- 分支：`develop`
- 代码提交：`e0cf57a`（后端 V26 + 个人库）、`e3d8d9d`（iOS 器械库/个人动作库）、`b059569`（器械详情页）
- 做了什么：
  - **后端 V26**：`equipment_library` 增加 `equipment_type`/`category`/`photo_url`；新增 `user_exercise_library` 表；生产已手动应用并记录 flyway V26
  - **接口**：`GET/POST/DELETE /me/exercise-library`；`/equipment/items` 支持新字段；`/plans/generate` 接受 `exercise_library_slugs`
  - **计划生成**：个人动作库 ≥8 条时严格只用它（仍过滤伤病），不足回退器械池；本地生成同规则
  - **iOS**：`EquipmentItem` 改成物理器械（equipmentType/category/photoURL + trainableExercises）；识别结果改为保存「器械」并把可练动作默认全选加入个人动作库；新增 `PersonalExerciseLibraryView`；器械库行显示「N 个可练动作」；`AppStore.personalExerciseSlugs` 本地持久化 + 云端同步
  - **器械详情页**（`PhysicalEquipmentDetailView`）：Hero + 个人库进度 + 训练类型 Tab + 按部位分组的动作开关 + 全部加入/移除 + 用这件器械生成计划；非力量动作灰标「仅参考」；自定义/0 动作器械有诚实空态
- 验证：
  - 后端 **223 passed**（新增 3 个个人动作库计划池测试），Ruff 通过
  - 生产 V26 已应用：`equipment_library` 新字段 + `user_exercise_library` 表
- macOS 需要做：
  - `git pull` → `xcodegen` → 编译验证新模型字段、识别保存器械、个人动作库页面、计划生成
  - 真机走一遍：拍照识别 → 加入器械库 → 个人动作库 → 生成计划
- 不要恢复：
  - 不要恢复「识别结果保存为动作」的旧逻辑
  - 不要恢复 `equipmentLibrary.compactMap(\.slug)` 作为计划来源
- 遗留：
  - 器械照片目前只本地保存，跨设备同步需要上传接口
  - 教练 tool 还没接 `equipment.add`/`exercise_library.add`

### 2026-11-10 · Windows（动作库分类重做 + 器械目录/映射 + 识别修复）

- 分支：`develop`
- 代码提交：`e655e6a`（taxonomy）、`58e5f2c`（器械映射）、`82b066b`（iOS 接线）、`4eb3fee`（训练类型 Tab）、`d85de7f`（识别修复）
- 做了什么：
  - **动作库分类重做**（`build_taxonomy.py`）：从 1,394 条导出正交维度，替换掉原来混在一棵树里的乱分类
    - 训练类型 6 类：力量 835 / 拉伸 202 / 普拉提 133 / 有氧 88 / 瑜伽 70 / 灵活性 66；瑜伽/普拉提按 pack 独立，不再掺进力量/拉伸
    - 部位 8 类：腿 436 / 核心 350 / 臀 158 / 肩 125 / 背 110 / 臂 96 / 胸 82 / 全身 37（0 条未定）
    - 动作模式：孤立/推/蹲/髋铰链/等长/拉/弓步/旋转/提携（draft，非力量类置空）
  - **器械目录 v2 + 器械→动作映射**（`build_equipment_mapping.py`）：79 类固定器械（来自 E:\opencode\fixed_machines_dataset）+ 15 类自由重量/有氧/小工具 = 94 类；42 个动作组 keyword 映射到 vital 动作；`tibialis`/`multi` 诚实 0 动作
  - **iOS 接线**：catalog 新增 `training_type`/`body_part`/`muscle_primary`/`muscle_secondary`/`movement_pattern`/`equipment_types`；`category_l1`=部位、`category_l2`=主肌群（桥接现有侧栏）；`plan_eligible` 改为「力量 only」（809）；Exercise 模型 + ResourceExercise 解码器加新字段；动作库顶部加训练类型 Tab（力量/拉伸/灵活性按部位侧栏，瑜伽/普拉提/有氧平铺）
  - **识别修复**：删 `equipment_catalog.py`（cm_* 死映射），生成 `equipment_catalog_v2.py`，`equipment.py` 用 `exercises_for()` 映射 vital 动作
  - **废数据清理**：删 `category_classification.csv`（旧乱分类）+ 合并流水线中间产物 4 个 + 空壳 `EquipmentService.swift`；删生产 `_bak_*` 三张表；删旧 `equipment_catalog.py`
- 验证：
  - 后端 **220 passed**，Ruff 通过
  - 抽查：下犬式→瑜伽、战士→瑜伽、百次拍击→普拉提、卧推→力量/胸/推、深蹲→力量/腿/蹲、硬拉→力量/腿/髋铰链
  - 器械映射抽查：腿举 11 / 史密斯 11 / 龙门架 47 / 哑铃 126 / 跑步机 5
- 复核队列（待定默认值）：
  - 下背 55 条 → 默认「核心」（可改「背」）；颈 16 → 肩、斜方肌 14 → 背；混包瑜伽 6 条（平板支撑/反向平板/乌鸦式等）→ 默认瑜伽
  - `data/vital/taxonomy_review.csv`（90 条）+ `equipment_mapping_review.csv`（2 条空组）
- macOS 需要做：
  - `git pull` → `xcodegen` → 编译验证训练类型 Tab、部位侧栏、Exercise 新字段
  - 真机验证动作库按训练类型/部位分类正确、瑜伽/普拉提不掺
- 不要恢复：
  - 不要恢复旧乱分类（`category_classification.csv`、cm_* 映射、`equipment_catalog.py`）
  - 不要恢复 `EquipmentService.swift` 空壳、生产 `_bak_*` 表
- 遗留（下一步）：器械库 UI 改成「物理器械」（照片+类型+可练动作）、识别结果存器械而非动作、个人动作库（user_exercise_library 表 + 视图）、器械照片跨设备同步

### 2026-11-10 · Windows（动作详情多视频切换 + 媒体重转码重传）

- 分支：`develop`
- 代码提交：`9ce7a63`
- 做了什么：
  - 动作详情「动作轨迹」支持多视频切换：iOS catalog 每个动作打进**全部变体**（`media` 数组含 `poster_url`/`video_url`/`visual_style`/`visual_priority`，按视觉优先级排序），详情页 `MotionBoardGallery` 横向缩略图 strip 点选切换循环视频；仅多变体时才显示缩略图
  - 重转码 1,571 条媒体：修复竖屏 720×1072 被拉伸的问题 → 统一 1080×1080 保持原始比例 + 白边填充（`force_original_aspect_ratio`）
  - 清理本地/服务器旧 PoC 占位媒体（crunch/squat/goblet_squat 等 11 目录 + 2 孤儿目录 `vital-close-grip-bench-press-barbell`、`vital-sprint-interval-fast-running`）
  - 清理服务器 `exercise_media_assets` 21 条非 `vital-` 死链（`cm_*` 10 条 + 无前缀 11 条，指向已删除的占位文件）
  - 重新上传媒体 1,124MB / 4,713 文件到 `/opt/fitai/media/exercises/vital/`，重新导入 `data/vital/media_insert.sql` 更新 watch_sha256（重编码后内容变了）
- 验证：
  - 转码 `missing=0 processed=1571`；抽查视频统一 1080×1080
  - SQL watch_sha256 与本地新文件一致（`8999e744…`）；服务器 media 表 **1571 条 / 1394 动作**，与本地 catalog 一致
  - 媒体 URL `HEAD` 返回 **200**（`/media/exercises/vital/vital-ez-bar-biceps-curl/200-0154/v1/iphone.mp4`，613KB）
- macOS 需要做：
  - `git pull` → `xcodegen` → 编译验证动作详情「动作轨迹」多视频缩略图切换、选中高亮
  - 真机验证视频/缩略图加载（服务器已是最新 1080×1080 视频，旧缓存需清）
- 不要恢复：
  - 不要恢复旧 PoC 占位媒体（crunch/squat/male-phone.mp4 等 11 目录）
  - 不要恢复 21 条非 `vital-` media 死链
- 旧占位动作清理（本次已删除）：
  - `exercises` 表 84 条非 `vital-` 旧动作（`cm_*` + 无前缀，`name_zh` 乱码）已删除；级联删除 `plan_exercises` 182 行 + `set_logs` 12 行（引用旧 slug 的失效数据）
  - 归属：`test_reviewer`（is_test=1）48 行计划 + `13428104171`（is_test=0，2026-11-05 注册、仅当天登录）134 行计划 + 12 行日志
  - 外键 `plan_exercises.exercise_slug`/`set_logs.exercise_slug` 是 NO ACTION（非 CASCADE），先删子表行再删父表
  - 备份表保留在生产库：`_bak_exercises_stale`(84)、`_bak_plan_exercises_stale`(182)、`_bak_set_logs_stale`(12)，确认无误后可 `DROP TABLE`
  - 副作用：`test_reviewer` 的旧 3 分化计划动作被清空（plan_exercises 现 0 行），需用新 vital 动作库重新生成演示计划

### 2026-11-10 · macOS（媒体图库 + 训练页视频验证）

- 分支：`develop`
- 代码提交：`8dfc008`（媒体缩略图/训练页视频/折叠说明）、`9ce7a63`（动作详情多 variant gallery）
- 做了什么：
  - 拉取并执行 `xcodegen generate`
  - `python3 scripts/vital/validate_catalog.py`：**ok**
    - exercises=1394 / plan_eligible=776 / media_rows=1571 / media_slugs=1394 / primary=1394
  - Debug build：**BUILD SUCCEEDED**
  - `FitAITests`：**61/61** 通过
- 未验证：
  - 动作详情 gallery 实际切换、训练页视频置顶/说明折叠、器械卡片缩略图
  - 视频缓存/离线、Reduce Motion、全屏
- Windows 注意：
  - Windows 已在顶部补充动作详情/媒体重转码条目；本条目保留 macOS build/test 和 catalog 验收结果
  - 保留 `validate_catalog.py`、`build_phone_only.sh` 和 CI catalog step
- 不要回退：
  - 不要把动作详情 gallery 改回只显示 primary
  - 不要把训练页视频移出顶部或恢复默认展开长说明

### 2026-11-10 · macOS（phone-only Release 构建）

- 分支：`develop`
- 代码提交：`4af3bcb`
- 做了什么：
  - 定位：Release 嵌入 Watch App 后，iPhone App 安装成功但启动报 `invalid code signature / profile not trusted`
  - 移除 `FitAI.app/PlugIns/FitAIWatch.app` 并重签主 App 后可正常启动
  - 根因：Watch App 仍是 iOS 描述文件，不是 watchOS 描述文件；iOS 校验整个包时拒绝了主 App
  - 新增 `ios/scripts/build_phone_only.sh`：解析设备名/UDID → `xcodegen` → Release build → 移除 Watch App → 重签 → 安装 → 启动
  - `ios/README.md` 增加 Watch 签名未就绪时的 phone-only 说明
- 验证：
  - 在 Wu-Tang 跑通脚本：**BUILD SUCCEEDED** → 安装 → 启动成功
  - 启动后截图确认动作库 **1394** 条、16 个一级分类、`other` 已隐藏
  - 这个包不包含 Watch App
- Windows 需要做：
  - Watch 签名解决前，真机 Release 用该脚本或保持 phone-only；不要把 iOS 签名的 Watch App 嵌入手机包
  - Watch 签名需要 Xcode 能看到手表并生成 watchOS profile，或付费团队/手工 watchOS profile
- 不要恢复：
  - 不要删除 `build_phone_only.sh` 和 README 说明
  - 不要在 phone-only 包里放回 `PlugIns/FitAIWatch.app`

### 2026-11-10 · macOS（媒体 coverage 校验）

- 分支：`develop`
- 代码提交：`d890a53`
- 做了什么：
  - 新增 `scripts/vital/validate_catalog.py`：校验动作库与媒体 manifest 的数据契约
  - iOS CI 增加 `Validate catalog data` 步骤；触发路径补充 `data/vital/**`、`scripts/vital/**`
- 校验规则：
  - 每个动作 slug 必须有媒体
  - 每个 slug 有且只有一个 `is_primary_for_watch`
  - 同一 slug 的 `variant_key` 不重复
  - 每条媒体必须有 `source_file` 和正数 `size_bytes`
  - `plan_eligible` 不能出现在 `拉伸`/`有氧`/`热身动作`/`other`
- 验证结果：
  - `exercises=1394 plan_eligible=776 media_rows=1571 media_slugs=1394 primary=1394`
  - 缺失媒体 0、孤儿媒体 0、重复 variant 0、无效媒体行 0
  - 结论：1,571 vs 1,572 只是计数口径差异，媒体覆盖率完整，不需要补假数据
- Windows 需要做：
  - 保留 `validate_catalog.py` 和 CI 步骤
  - 后续新增/删除媒体先跑该脚本
  - 文档里的 1,572 改成 1,571，或只写「1,394 动作全部覆盖」
- 不要恢复：
  - 不要删除 `validate_catalog.py` 或 CI step
  - 不要为了凑 1,572 补假媒体

### 2026-11-10 · macOS（动作库数据源 + 计划白名单 + 分类）

- 分支：`develop`
- 代码提交：`fc8634c`（数据/白名单）、`bc183ae`（分类/测试）
- 做了什么：
  - 给 `vital-captain-s-chair-leg-raise` 补「双杠抬腿」别名；改 `data/vital/vital_actions_v2.json` 后重新生成，未手改生成物
  - `build_ios_catalog.py` 先 `classify` 再算 `plan_eligible`，默认计划池排除 `拉伸`/`有氧`/`热身动作`/`other`；计划池 **810 → 776**
  - `visibleCategoryTree` 隐藏 `other`；一级分类 **17 → 16**；`斜方肌` 暂时保留
  - 新增搜索别名、可见分类、计划池回归测试
- 验证：
  - `FitAITests` **61/61** 通过；Debug build **BUILD SUCCEEDED**
  - 搜索：双杠抬腿 / 臀冲 / B站姿 / EZ杆 / bench press 全部命中
  - 未验证：侧栏实际显示/分页、视频缓存/gallery/Reduce Motion、Watch primary、器械 `other` UI；SwiftLint 本机未安装
- Windows 需要做：
  - 拉 `develop`；计划池现在是 **776**，不是 810，不要恢复
  - 确认 `斜方肌` 是否合并到「背 / 上斜方」；确认 `other` 动作仍可被搜索到
  - 媒体 manifest 1,571 vs 清单 1,572 仍待核对；建议加覆盖率校验，不要为凑数补假数据
- 不要恢复：
  - 不要手改 `ios/FitAI/Resources/vital_exercises.json`；只改 `data/vital/vital_actions_v2.json` 后重新生成
  - 不要把 `拉伸`/`有氧`/`热身动作`/`other` 加回默认计划池
  - 不要把 `other` 加回动作库侧栏

### 2026-11-10 · macOS（develop 编译修复 + 头像单测）

- 分支：`develop`
- 代码提交：`6e95feb`（`ExerciseCategory` init）、`fa9d3c8`（头像 512）
- 做了什么：
  - 拉取 `10d1ad5` / `e0922fc`，按 Windows 清单执行 `xcodegen generate` + Debug build
  - 编译失败：`ExerciseLibrary.swift` 的 `ExerciseCategory` 只有合成的 `init(l1:l2:)`，但 `categoryTree` 使用无标签调用；补 `init(_:_:)`
  - 单测 58 个：`PhotoLibraryLoaderTests.testSquareCroppedProducesSquareAtTargetSize` 失败（800×400 源图输出 400，期望 512）；把 `squareCropped` 改为始终输出 `maxDimension=512`
  - 结果：Debug build **BUILD SUCCEEDED**；`FitAITests` **58/58** 通过
  - SwiftLint 本机未安装，未跑
- 未做：Windows 清单里的两级分类、别名搜索、计划白名单、视频缓存/gallery、Watch primary、器械 other 等功能验证；未做 Release/真机
- Windows 需要做：
  - 拉取 `develop`；编译和头像单测已恢复，不需要再改这两处
  - 继续按 2026-11-10 清单做功能验证；SwiftLint 在 CI/本机补跑
- 不要恢复：
  - 不要删除 `ExerciseCategory` 无标签 init，除非同时改掉 19 处调用
  - 不要把头像裁切改回 `min(短边, 512)`，否则测试和 512 头像契约会再次不一致

### 2026-11-10 · Windows / OpenCode（Mac 构建/验证清单）

- 本轮 iOS 全部是 **盲写**（Windows 无法编译），Mac 拿到后必须按下面清单验证。相关提交：`607eecd`（两级目录 + iOS）、`a3e2761`（隐藏空目录）、`632e9a0`（计划白名单/缓存/搜索）。

**一、构建步骤**

```bash
git pull
cd ios && xcodegen generate        # 会跑 postGenCommand（fix_watch_embed.sh）
# Release build；FITAI_API_BASE_URL 应仍是 https://hk-api.jiaolianfit.cn/api/v1
# SwiftLint + 单测（44+，重点 ExerciseLibraryTests 现在要解码 1,394 条）
```

**二、重点编译风险（盲写，可能报错）**

```text
ExerciseLibrary.swift   ExerciseCategory 结构体 / categoryTree / visibleCategoryTree
Exercise.swift          categoryL1/L2、planEligible、searchKey(改 let)
ExerciseMedia.swift     media_id / visual_style / visual_priority / is_primary_for_watch
ExerciseMediaStore.swift  多 variant（itemsBySlug: [String:[ExerciseMediaItem]]）
ExerciseMediaCache.swift  新增（video+poster 磁盘缓存）
ExerciseAnimationCard.swift  medias 数组 + 图库 gallery + .task 缓存
EquipmentPickerView.swift   分类筛选 + 上拉分页
EquipmentPickerView+Filters.swift  categorySidebar / categorySubChips
Equipment.swift          加了 .other 枚举
LoadProgression.swift    加了 .other case
PlanGenerator.swift      用 planEligible ∪ 用户自选
```

**三、功能验证清单**

1. **动作库两级目录**
   - 侧栏显示 16 个有内容的一级（前锯肌/大圆肌/中下斜方不显示）
   - 点「胸」→ 出现二级 chips 上胸/中下胸；点「背」→ 背阔肌/菱形肌/上斜方/竖脊肌
   - 无二级的一级（核心/有氧/全身/other）不显示 chips
   - 滚到底自动上拉加载（60/次）
2. **搜索（别名）**
   - 搜「双杠抬腿」→ 船长椅屈膝举腿；搜「臀冲」→ 杠铃臀推；搜「B站姿」→ B字步系列；搜「EZ杆」→ EZ杠弯举；搜英文「bench press」→ 卧推系列
3. **计划生成（白名单）**
   - 只用 810 常用动作 + 用户自选；新手计划不出现 瑜伽体式/拉伸/康复 动作
   - 用户器械库自选的动作能进计划
4. **训练页视频**
   - 首次播放下载→缓存，退出重进不重复下载（断网重开仍能播本地缓存）
   - 多视频动作显示缩略图 gallery，点切换，只自动加载 primary
   - Reduce Motion 回退 poster
5. **Watch**
   - bootstrap 每个动作只返回 primary（后端已改，`all=false` 默认）
   - 离线能播
6. **器械筛选**
   - 新增「其他」分类（药球/TRX/战绳/雪橇/波速球）

**四、后端已就绪（真机直连生产即可）**

```text
V25 迁移已应用、1,394 动作 / 1,572 媒体已导入、媒体 1.3G 已上传
/exercise-media?slugs=...&all=true  返回多 variant（按 visual_priority 排序 + is_primary_for_watch）
/watch/bootstrap                      只返回 primary
烟测：vital-back-squat 3 条 variant、vital-cable-rear-delt-fly 2 条、媒体 URL 200
```

**五、遗留（不阻塞 Mac build）**

```text
分类 needs_review 235 条（data/vital/category_classification.csv），可后续人工复核
硬拉/内收肌/颈部/康复 等边界分类先按默认值，等复核再改
```

### 2026-11-10 · Windows / OpenCode（修复重复 + 计划白名单 + 性能）

- 提交：`632e9a0`
- 做了：
  - 修复线上重复：`杠铃卧推`（barbell bench press flat + close-grip 实为正常卧推）合并为 1 条（2 条视频）；`冲刺间歇跑` 删掉 fast 那条（生产 DB 已 UPDATE/DELETE，exercises 1480→1478、media 1593→1592）
  - iOS `Exercise.searchKey` 从 computed var 改成 `let` 一次性算好，搜索不再每键入重算
  - `ExerciseMediaCache` 加 `ensurePosterCached`，poster 也走磁盘缓存（主卡 + 全屏 poster 用本地 URL）
  - **计划白名单**：`Exercise.planEligible`（catalog `plan_eligible` 字段）+ `ExerciseLibrary.planEligible`（常用动作 1,028 条，排除 yoga 包 / cardio 肌群 / `other` 器械 / 拉伸·放松·呼吸·瑜伽·平衡等关键词）
  - `PlanGenerator.allowedExercises`：白名单（常用动作）+ 用户自选动作库（equipmentSlugs）取并集，用户自选无视器械白名单但仍受伤病拦截
- 验证：生产烟测 `vital-barbell-bench-press-flat` 返回 2 variant（URL 指向旧路径文件存在）、sprint fast 0 条、sprint slow 1 条
- 注意：杠铃卧推合并后 DB 媒体 URL 仍指旧 slug 路径（文件在那）；`media_manifest.json`/`media_insert.sql` 重新生成时用 canonical 路径，全量重建需重新转码
- Mac 待办：`git pull` → build，验证计划生成只用白名单+自选、搜索、poster 缓存、图库

### 2026-11-10 · Windows / OpenCode（生产部署：媒体转码 + 上传 + V25 + 导入）

- 提交：`96235aa`（并行转码器）
- 做了（生产 HK 服务器）：
  - 转码 1,572 条源视频 → iPhone 1080（1.06G）/ Watch 360（112M）/ poster（52M），共 1.23G，`missing=0`
  - 上传到 `/opt/fitai/media/exercises/vital/`（1.3G，3,166 个 mp4）
  - 应用 V25 迁移（手动 DDL + flyway_schema_history 记 `checksum=NULL`）
  - 导入 `exercises_insert.sql`（exercises 84→1,480）+ `media_insert.sql`（media 21→1,593）
  - 部署后端新代码（models.py/watch.py/videos.py → docker build + up）
  - 烟测：`media_for_slugs(all_variants=True)` 返回多 variant 按 priority 排序 + `is_primary_for_watch`；`/media/.../iphone.mp4` 返回 200
- 验证：`curl /health` → env=production；`/media/exercises/vital/vital-back-squat/100gym-0054/v1/iphone.mp4` → 200 679260 字节
- 注意：V25 是手动 DDL + 手工记 history（checksum=NULL），下次跑 admin-server Flyway 不会校验 V25，正常
- 服务器临时文件已清理；`/opt/fitai/V25.sql`、`exercises_insert.sql`、`media_insert.sql` 保留作参考
- Mac 待办：`git pull` → build；iOS 代码仍是盲写，需要 Mac 编译验证（ExerciseAnimationCard 图库 / ExerciseMediaCache / EquipmentPickerView 分页 / ExerciseLibrary 全库解码）

### 2026-11-10 · Windows / OpenCode（Vital 全库接入 iOS + 媒体缓存/图库/分页）

- 提交：`f083177`（iOS）+ `bd215fc`（后端 V25）
- 做了：
  - 后端 `V25__exercise_media_variants.sql`：`exercise_media_assets` 加 `variant_key/source_pack/visual_style/visual_priority`，唯一约束改 `(exercise_slug, variant_key, version)`
  - `media_for_slugs` 支持 `all_variants`：手机 `all=true` 返回全部 variant（按 visual_priority 排序 + `is_primary_for_watch`），Watch 默认只返回 primary；`/exercise-media` 加 `all` 参数
  - `tools/media/import_vital_catalog.py`：生成 `exercises_insert.sql`（1,396 条）+ `media_manifest.json`（1,572 条）；`--transcode` 模式做 1080/360/poster 转码 + `media_insert.sql`
  - iOS `Equipment` 枚举加 `.other`（47 个药球/TRX/VIPR/战绳等动作）
  - iOS 动作库换成 Vital 全库：`ExerciseLibrary.all` 读 `vital_exercises.json`（1,396 条），`xunji_movements`/`legacy_exercises` 降级为旧 slug 解析；`ResourceExercise` 加 `aliases/slug_aliases`
  - `Exercise` 加 `aliases/slugAliases/searchKey`；`ExerciseLibrary.search` 用 `searchKey`
  - `EquipmentPickerView`：搜索用 `searchKey`，上拉加载（`visibleLimit` 60/次，筛选项变化重置）
  - `ExerciseMediaItem` 加 `media_id/visual_style/visual_priority/is_primary_for_watch`；`id = media_id ?? exerciseSlug`
  - `ExerciseMediaStore` 改多 variant（`itemsBySlug: [String: [ExerciseMediaItem]]`，primary 排序在前）
  - 新增 `ExerciseMediaCache`（Caches/ExerciseMedia，256MB 软上限，LRU 淘汰）：训练页视频先落盘，重复看不再重复下载
  - `ExerciseAnimationCard`：视频走缓存（`.task` 下载后换本地 URL）；全屏加横向缩略图 gallery，点缩略图切换，只自动加载 primary（懒加载）
  - `APIClient+ExerciseMedia` 请求加 `&all=true`
- 产物：`ios/FitAI/Resources/vital_exercises.json`（984KB，1,396 条，由 `scripts/vital/build_ios_catalog.py` 生成）
- 未验证：**iOS 代码是盲写，没在 Mac 上 build**；需要 Mac 编译 + 单测 + SwiftLint
- 依赖/阻塞：已解决。生产已部署 V25 + 导入 1,396 动作 / 1,572 媒体 + 上传 1.3G 媒体 + 后端多 variant 服务，烟测通过（`vital-back-squat` 返回 3 条 variant 按 visual_priority 排序、`is_primary_for_watch` 正确）
- Mac 待办：`git pull` → `xcodegen generate` → build；重点验证 `ExerciseAnimationCard` 图库、`ExerciseMediaCache`、`EquipmentPickerView` 分页、`ExerciseLibrary` 全库加载（1,396 条解码 + 唯一 slug 单测）
- 禁止：不要把 `vital_exercises.json` 换成训记旧库；`Equipment` 的 `.other` 已在 `LoadProgression` 加 case，不要再删

### 2026-11-09 · Windows / OpenCode（Vital 动作库合并 + 视觉优先级）

- 提交：`a61c681`、`2a98690`
- 做了：
  - 按用户逐条人工判断，对 1,577 个 Vital 动作做了合并/改名/拆分
  - **最终动作库 `vital_actions_v2.json`：1,396 个动作 / 1,572 条媒体**
  - **face/office 预留给第二版：`vital_face_office_v2.json` 130 个动作，不进主库**
  - 每条媒体加了 `visual_style` + `visual_priority`，动作内按优先级排序，标了 `primary_for_watch` 和 `primary_media`
  - 视觉优先级（用户指定）：
    1 灰T恤3D（pack 100/100gym/430m）
    2 金发真人女（430f1/homepilates/yoga）
    3 黑背心真人女（women400）
    4 红背心3D男（200）
    5 肉色背心3D女（430f2/wallpilates）
    6 黑背心3D肌肉建模女（home130）
  - 关键改名（用户确认）：
    - 单腿腿举 → 单腿倒蹬 / 弹力带箭步蹲
    - 哑铃侍者弯举 → 哑铃肩外旋 / 哑铃侍者弯举
    - 后束飞鸟 → 蝴蝶机后束飞鸟 / 坐姿俯身后束飞鸟 / 哑铃俯身后束飞鸟 / 绳索后束飞鸟
    - 坐姿划船 → 坐姿器械划船（含 1620 可移动凳）/ 坐姿绳索划船机
    - 仰卧打水 → 仰卧打水（flutter kick，男）/ 仰卧交叉打水（flutter+flutter kicks，女）
    - 船长椅举腿 → 船长椅屈膝举腿 / 船长椅直腿举腿
    - 蜘蛛弯举 → 蜘蛛弯举 / 交替蜘蛛弯举
    - 侧平板支撑 → 侧平板支撑 / 瑜伽侧板式
    - 仰卧举腿（微屈膝）→ 跪姿弹力带髋外展（band/glutes，英文 kneeling band hip abduction）
  - 产物：
    - `data/vital/vital_actions_v2.json`（主库）
    - `data/vital/vital_face_office_v2.json`（第二版预留）
    - `data/vital/vital_merge_decisions.csv`（逐条决策）
    - `data/vital/duplicates_review_v2.html`（带视频复核）
    - `scripts/vital/apply_decisions.py`（可复现，改 ACTIONS 表再跑）
- 验证：脚本重跑幂等；媒体排序/优先级/primary_for_watch 抽查通过（标准俯卧撑 6 媒体、坐姿器械划船 4 媒体主条=1620 灰T恤3D）
- 未做：
  - 没有接入 iOS/后端/生产库，没转码、没上 OSS
  - 误标视频的英文 instructions 还没重写（弹力带箭步蹲、跪姿弹力带髋外展等，已标 instructions_needs_review=1）
  - 冲刺间歇跑：默认 plural 条当慢速保留、singular 条排除，用户尚未最终确认哪条是慢速
  - 别名已补全（`scripts/vital/enrich_aliases.py`：训记精确名 + 中文术语替换 + 英文变体 + 逐动作别名；主库 avg 2.1/条）
- 对方需要做（Mac）：
  - 等 media 转码 + OSS 后，再谈 iOS 接入；当前 v2 JSON 只是数据草稿，不要直接进包
  - 手机端动作详情要做「主播放区 + 全部视频缩略图切换」，Watch 只下载 primary
- 禁止：不要把 base 训记候选当正式中文名；不要覆盖原 1500 JSON；face/office 别在 v1 上架进动作库

### 2026-11-09 · Windows / OpenCode（Vital 1500 双语动作库草稿）

- 提交：`b63d12e`
- 做了：
  - 新增 `data/vital/`：Vital 1500 + 训记 1213 的合并分析、中文名、中文 instructions、映射草稿
  - `vital_actions_base.json`：**1,577 个唯一动作 / 1,702 条媒体**
  - `vital_actions_zh_draft.json`：中英双语动作草稿
  - `xunji_vital_mapping.csv`：1,213 条训记动作映射
    - exact 287
    - base 663（只作候选）
    - none 263
  - 中文名：
    - `xunji_exact` 246 个（只用训记精确同名）
    - `llm` 1,331 个
    - **base 候选不自动写入正式中文名**，避免「反手俯卧撑 → Bench Dips」这类错配
  - 中文 instructions：1,577 个动作全部生成，全部标记 `instructions_needs_review=1`
  - 人工复核队列：
    - `review_high_videos.csv` / `review_high_videos.html` 243 条（优先看，**含源视频绝对路径，HTML 可直接播放**）
    - `review_medium_videos.csv` 1,107 条
    - `review_low_videos.csv` 227 条
    - `vital_actions_review_videos.csv` 全部 1,577 条（含 `primary_video_path` / `all_video_paths`）
  - 早期无路径的 `review_*.csv` 保留作对照
  - 原始 1500 JSON 没有覆盖；English 原名和 instructions 保留
- 关键事实：
  - 1500 的健身房部分和 800 完全重复（831/831 哈希一致），400 也是子集
  - 1500 真正新增是 866 个家庭视频，总共 1,697 个唯一视频
  - 1500 缺 `200workouts.json`，健身房元数据用 800 包补齐
  - 1500 有 5 组重复视频；90 组同名动作
- 未做：
  - 没有接入 iOS / 后端 / 生产库
  - 训记 `none` 263 条还没有作为独立动作加入
  - 翻译和 base 映射还没有人工逐条确认
- 下一步：
  1. 先看 `data/vital/review_high.csv`（243 条）
  2. 确认中文名/映射后，再生成最终 `vital_movements_zh.json`
  3. 决定训记 263 条 `none` 是否补进动作库
  4. 再做媒体转码、OSS、`exercise_media_assets` 导入
- 禁止：
  - 不要把 base 候选直接当正式中文名；不要覆盖原 1500 JSON
  - 不要把 `review_high` 未确认的数据直接上线

### 2026-11-08 · Windows / OpenCode（Watch 安装失败修复）

- 提交：`cece359`
- 现象：iPhone Watch App「可用 APP」里能看到「叫练」，点安装报：
  `This app could not be installed at this time. Could not install at this time.`
- 最可能原因：**Xcode 26+ 要求 Watch 伴生 App 放在父 App 的 `PlugIns/`**；XcodeGen 2.45.x 仍生成旧版 `Watch/` 目录，导致系统能识别图标但安装失败
- 修复：
  - `ios/project.yml` 增加 `options.postGenCommand: bash scripts/fix_watch_embed.sh`
  - 新增 `ios/scripts/fix_watch_embed.sh`：生成项目后把
    - `dstPath = "$(CONTENTS_FOLDER_PATH)/Watch";` → `dstPath = "";`
    - `dstSubfolderSpec = 16;` → `dstSubfolderSpec = 13;`
    - 已可重复执行；若 XcodeGen 新版本已直接生成 `PlugIns/` 则 no-op
  - **`FitAI` → `FitAIWatch` 依赖增加 `codeSign: true`**：XcodeGen 对嵌入的 executable target 默认不设 `CodeSignOnCopy`，Watch App 被复制进主 App 后签名不完整，会报「无法验证其完整性」
- Mac 侧需要做：
  1. `git pull`
  2. `cd ios && xcodegen generate`
  3. 确认 `FitAI.xcodeproj/project.pbxproj` 里有 `dstSubfolderSpec = 13;`，且没有 `CONTENTS_FOLDER_PATH)/Watch`
  4. 确认 `Embed Watch Content` 的 `FitAIWatch.app` build file 带 `CodeSignOnCopy`
  5. Xcode `Product > Clean Build Folder`，重新 Archive/安装 iPhone App
  6. 打开 iPhone Watch App → 可用 APP → 叫练 → 安装
  7. 如果发 TestFlight：必须重新上传包含该修复的 build，旧 build 不会自动修
- 如果仍然失败，按顺序查：
  - Xcode Debug 安装：Watch 需要 Developer Mode；用 USB 连 iPhone，Xcode → Window → Devices and Simulators → 选配对 Watch → Enable Developer Mode（或 Xcode 提示 Prepare for Development）
  - TestFlight 安装：不需要 Developer Mode；确认 build 里 `FitAI.app/PlugIns/FitAIWatch.app` 存在
  - Apple Developer 后台给 `com.wjk.fitai.watchkitapp`（以及 Debug 的 `com.wjk.fitai.dev.watchkitapp`）开启 **HealthKit** capability，重新生成 provisioning profile
  - Watch 解锁、靠近 iPhone、在充电、存储充足；必要时重启/重新配对
  - Mac Console.app 过滤 `installd` / Watch 相关日志，拿具体错误码
- 禁止恢复：
  - 不要把 Watch App 再嵌回 `Watch/`
  - 不要为了让安装通过盲目把 `SKIP_INSTALL` 改成 NO；先确认 `PlugIns/FitAIWatch.app` 和签名
- 未验证：Windows 无法跑 Xcode/真机安装；需 Mac agent 在 S6 watchOS 11.5 上验证

### 2026-11-08 · Windows / OpenCode（后台样式与生产数据修复）

- 提交：`aae039b`
- 做了：
  - **覆盖缺口重做**：动作媒体页从「一大片标签墙」改成统计卡 + 搜索 + 表格式缺口清单（女版/男版/完全缺失），点击行可直接筛选媒体列表并滚动到表格
  - **动作媒体移动端**：<=720px 改为卡片列表，不再依赖横向滚动表格；<=430px 指标卡改 2 列
  - **指标卡布局**：动作媒体 6 卡改 3 列 × 2 行；会员运营 5 卡改单行 5 列
  - **标签修复**：
    - 目标：`build_muscle` / `recomp` / `lose_fat` 现在显示增肌/重塑/减脂
    - 训练经验：`advanced` → 高级
    - 器械：`bodyweight/barbell/dumbbell/machine/cable` → 中文
    - 识别状态：`not_gym_equipment` → 非健身器械
    - 肌肉部位：`cardio` → 有氧
  - **会员状态**：「启用」改为「有效 / 即将到期 / 已过期 / 已撤销」
  - **Diet 空状态**：生产无饮食数据时只显示一个说明卡，不再堆 4 个大空表；策略分布补上全局 `.dist-*` 样式
  - **图表**：体重趋势使用 `scaleY`，不再从 0 压成一条平线；右侧留白加大避免日期截断
  - **表格宽度**：训练计划「编排」、训练记录「时长」加宽；动作媒体操作改下拉菜单，避免横向溢出
  - 全局补齐 `.panel-heading`、`.chip-row`、`.dist-*` 样式，侧边栏版本文字提亮
  - 二级路由（`/schedule`、`/videos`、`/agent-actions`）进入时高亮对应父菜单
  - **生产数据修复**：
    - `exercises.name_zh`：57 条 `curated_iron_gym` 动作从本机正确库回填；修复前生产为双重编码乱码
    - `equipment_scans.result`：14 条历史扫描 JSON 里的 `name_zh` 用当前动作名回填
    - 备份文件：`%TEMP%\fitai_prod_exercise_names_backup.json`、`%TEMP%\fitai_prod_scan_results_backup.json`
- 验证：
  - Playwright 登录生产 viewer，1440px 截图走查：运营总览、用户管理、会员运营、训练计划、饮食运营、训练记录、教练对话、器械识别、动作库、动作媒体、AI 运营、Agent、审计、排期、旧版视频
  - 390px 截图走查：动作媒体（卡片）、会员运营、饮食运营、器械识别、用户管理
  - 控制台只有登录前一次 401，无业务报错
  - `npm run typecheck`、`npm run test`（3 passed）、`npm run build` 通过
- 未做 / 限制：
  - 会员/器械/用户表格在移动端仍使用横向滚动，只有动作媒体做了卡片化
  - 生产 viewer 媒体上传仍禁用；生产素材用外部 URL 或生产机 admin-server
- 对方需要：
  - `git pull`；无新增 Flyway
  - 前端是 Vite dev 热更新，生产 viewer 刷新即可看到新样式
- 禁止恢复：
  - 不要把 `curated_iron_gym` 的 `name_zh` 再写回双重编码；不要回滚这次生产数据修复
  - 不要把覆盖缺口改回标签墙

### 2026-11-08 · Windows / OpenCode（后台第三批小修）

- 提交：`9fdb334`
- 做了：
  - **生产 viewer 禁止媒体文件上传**：`FITAI_MEDIA_UPLOAD_ENABLED`（默认 true）
    - 生产 viewer 启动脚本设置为 `false`
    - 新增 `GET /api/admin/v1/media-assets/config` 返回 `uploadEnabled`
    - 动作媒体页在关闭上传时隐藏上传按钮，并提示「填写生产可访问 URL 或在生产机运行 admin-server」
    - 旧版视频上传也走同一 `MediaService` 守卫，会返回 400 `MEDIA_UPLOAD_DISABLED`
  - **赠送 Pro 立即生效**：新权益 `starts_at` 回退 1 秒，避免刚赠送后 `pro=false` 的秒级竞态
- 验证：
  - 本地赠送 1 天 → 响应 `pro=true`，`/access` 也是 `pro=true`，测试权益已撤销
  - 本地 `/media-assets/config` → `uploadEnabled=true`
  - 生产 `/media-assets/config` → `uploadEnabled=false`；上传请求返回 400 `MEDIA_UPLOAD_DISABLED`
  - 生产媒体覆盖率/读取接口正常
  - `mvn compile/package`、`npm run typecheck`、`npm run build` 通过
- 注意：
  - 生产 viewer 仍只适合看数据/改元数据/赠送 Pro；真正上传素材需要生产媒体目录或 OSS
  - 生产 viewer 启动脚本只在本机 temp，不在仓库
- 禁止恢复：
  - 不要把生产 viewer 的 `FITAI_MEDIA_UPLOAD_ENABLED` 改回 true，否则会在生产库写入本机 `/media/...` 失效 URL

### 2026-11-08 · Windows / OpenCode（后台第二批功能）

- 提交：`99cbe33`
- 做了：
  - **动作媒体批量导入**：`POST /api/admin/v1/media-assets/import`
    - CSV 表头：`exercise_slug, sex, source, phone_url, watch_url, poster_url, duration_seconds, loop_start_ms, loop_end_ms, watch_sha256, license_note, license_expires_at, purchase_ref, status`
    - 逐行校验，返回行号错误；单次最多 500 行；前端「动作媒体 → 批量导入」支持选文件、下载模板、查看失败行
  - **饮食运营页**：`/diet` + `/api/admin/v1/diet/summary`
    - 餐单总数/近 7 天、饮食记录、近 7 天饮食活跃、30 天平均目标热量
    - 策略分布、生成来源、最近餐单、最近饮食记录
  - **识别质量 + 个人器械库**：`/scans/summary` + `/equipment-library`
    - 识别总数、近 7 天、零候选率、平均候选数、模型分布、14 天趋势
    - 器械识别页新增「识别记录 / 个人器械库」两个 tab
    - 修正识别状态筛选值为真实状态：`ok / succeeded / unknown_equipment / no_actions / unavailable`
  - **训练来源**：`/workouts?source=phone|watch`
    - 训练记录页新增来源筛选和 Watch/iPhone 标签
  - **运营总览**：新增 Pro 会员、动作媒体覆盖率、Watch 训练 7 天、饮食记录 7 天卡片
  - **会员运营**：已有来源筛选可直接看 `storekit` 权益
- 验证：
  - `mvn -q -DskipTests compile/package` 通过
  - 本地 8081 手工冒烟：
    - `/scans/summary` → 13 条、零候选 3、平均候选 1.6
    - `/diet/summary` → 28 份餐单、2517 条饮食记录、平均 2522 kcal
    - `/equipment-library` → 15 条
    - CSV 导入 2 行 → 成功 1、失败 1（错误行号正确），测试记录已删除
    - `/dashboard/summary` 新字段正常
  - `npm run typecheck`、`npm run build` 通过
  - 生产 viewer（`ops_viewer` / CONTENT_OPERATOR）读取：`scans=15`、`dietPlans=0`、`pro=2`、`media=10`
  - 生产 API 未改动：`production / deepseek-flash / qwen3-vl-plus`
- 未做 / 限制：
  - 真实器械 top-1/top-2 命中率仍需要 App 回传用户最终选择；当前只展示候选质量
  - IAP 通知/对账没有后台入口；会员页只能按 `storekit` 来源筛选
  - Watch 没有独立运营页，只有 Dashboard 卡片 + 训练来源筛选 + 用户详情 Watch tab
  - 生产 viewer 的媒体上传仍写本机 `backend/media`，不会同步生产
- 对方需要：
  - `git pull`；无新增 Flyway（仍 V24）
  - 生产 viewer 依赖 SSH 隧道 `13307`、admin-server `8080`、Vite `5173`
  - 看完生产数据后删除/改密 `ops_viewer`
- 禁止恢复：
  - 不要把识别状态筛选改回 `pending/done/failed`，真实状态是 `ok/succeeded/unknown_equipment/no_actions/unavailable`
  - 不要回滚 V24

### 2026-11-08 · Windows / OpenCode（后台第一批功能）

- 提交：`c8d7812`（admin-server + admin-web）；前一提交 `1666cfe` 记录生产 viewer
- 做了：
  - **动作媒体库**：`MediaView.vue` + `/api/admin/v1/media-assets`
    - 列表/筛选/封面预览/草稿/发布/下架/删除；上传 iPhone 视频、Watch 视频、海报
    - 覆盖率：启用动作、已覆盖、男版/女版/中性、Watch/海报/iPhone 就绪、30 天授权到期
    - 覆盖缺口按「女版 / 男版 / 完全缺失」列出，点击动作可筛选
    - 生产现状：启用动作 57，有媒体 10（男 9 / 女 1），Watch/海报 10
  - **用户 360**：`GET /api/admin/v1/users/{id}/insights`
    - 用户详情新增：身体数据趋势 + 记录、饮食餐单 + 饮食记录、排期、Watch 会话/训练、AI 记忆、个人器械库
  - **会员运营**：`MembershipsView.vue` + `/api/admin/v1/memberships`、`/memberships/summary`
    - 全局 Pro 用户、7/30 天到期、来源拆分、7 天新增、30 天撤销
    - 续期/撤销复用 `users/{id}/entitlements`，写审计
  - **菜单收敛**：
    - 新增「会员运营」「动作媒体」
    - 「排期状态」并入「训练计划」入口
    - 「教学视频」降为「动作媒体 → 旧版讲解视频」
    - 「Agent 运行」+「Agent 动作」合并为「Agent 审计」
  - **权限**：Flyway `V24__content_operator_role.sql` 新增 `CONTENT_OPERATOR`
    - 所有 `*:read` + `video:write` + `user:entitlement:write`
    - 不含 `user:write`、`exercise:write`、`plan:write`、`settings:manage`
    - 生产 `ops_viewer` 已从 `AUDITOR` 改为 `CONTENT_OPERATOR`
- 验证：
  - `mvn -q -DskipTests compile/package` 通过；本地/生产 Flyway 均已到 **V24**
  - `mvn test`：单元测试通过；`AdminApiIntegrationTest` 3 个用例被 Testcontainers 跳过（本机 Docker 29 + TC 1.20.6 provider 400），新增的集成测试未实际执行
  - 本地 8081 手工冒烟：media create/update/publish/coverage/unpublish/delete、`/users/{id}/insights`、`/memberships` list/summary 全部 200
  - `npm run typecheck`、`npm run build` 通过
  - 生产 viewer 登录 `ops_viewer` → `CONTENT_OPERATOR`；`/media-assets`、`/memberships`、`/users/{id}/insights` 读取成功
- 未验证 / 未做：
  - 浏览器逐页点击（媒体表单、上传、图表、会员赠送弹窗）只做了编译 + API 冒烟
  - 未实际在生产赠送/撤销 Pro，未改生产媒体
  - **生产 viewer 的媒体上传写在本机 `backend/media`，不会同步到生产**；生产素材应填 OSS/公网 URL，或在生产机运行 admin-server
  - CSV 批量导入、IAP 对账、识别质量看板、安全事件队列留到下一轮
- 对方需要：
  - `git pull`；启动 admin-server 会自动应用 V24
  - 生产 viewer 仍依赖 SSH 隧道 `13307`、admin-server `8080`、Vite `5173`；看完删除或改密 `ops_viewer`
- 禁止恢复：
  - 不要把 `ops_viewer` 改回 `AUDITOR` 后还指望赠送 Pro 或编辑媒体
  - 不要删除/回滚 V24 迁移
- 仍 BLOCKED：
  - 1,500 动作 × 男女素材采购、许可证确认与映射
  - Testcontainers 集成测试需修 Docker provider 或改 CI

### 2026-11-08 · Windows / OpenCode（生产数据只读后台）

- 目的：在本机用管理后台 UI 查看**生产**用户数据，不部署公网后台、不改生产 API
- 结构：
  - SSH 隧道：`ssh -N -L 13307:172.18.0.2:3306 root@8.218.205.149`（生产 MySQL → 本机 13307）
  - 本机 admin-server `8080` 以 `prod` profile 连 `127.0.0.1:13307`（生产库），**不是**本机 3307
  - Vue dev `http://127.0.0.1:5173/admin/` 代理到 8080
- 账号：生产库中临时创建 `ops_viewer`，角色 **CONTENT_OPERATOR**（读全量 + `video:write` + `user:entitlement:write`，无 `user:write`/`settings:manage`）；密码不写入仓库，只在会话/密码管理器里
- 验证：
  - admin 登录 `ops_viewer` 成功，role=CONTENT_OPERATOR
  - `/api/admin/v1/users` 返回生产 3 个用户（wjk / test_reviewer / demo）
  - `/media-assets` 返回生产 21 条媒体；`/memberships` 返回生产 Pro 记录
  - 5173 代理登录 200
- 风险/注意：
  - admin UI 本身可写，CONTENT_OPERATOR 只放开媒体和 Pro 权益；仍不要点用户/计划/动作库的编辑按钮
  - 依赖三个进程同时存活：SSH 隧道、admin-server(8080)、Vite(5173)
  - 查看结束后必须：删除生产 `ops_viewer`（或改密），并关掉隧道/8080/Vite
  - 生产 `.env`、生产 MySQL 密码不要落盘到仓库；启动脚本只放在本机 temp
- 未验证：生产后台的用户详情/训练/计划子页面完整走查（仅验证列表接口）

### 2026-11-08 · Windows / OpenCode（本地后台已启动）

- 本机 Docker MySQL 3307：`fitai-admin-mysql-1` healthy
- Flyway 已从 V21 迁到 **V23**，`exercise_media_assets` 表已创建
- FastAPI 后台：
  - `http://127.0.0.1:8000`
  - `http://192.168.1.4:8000/api/v1`（同一局域网真机可用）
  - `/health` → `{"status":"ok","env":"dev","llm":"deepseek-flash","vision":"qwen3-vl-plus"}`
- 管理后台：
  - Spring admin-server：`http://127.0.0.1:8080`
  - Vue 开发服务器：`http://127.0.0.1:5173/admin/`
  - 登录账号/密码在 `deploy/admin/.env` 的 `FITAI_BOOTSTRAP_*`
  - 本机 admin-server 的 `FITAI_CORS_ORIGINS` 已加入 `http://127.0.0.1:5173` 和 `http://localhost:5173`；否则浏览器登录会 403（仅本地开发配置）
- 说明：
  - Docker 构建 admin-server/admin-web 时 Docker Hub 拉取失败，所以管理后台用本地 jar + Vite dev 跑，不用 Docker 镜像
  - 本地 `exercise_media_assets` 目前为空，动作动画/Watch 媒体需要另行导入；器械识别和 admin 后台不受影响
  - 不要把 `.env`、API Key、MySQL 密码提交到 Git
- 验证：
  - 本地 `/equipment/scan`（Pro 测试用户）Qwen3-VL-Plus 返回 top-2
  - admin 登录成功（admin / boss）
  - admin web 通过 Vite proxy 登录成功
- 未验证：
  - 真机 iPhone 走 `192.168.1.4:8000` 的完整登录/计划/训练链路
  - 本地 Watch bootstrap 媒体（表为空）

### 2026-11-08 · Windows / OpenCode（合并到 develop）

- `develop` HEAD：`48ad5f0`（merge commit）
- 合并：`feature/watch-standalone-workout` → `develop`
- 包含：
  - Watch 独立训练、语音教练、离线 outbox、媒体预载
  - 教练内核统一（iPhone + Watch 同源只读）
  - iPhone 训练页动作循环动画、`/exercise-media`
  - 器械识别图片归一化、OCR、Qwen3-VL-Plus、top-2 候选 + 混淆兜底
- CI @ `48ad5f0`：
  - `Backend Tests` **success**
  - `iOS Build` **success**
  - `Admin CI` **success**
- 生产：已经是同一套代码，无需额外部署
- Mac 下一步：
  - `git pull` 到 `develop`
  - `xcodegen generate` → 构建/测试
  - TestFlight / 真机 Watch 验收
- 不要恢复：
  - 不要把 `develop` 回退到 `48ad5f0` 之前
  - 不要删除器械识别 OCR / top-2 / Qwen 配置

### 2026-11-08 · Windows / OpenCode（器械 top-2 候选 + 混淆兜底）

- 分支：`feature/watch-standalone-workout`
- 做了什么：
  - 后端 prompt 要求模型返回 `equipment_candidates` 前两个
  - 模型只给一个时，按真实照片观察到的混淆对补一个“也可能是”（`equipment_catalog.CONFUSABLES`）
  - API 返回 `equipment_candidates`，每个候选带自己的动作列表
  - iOS 识别结果页显示“最可能是 [A] [B]”，点 B 会切换动作列表
  - `needs_confirmation` 在出现多个候选时为 true
  - 生产后端已重新构建部署，`vision=qwen3-vl-plus`
- 验证：
  - 本地后端 **220 passed**，Ruff 通过
  - GitHub Actions：`Backend Tests` **success** @ `aa17a19`；`iOS Build` **success** @ `0d63191`
  - 18 张用户图（360px 副本 + OCR）：
    - top-1 **11/18 = 61%**
    - top-2 **15/18 = 83%**
  - 生产 `/equipment/scan` 推肩/推胸图返回两个候选，`needs_confirmation=true`
- 未验证：
  - 真机点第二个候选切换动作
  - 高分辨率原图 top-1/top-2
- Mac 下一步：
  - `git pull` → `xcodegen generate` → 构建
  - 真机拍带标签/不带标签的器械，确认两个候选和切换动作
  - 如果第二个候选仍然不对，把照片和两个候选一起发回来
- 不要做：
  - 不要把第二候选说成“模型确定结果”；它只是混淆兜底
  - 不要删除 `CONFUSABLES`，否则 top-2 会退回 61%

### 2026-11-08 · Windows / OpenCode（生产视觉切 Qwen3-VL-Plus）

- 分支：`feature/watch-standalone-workout`
- 做了什么：
  - 生产视觉识别从 `deepseek-flash` 切到 **Qwen3-VL-Plus**（阿里云百炼/DashScope 中国站）
  - 文本教练/计划继续用 DeepSeek，不换
  - `VISION_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1`
  - `VISION_MODEL=qwen3-vl-plus`
  - Key 只写入本机 `backend/.env` 和服务器 `/opt/fitai/.env`，未入库；旧 `.env` 备份权限 600
- 验证：
  - 生产 `/health` 返回 `vision: qwen3-vl-plus`
  - 生产 `/equipment/scan`：`SHOULDER PRESS` → `shoulder_press_machine` 0.95；`CHEST PRESS` → `chest_press_machine` 0.95
  - 本地 `equipment.recognize` 用 Qwen 跑数据集推肩/推胸/椭圆/哈克，结果正常
  - 低分辨率 360px 缩略图不稳定（椭圆/腿举、哈克/髋外展会混），不代表手机原图
- 未验证：
  - 高分辨率真实手机照片的 top-1/top-3
  - 生产 Qwen 的限流/超时/长图
  - 真机 OCR + Qwen 组合
- Mac 下一步：
  - 用 30–50 张高分辨率真实照片跑 A/B（Qwen3-VL-Plus vs qwen3.8-max / qwen3.7-plus）
  - 重点确认推胸/推肩、椭圆/健身车、龙门架/背景器械
  - 真机测试 OCR 标签 + Qwen
- 不要做：
  - 不要把 API Key 提交到 Git 或写进文档
  - 不要删除 `VISION_*` 配置；旧客户端不传 OCR 仍要兼容
- 成本：约 1 元/百万输入、10 元/百万输出；单次扫描约 0.004 元
- 仍 BLOCKED：
  - 高分辨率真实评测集
  - 专用检测器/分类器的真实数据

### 2026-11-08 · Windows / OpenCode（器械识别准确率实验 + OCR 标签）

- 分支：`feature/watch-standalone-workout`
- 做了什么：
  - 用 18 张多品牌真实健身房照片做评测（Hammer Strength / Life Fitness / Inspiration / SHUA / Precor）
  - 对比：当前 prompt、类目短名单、参考图网格、HF 公开数据集 MobileNet 线性探针、CLIP 线性探针
  - 结论：`deepseek-flash` 是当前准确率上限；短名单/参考图收益有限，公开产品图训练的分类器在真实场景不泛化，未接入
  - iOS 新增 `ImageTextRecognizer`（Vision OCR），把机器上的品牌/动作标签随图片上传
  - 后端 `/equipment/scan` 接受 `ocr_text`，匹配目录后作为强证据写入视觉 prompt
  - 拍摄提示改为“把品牌/动作标签一起拍进去”
- 验证：
  - 本地后端 **219 passed**，Ruff 通过
  - GitHub Actions：`Backend Tests` **success** @ `23e41c8`；`iOS Build` **success** @ `23e41c8`
  - 生产 OCR 烟测：`SHOULDER PRESS` → `shoulder_press_machine` 0.92；`CHEST PRESS` → `chest_press_machine` 0.93
  - 生产 `/health`、`/health/ready` 正常
- 未验证：
  - 真机 Vision OCR 中文/英文标签、低光/反光、标签在背景时的误用
- Mac 下一步：
  - `git pull` → `xcodegen generate` → 构建
  - 真机拍带 `SHOULDER PRESS` / `LATERAL RAISE` / `推胸训练器` / `大腿外展训练器` 标签的器械，验证 OCR 是否被正确采用
  - 拍不带标签的器械，确认会回退到视觉模型，不会因 OCR 空字符串报错
- 不要恢复：
  - 不要删除 OCR 字段；旧客户端不传时后端必须兼容（已用 `Form(default="")`）
  - 不要把 OCR 文本直接当唯一结果；它只是强证据，背景标签要忽略
- 仍 BLOCKED：
  - 更强视觉模型（Qwen-VL / Doubao / GPT-4o 级）和 API Key
  - 每类 100+ 张真实健身房照片的检测/分类训练集

### 2026-11-07 · Windows / OpenCode（器械识别修复 + 生产动作库 57 条）

- 分支：`feature/watch-standalone-workout`
- 做了什么：
  - 定位本地 `smoke.db`：`equipment_scan` 实际是 `fallback`，`vision HTTP 400` 后返回 `model=mock` 的随机 3 个动作
  - iOS 新增 `ImageJPEGNormalizer`：相册/相机统一转 JPEG、最长边 1280、修正方向；不再把 HEIC 原始数据当 JPEG 上传
  - 后端新增 `image_input.normalize_image_bytes`：Pillow + pillow-heif，支持 HEIC/PNG/WebP/JPEG，坏图 422；器械/身体/饮食三个接口共用
  - 后端新增 `equipment_catalog.py`：37 类常见器械 + 中英文别名 + 可做动作 slug
  - 视觉 prompt 改为“从目录选 `equipment_slug` + 1–3 个动作”，不再自由发挥中文动作名
  - 视觉失败返回 `status=unavailable`、`candidates=[]`、`warning`；删除随机 mock；iOS 显示重试/手动添加
  - iOS 新增 `warning/status/equipmentName` 解析；空态区分“服务不可用 / 不是器械 / 动作库未收录 / 通用”
  - 生产导入当前 57 条训记动作（旧 27 条保留 inactive）；给示例动画补 `cm_*` 媒体别名
  - 生产部署新 API + `pillow-heif`，Flyway 不变（仍 V23）
- 验证：
  - 本地后端 **217 passed**，Ruff app/tests 通过
  - GitHub Actions：`Backend Tests` **success** @ `5bf99a1`；`iOS Build` **success** @ `5bf99a1`
  - 生产 `/health`、`/health/ready` 正常
  - 生产器械识别真实照片 4 张 + 负例 1 张：腿举/哈克 0.94、椭圆机 0.93、跑步机 0.93、龙门架 0.93、截图 `not_gym_equipment`，**5/5 主判断正确**
  - 龙门架返回 3 个动作候选：绳索夹胸 0.93 / 绳索下压 0.79 / 坐姿划船 0.65
  - `/exercise-media?slugs=cm_squat,cm_leg_press,cm_crunch` 返回 200
  - 生产 `exercises` active=57
- 未验证：
  - 真机相册 HEIC、相机大图、弱网、失败重试 UI
  - 真机身体/饮食拍照（后端已统一归一化，但 iPad/HEIC 组合仍需真机）
  - 更多器械类型（史密斯 vs 深蹲架、不同品牌腿举/哈克一体机）
- Mac 下一步：
  - `git pull` → `xcodegen generate` → 构建/测试
  - 用 Debug/真机分别测试相机、相册 HEIC、大图、非器械截图
  - 验证失败时显示“识别服务暂时不可用 / 重新识别”，不再出现随机动作
  - 验证龙门架返回多个动作候选，腿举/哈克返回腿举/哈克候选
  - 如果 top-3 仍不够，再用 GymBro/GymGuide 23 类数据集做 few-shot/评测；数据集 license 先在 Roboflow 页面核实
- 不要恢复：
  - 不要恢复 `_mock_recognize` 随机候选或 iOS `EquipmentService.recognize` 本地随机匹配
  - 不要把 HEIC 原始数据直接当 JPEG 上传
  - 不要再只靠中文名包含匹配动作
  - 不要把 `active=0` 的旧动作删除；历史计划和媒体仍引用
- 仍 BLOCKED：
  - 1,213 / 1,500 动作全量映射与素材采购
  - 更细的器械分类和真实评测集
  - IAP / App Store API / TestFlight 外部审核等外部项

### 2026-11-07 · Windows / OpenCode（iPhone 动作循环动画 PoC）

- 分支：`feature/watch-standalone-workout`
- 代码提交：`341981f`
- 做了什么：
  - 后端新增 `GET /exercise-media?slugs=...`：认证用户批量取当天动作媒体，最多 20 个，按 `profiles.sex` 优先同性别、再 `unisex`、最后异性回退
  - 抽出 `media_for_slugs`，`/watch/bootstrap` 继续复用同一 resolver
  - iOS 新增 `ExerciseMediaItem`、`APIClient.fetchExerciseMedia`、`ExerciseMediaStore`、`SilentLoopingVideoPlayer`、`ExerciseAnimationCard`
  - 训练页在当前动作标题下、组数输入上插入静音循环动画卡；点击进全屏；Reduce Motion/非 active 显示海报；失败回退海报；音频会话 `.ambient + .mixWithOthers`
  - 训练开始按当天 slug 一次批量预取，切动作读内存缓存；前台恢复会重试失败项
  - 新增 `tools/media/build_vital_sample.py`：720p phone、480p watch、720p poster、manifest、生产 SQL
  - 用 VitalAnimations 免费 sample 发布 11 条映射：squat / hip_thrust / romanian_deadlift / goblet_squat / leg_press / rowing_machine / triceps_pushdown / treadmill_walk / shoulder_press / lateral_raise（male）+ crunch（female）
  - 所有 sample 文件已上传 `/opt/fitai/media/exercises/vital/`，生产 `exercise_media_assets` 已写入 11 条 `published`
  - 生产 API 已重建并部署 `/exercise-media`
- 验证：
  - 本地后端 **211 passed**，Ruff app/tests 通过
  - GitHub Actions：`Backend Tests` **success** @ `341981f`；`iOS Build` **success** @ `341981f`
  - 生产未登录 `/exercise-media` → **401**；21 个 slug → **400**
  - `test_reviewer` `/exercise-media?slugs=squat,hip_thrust,leg_press,crunch,missing` → **200**，返回 4 条，缺省项被忽略
  - 生产媒体 URL → **200**，Range 请求 → **206**，`video/mp4` / `image/jpeg` 正确
  - `test_reviewer` `/watch/bootstrap` → **200**，`media` 包含 `crunch`
  - 素材首帧/末帧比对：squat、leg_press、crunch 循环无明显跳帧
- 未验证：
  - 真机 iPhone 内嵌循环/全屏/Reduce Motion/音乐不中断/切后台暂停
  - 真机 Watch 下载、播放、离线缓存
  - 弱网和离线回退
  - `test_reviewer` 当前计划只有 `crunch` 命中；squat/leg_press 等需要含器械动作的计划或另一个测试账号
- Mac 下一步：
  - `git pull` → `xcodegen generate` → 构建/测试
  - 用 `test_reviewer` 或新账号生成含 squat / leg_press / hip_thrust 的计划，真机看内嵌动画和全屏
  - 验证 Watch 动作页播放 `watch_url`，确认和 iPhone 同一素材
  - 检查白底素材在深色模式下的观感（当前媒体面板固定白底）
- 不要恢复/不要做：
  - 不要在素材缺失时显示假动画；没有媒体就不出动画卡
  - 不要把循环视频换成带系统控件的 `VideoPlayer`
  - 不要把 `advance`/播放器改成自动全屏
  - 不要提交原始 MP4/转码文件到 git
  - 不要破坏 `/watch/bootstrap` 的媒体字段
- 仍 BLOCKED：
  - 正式 1,500 动作 × 男女两套素材采购、授权确认、映射与转码
  - 生产 `exercises` 只有 27 个旧 seed 动作，iOS 训记 57 条未导入；铺全量媒体前要先定动作库同步方案

### 2026-11-07 · Windows / OpenCode（Watch 生产链路复核）

- 分支：`feature/watch-standalone-workout`
- 代码 HEAD：`9a833b1`；文档 HEAD 见 `git log -1`
- CI：`iOS Build` **success** @ `0aaf2ce`；`Backend Tests` **success** @ `ca7f24d`
- 已拉取并保留：
  - macOS 40/42/49mm 响应式训练控件（`1eb3fdd`）
  - 语音输入与发送同一行（`9a833b1`）
  - 不恢复自动发送、不拆成上下两行
- 生产环境状态：
  - `https://hk-api.jiaolianfit.cn/health` → ok
  - `/health/ready` → ready
  - Flyway schema version **23**
  - API/Caddy/MySQL 容器 healthy
- `test_reviewer` 生产状态：
  - Pro 有效到 `2027-02-05 12:51:59 UTC`
  - 已补齐档案：男、178cm、75kg、体脂 18%、每周 3 练、45 分钟
  - 已生成 4 周 3 分化计划，12 个训练日，首日 4 个动作
- 生产 Watch E2E 烟测（真实 HTTP，不使用模拟器）：
  - `/watch/bootstrap?day_id=...` → 200，day title 正常，4 个动作，`media=0`
  - `/watch/session` → 200，30 分钟 access token + refresh token
  - Watch access token `/me/access` → 200，`is_pro=true`，`watch_can_train=true`
  - Watch access token `/coach/voice`（改计划）→ 200，`requires_phone_confirmation=true`
  - Watch refresh token `/auth/refresh` → 200，token 已轮换
  - 刷新后的 access token `/me/access` → 200
  - `DELETE /watch/session` → 200，撤销 1 个会话
  - Watch voice 前后 `chat_sessions/chat_messages/agent_runs/ai_memories` 均为 0
  - iPhone `/agent/chat` 烟测仍为 `completed`
- 未跑通 / 未验证：
  - 真实 iPhone ↔ Apple Watch 的 WatchConnectivity 预载、快照回传、文件传输
  - 真机听写/手写、TTS、耳机自动朗读、Watch 直连网络
  - HealthKit 保活、单写者、手表锁屏/后台
  - 真实媒体（生产 `exercise_media_assets=0`）
  - 41/45mm 休息态/锁定页/语音页视觉
  - 真机签名、Watch App ID/HealthKit capability、TestFlight 安装
- Mac 下一步：
  - `git pull` → `xcodegen generate`
  - 用 `test_reviewer` 真机/TestFlight 走完 Watch 安装和训练
  - 验证 Watch voice 听写/发送/TTS/耳机
  - 验证 HealthKit 与离线 outbox
  - 上传 TestFlight，确认 Watch 安装入口
- 不要恢复：
  - 不要拆分语音输入/发送行
  - 不要恢复提交即自动发送
  - 不要拆回两套教练 prompt
  - 不要让 Watch voice 写聊天/记忆
  - 不要删除生产 V23 schema

### 2026-11-07 · macOS（语音教练输入行并排）

- 分支：`feature/watch-standalone-workout`
- 代码提交：`9a833b1`（本条目为后续 docs 提交）
- 做了什么：
  - 语音页原来是 `TextFieldLink` 整行 + 发送按钮整行，改成同一行：左侧「问教练…」输入，右侧 44pt 荧光绿「发送」胶囊
  - 取消 `TextFieldLink` 提交后自动发送：提交后先显示「你问」卡片，点发送才真正发给教练
  - 发送按钮在问题为空或加载中禁用；有内容后变荧光绿
  - `WatchCompactPrimaryButtonStyle` 增加 `height` 参数，发送按钮 44pt 与输入框对齐
- 验证：
  - Xcode 27.2 构建 **BUILD SUCCEEDED**
  - 40mm / 49mm 截图：输入与发送并排；40mm 底部说明换行但控件完整
  - 未验证：真实听写/手写、TTS、耳机、网络发送；40mm 提交后「你问」卡片和回答卡布局
- Windows 需要做：
  - 保留单行输入 + 发送；不要恢复自动发送和整行发送按钮
  - 真机验证听写/手写提交后「你问」卡片、发送按钮启用态
  - 检查 41/45mm 下输入行和底部说明
- 不要恢复：
  - 不要把 `TextFieldLink` 和发送按钮拆成上下两行
  - 不要恢复提交即发送

### 2026-11-07 · Windows / OpenCode（教练同源只读 + 生产部署）

- 分支：`feature/watch-standalone-workout`
- 代码提交：`ca7f24d`（本条文档提交见 `git log -1`）
- CI：`Backend Tests` **success** @ `ca7f24d`；`iOS Build` **success** @ `8d560e7`
- 本地验证：后端 **210 passed**，Ruff 通过
- 教练统一：
  - 新增 `backend/app/services/coach_core.py`：共享教练人格、语气、安全红线、手机确认标记、Watch 只读指令
  - iPhone Agent 的 `SYSTEM_PROMPT` 改为「共享 core + Agent 工具指令」；Watch voice 使用「共享 core + Watch 只读指令」
  - `/coach/voice` 内部改走 `watch_voice_reply`，复用同一份 `build_coach_context`，但无工具、无历史、无 ChatMessage/长期记忆/AgentRun
  - Watch voice 使用低 reasoning、`max_tokens=600`、1–3 句短答；计划类问题仍回 iPhone
- 生产部署（2026-11-07 20:50 UTC+8）：
  - 数据库备份：`/opt/fitai/backups/fitai-pre-v23-20261107-205027.sql.gz`（23K，gzip 校验通过）
  - 后端备份：`/opt/fitai/backups/backend-pre-v23-20261107-205027.tar.gz`（553K）
  - Flyway：V23 `watch training` 成功，schema version **23**
  - 后端包：`backend-20261107-205027.tar.gz`，`docker compose build api && up -d api`，健康检查 ready
  - 管理 jar 已替换为含 V23 的版本，旧包保留为 `admin/fitai-admin-server-pre-v23.jar`
  - `test_reviewer` 已授 Pro 90 天：`2026-11-07 12:51:59` → `2027-02-05 12:51:59`，source `admin`
- 生产烟测：
  - 未登录 `/coach/voice`、`/watch/bootstrap`、`/watch/session` 均返回 **401**
  - `test_reviewer` `/me/access`：`is_pro=true`、`watch_training.can_train=true`
  - 改计划语音：200，`requires_phone_confirmation=true`
  - 正常语音：200，87 字，DeepSeek `deepseek-flash`，AIJob `coach_watch_voice` **ok**，延迟 1770ms
  - Watch voice 前后：`chat_sessions=0`、`chat_messages=0`、`agent_runs=0`、`ai_memories=0`
  - `/watch/session` 签发/撤销均 200
  - iPhone `/agent/chat` 烟测：200、`completed`、回答 78 字、无意外 action
- Mac 需要做：
  - 继续保留 40/42/49mm 响应式阈值和单主按钮流程
  - 真机装 iPhone + Watch，验证系统听写/TTS/耳机、WatchConnectivity 预载、HealthKit、logout/login、视频回退
  - Release Archive + Watch App ID/HealthKit capability + TestFlight 上传
  - 3D 素材到位后验证 loop/poster/流量电量
- 回滚：
  - DB：用上述 `.sql.gz` 恢复
  - 后端：解压 `backend-pre-v23-...tar.gz` 回 `/opt/fitai`，重新 build/up api
  - 注意：回滚 API 代码不要回滚 V23 schema（列/表保留是安全的）
- 不要恢复：
  - 不要拆回 iPhone Agent 和 Watch 两套独立教练 prompt
  - 不要让 Watch voice 调工具、写聊天记录或长期记忆
  - 不要删除 `coach_core.py` 或响应式布局

### 2026-11-07 · macOS（40/42/49mm 小表盘适配）

- 分支：`feature/watch-standalone-workout`
- 代码提交：`1eb3fdd`（本条目为后续 docs 提交）
- 做了什么：
  - 拉取 Windows `588af76` / `6373a9e`，保留其页码点、休息期暂停/撤销、暂停隐藏主操作、最后一组「查看总结」等改动
  - 在 40mm（SE 3）、42mm（Series 12）、49mm（Ultra 4）模拟器实测训练页
  - 发现 42mm 主按钮横向被挤出屏幕、40mm 三个操作底部被截断
  - 训练页控制区改为响应式：
    - 宽度 ≥ 195：完整文字（完成一组 / 下一个动作）+ 40pt 图标
    - 宽度 168–195：短文案（完成 / 下一个 / 总结）+ 34pt 图标
    - 宽度 < 168：图标按钮（荧光绿圆形主按钮 + 暂停 + 撤销）
    - 高度 < 210：隐藏进度条、缩小卡片内边距、按钮高度 42→38、底部留白收紧
  - `WatchPrimaryButtonStyle` / `WatchRoundPrimaryButtonStyle` 增加 `height` 参数；`WatchIconButtonStyle` 增加 `size` 参数
- 验证：
  - `xcodegen generate`；`FitAIWorkoutCore` **13/13**；Xcode 27.2 构建 **BUILD SUCCEEDED**
  - 40/42/49 训练页截图：三个操作都在首屏；40mm 使用图标按钮，42mm 使用「完成」短文案，49mm 保持「完成一组」
  - 未验证：40/42 休息态的暂停/继续/撤销 +「查看总结」、锁定页 CTA、语音页底部说明、动作页页码点、真机
- Windows 需要做：
  - 保留响应式阈值，不要按 49mm 写死尺寸
  - 继续检查 41/45 的休息态、锁定页、语音页；40mm 图标按钮是有意降级
  - 如果产品要求 40mm 也显示文字，需要单独的 40mm 布局，不要直接拉大按钮
- 不要恢复：
  - 不要删除响应式分支和按钮尺寸参数
  - 不要恢复 Root 全局页码点或「完成一组 + 下一个动作」双按钮
  - 不要把休息期暂停/撤销移除

### 2026-11-07 · Windows / OpenCode（Watch 全链路自检 + 并发/账号/媒体加固）

- 分支：`feature/watch-standalone-workout`
- 代码提交：`588af76`（本条文档提交见 `git log -1`）
- CI：`iOS Build` **success** @ `588af76`；`Backend Tests` **success** @ `a79f3db`（后端未再改）
- 本地验证：后端 **209 passed**，Ruff 通过；Swift 语法树 96 文件 0 error
- 做了什么（保留 macOS UI 重设计）：
  - 账号切换：同一天换账号会强制重建 Watch 引擎，不再把旧账号动作/组数带到新账号；媒体按新计划清理
  - Bootstrap 防乱序：任何比当前更旧的 bootstrap 都忽略；跨天旧 payload 不再覆盖新计划
  - 预载 ≠ 已开始：手机不再把「手表只预载未开始」误判为 Watch 主导；只有用户第一次动作后才进入 watch-led
  - 进行中训练保护：手机改计划/换日时，Watch 保留已开始会话的旧动作与媒体，结束后再加载新计划；重启 App 也不删当前训练媒体
  - 恢复与对账：手机启动/重连会请求 Watch 当前状态；手机持久化 watch-led 暂停状态；空状态不会污染 outbox
  - 退出登录竞态：logout 带时间戳；早于 logout 的延迟 bootstrap 不能重新解锁；晚到的旧 logout 不能覆盖新登录
  - 媒体：视频解码失败/损坏回退海报；媒体/训练文件标记不备份；替换版本时删除旧文件
  - 服务端：watch session 每账号最多 3 个活跃会话、12 次/分钟限流；voice 空消息校验；`_speech_text` 空文本兜底
  - 其他：Paywall 增加 Apple Watch 权益；Watch voice 回答自动滚到结果；`canTrainNow` 允许 Pro 过期后查看已完成总结
- 未验证 / 仍需真机：
  - Mac 侧 41mm/45mm 布局、动作页页码点、休息中暂停/撤销、视频失败海报回退
  - 真实 WatchConnectivity 状态对账、logout/login 快速切换
  - 真实媒体循环/TTS/耳机路由、HealthKit 授权与单写者、真机签名
- 仍 BLOCKED：3D 素材、V23 生产迁移与 `/watch/*` 部署、App Store 协议/IAP/API Key、TestFlight 外部审核、`test_reviewer` Pro 授权、真实 Watch 签名/HealthKit capability

### 2026-11-07 · Windows / OpenCode（Review macOS Watch UI + 交互回归修复）

- 分支：`feature/watch-standalone-workout`
- 代码提交：`a073ce6`（本条文档提交见 `git log -1`）
- CI：GitHub Actions `iOS Build` **success** @ `a073ce6`（含 iOS、Watch、共享 framework）
- 做了什么：
  - 完整 review 并保留 macOS `2d5dea0` 的 `WatchTheme`、暗色品牌配色、单主按钮流程、语音页/锁定页重设计
  - 页码点从 Root 全局 overlay 移入各页：训练页 header + 动作页顶部；修复动作页看不到页码点
  - 训练页 rest 期间仍保留暂停/撤销；暂停时隐藏主操作，避免仅剩“下一个动作”而没有“继续”
  - 休息卡按钮在暂停时禁用，避免绕过暂停；最后一组休息卡文案改为“查看总结”
  - 动作页动作名下移，避免 41mm 长动作名与页码点相撞
- 已验证：
  - iOS CI 编译通过；Swift 语法检查 96 文件 0 error
  - 未做模拟器截图（Windows 无 Xcode）；41mm/45mm 实际布局仍要 Mac 看
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate`
  - 复核 41mm/45mm：训练页三按钮、页码点、锁定页底部 CTA、语音页底部说明
  - 复核休息中暂停/继续/撤销；最后休息卡“查看总结”
  - 继续保持单主按钮流程，不要恢复“完成一组 + 下一个动作”双按钮
- 不要恢复：
  - 不要删除 `WatchTheme.swift` 或 Watch AccentColor 品牌色
  - 不要把页码点改回 Root 全局 overlay
  - 不要把暂停/撤销从休息状态移除
  - 不要把语音页重复关闭按钮/半透明背景加回
  - 不要把锁定页 CTA 放回滚动区域

### 2026-11-07 · macOS（Watch UI 重设计 + 动作完成流程）

- 分支：`feature/watch-standalone-workout`
- 代码提交：`2d5dea0`（本条目为后续 docs 提交）
- 做了什么：
  - 新增 `WatchTheme`：沿用 iPhone 四色体系的暗色版（近黑画布、荧光绿主色、暖白文字、石墨卡片）；Watch `AccentColor` 从原来的橙棕改为品牌荧光绿
  - 训练页重排：紧凑动作卡 + 左侧荧光绿竖条 + 3pt 进度条 + 页码点 + 荧光绿语音按钮；完成一组、暂停、撤销全部进入首屏
  - 动作完成流程：主按钮从「完成一组」切换为「下一个动作」/「查看总结」，与 iPhone `WorkoutSessionActionBar` 一致；最后一组休息期间休息卡只保留一个「下一个动作」，点击 = 跳过休息 + 进入下一动作；正常组间休息仍是「跳过」
  - 动作页：去掉重复动作名，荧光绿动作图标占位，增加「等待 iPhone 预载」，右滑提示改为胶囊
  - 语音页：去掉重复关闭/标题，只保留系统 X + 荧光绿导航标题；不透明黑背景，不再透出训练页绿色按钮；显示当前训练上下文；发送按钮品牌化且禁用态清晰；底部说明改一行
  - Pro 锁定页：品牌行 + PRO 胶囊，按 `signedOut` / `proRequired` 区分文案；刷新按钮固定底部；移除未上线的「3D 动作动画」宣传
- 验证：
  - Xcode 27.2 + iPhone 17 模拟器构建：**BUILD SUCCEEDED**
  - Watch App 在 Apple Watch Ultra 4 模拟器安装并运行
  - `FitAIWorkoutCore`：**13/13** 通过（UI 改动前）
  - 截图确认：训练页、完成 3/3 组后的休息页、动作占位页、语音页、Pro 锁定页
  - 未验证：真实视频/媒体、真实 Pro/登录、真实左右滑手势注入、41mm/45mm 小表盘、语音网络/TTS、真机签名
- Windows 需要做：
  - Review 并保留 `WatchTheme` 和单主按钮流程；不要恢复「完成一组 + 下一个动作」两个同时出现的按钮
  - 如果产品希望休息倒计时结束自动进入下一动作，可在 `WatchTrainingView` 增加 rest 结束自动 `advanceExercise`；当前为与 iPhone 一致，需要用户点一下
  - 检查 41mm/45mm：训练页首屏三按钮、锁定页 CTA、语音页底部说明是否仍完整
  - 动作页顶部页码点在当前实现里没有显示（训练页正常）；可把页码点移到各页内部或统一放到安全区
  - 真实素材到位后验证 AVKit loop、占位回退、语音 TTS
- 不要恢复：
  - 不要删除 `WatchTheme.swift` / Watch AccentColor 品牌绿
  - 不要把训练页主按钮拆回两个
  - 不要把语音页重复关闭按钮/半透明背景加回来
  - 不要把锁定页 CTA 放回可滚动区域导致截断

### 2026-11-07 · Windows / OpenCode（手表独立语音、媒体、离线同步、手机指令、HealthKit）

- 分支：`feature/watch-standalone-workout`
- 代码提交：`919288b`（本条文档提交见 `git log -1`）
- CI：GitHub Actions `iOS Build` **success** @ `919288b`；`Backend Tests` **success** @ `919288b`
- 本地验证：后端 `pytest` **208 passed**，Ruff app/tests 通过；`FitAIWorkoutCore` **13/13** 通过；Swift 语法树检查 95 个文件 0 error
- 做了什么：
  - 后端新增 `POST /watch/session`（手表独立 refresh token，避免轮换顶掉手机）、`DELETE /watch/session`（手机退出时撤销全部手表会话）、`POST /coach/voice`（Pro 只读语音回答，不写 ChatMessage、不触发长期记忆，改计划类问题要求回 iPhone 确认）
  - Watch 新增 Keychain 凭据、`WatchAPIClient`（直连 `/coach/voice`、`/me/access`、`/auth/refresh`）、`WatchVoiceView`（`TextFieldLink` 系统听写/手写、文字必显、静音默认、点按朗读、耳机自动朗读、安全提示、iPhone 确认提示）
  - Watch 媒体：手机从 `/watch/bootstrap` 拉当天动作和媒体清单，下载 watch 视频/海报后通过 `WCSession.transferFile` 预载；手表 `WatchMediaStore` 落 Application Support，动作页本地播放、按 loop_start/end 循环、无暂停控件；缺视频显示海报/文字
  - 离线：watch 持久化 outbox（每会话只保留最新快照，最多 20 条），手机按 revision 去重并持久化 inbox，收取后 ack；手机 App 启动/回前台/后台唤醒时回灌为本地训练记录，复用现有 `syncPendingWorkouts` 补传服务端
  - 手机→手表：watch 主导时手机完成组/撤销/跳动作/跳过休息/暂停/结束都发 `WorkoutCommand`；手表不可达时手机只读并在训练页内提示，不制造第二份训练
  - 开始时机：预载不再开始计时/HealthKit，第一次用户动作才写 `startedAt` 并启动 `HKWorkoutSession`；Watch 只保活，iPhone 仍是 HealthKit 唯一写入方
  - 训练来源：`WorkoutSession.source` 写入 `watch`/`phone` 并随 `/workouts` 上传，数据库 V23 `source` 列可追溯；Watch voice 先过安全护栏再做只读/改计划分流
  - Pro：3 天宽限用服务端验证时间；手机离线且无已验证券时不再用“免费”覆盖手表缓存；Pro 中途到期/退款但有已开始会话仍可练完；手机退出后手表强制锁定
  - 恢复 Watch `AppIcon`；增加 Watch `PrivacyInfo.xcprivacy`（UserDefaults required-reason + Health/Fitness/UserID/DeviceID/OtherUserContent）；只有已配对且已安装 Watch App 才自动预载，Watch App 安装/变为可用时重新预载；手表日 ID 统一小写，后端也做兼容
- 已验证：
  - iOS CI 编译通过（含 FitAIWatch、FitAIWorkoutCore、iOS App）
  - 后端单测、Ruff、共享核心单测通过
  - Swift 语法检查通过
- 未验证（必须 Mac/真机）：
  - 真实 WatchConnectivity 预载/文件传输/ack/手机指令
  - 真实 Apple Watch 上 `TextFieldLink` 听写/手写、TTS、耳机路由、手表直连网络
  - HealthKit 授权、`HKWorkoutSession` 保活、手表锁屏/后台、iPhone 单写者是否产生重复训练
  - 真实视频循环（目前无 `sample_loop.mp4`/3D 素材）、海报回退、流量/电量
  - Watch AppIcon 在真机/TestFlight 显示
  - 真机签名、Watch App ID、HealthKit capability
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate`
  - Release/Debug 真机安装 iPhone + Watch App；确认 iPhone 训练页打开后 Watch 收到真实动作和媒体
  - 免费账号：Watch 锁定；Pro 账号：解锁。退出登录后 Watch 强制锁定
  - 手表断网/离开手机：完成组、休息、暂停、结束，再连回手机，确认手机生成同一 `sessionID` 的训练记录，重启手机 App 不重复
  - 手机与手表同时在线：手机完成组/撤销/跳动作/结束，确认由手表执行并回传；手机断连时显示只读提示
  - 手表语音：听写/手写各问一次；默认不自动朗读；点“朗读”出声；连耳机后“耳机自动”模式自动读；说“帮我把下周改成四练”应返回“需要 iPhone 确认”；确认 iPhone 聊天记录和长期记忆没有新增
  - 修改设备时间/服务端验证时间验证 3 天宽限；Pro 中途到期仍能结束当前会话
  - HealthKit：首次动作才出现授权/训练会话；结束只在 iPhone 健康里出现一条训练，Watch 不单独保存
  - 有素材后验证 loop_start/loop_end、左右滑、动作页无暂停控件、训练页暂停
  - 检查 Watch AppIcon、Watch App ID、HealthKit capability 与 TestFlight 签名
- 上线前外部阻塞：
  - 3D 动作素材/VitalAnimations 采购与转码（`watch_url`/`poster_url`/loop 元数据）仍未提供
  - V23 迁移与 `/watch/*`、`/coach/voice` 尚未部署生产
  - App Store Connect 协议/IAP、Server API Key、外部 Beta 审核
  - `test_reviewer` 仍需生产 Pro 授权
- 不要恢复：
  - 不要 `import WatchKit`；watchOS 视频用 AVKit `VideoPlayer`
  - 不要回退 `SDKROOT`/`SUPPORTED_PLATFORMS`/`@rpath`/rpath/Watch DEBUG 条件
  - 不要把共享 framework 换成本地 package 链接
  - 不要让 watch 本地解锁 Pro，不要让 watch voice 写聊天/长期记忆
  - 不要在 watch 主导时让手机本地追加组数；手机离线必须只读
  - 不要把 auth token 写进 `watch-workout.json`（只放 Keychain）
  - 不要用手机本地未验证的自由权益覆盖手表缓存

### 2026-11-07 · Windows / OpenCode（手表真实计划预载 + snapshot 回传）

- 分支：`feature/watch-standalone-workout`
- 提交：`db8e09e`
- CI：GitHub Actions `iOS Build` **success**（含 framework/watch/app）
- 做了什么：
  - `FitAIWorkoutCore` 增加 `WatchBootstrap` / `WatchAccess` / `WatchMediaAsset` / `WatchSessionEnvelope`
  - iOS 新增 `WatchSyncManager`，在训练开始页把当天计划、Pro 权益、媒体清单发到手表
  - watch 新增 `WatchWorkoutStore`，本地持久化 bootstrap 和 snapshot，所有操作走共享引擎
  - watch 新增 `WatchSyncManager`，接收 bootstrap、回传 `WatchSessionEnvelope`
  - 训练页/动作页改为读取 `WatchWorkoutStore`，不再直接读 mock engine
  - 3 天离线宽限逻辑进入 `WatchAccess.canTrain`
- 验证：
  - iOS CI 构建通过
  - 未真机验证 WatchConnectivity、真实计划发送、snapshot 回传
  - iPhone 收到 snapshot 后还未合并到当前训练 UI/服务端
- Mac 需要做：
  - 真机或 Simulator 验证 iPhone 打开训练页后手表收到真实动作
  - 手表完成一组后检查 iPhone 是否收到 `WatchSessionEnvelope`（目前只存内存）
  - 继续验证左右滑、AVKit 占位、Pro 锁定
- 不要恢复：
  - 不要让 watch 直接读 iPhone 的 SwiftUI 状态
  - 不要绕过 `WorkoutSessionEngine`
  - 不要把 bootstrap 当成永久授权；手表必须检查 `pro_expires_at` 和 3 天宽限

### 2026-11-07 · macOS（watch 独立分支构建与模拟器验证）

- 分支：`feature/watch-standalone-workout`
- 提交：`94f8afa`（本条目为后续 docs 提交）
- 工作区：独立 worktree `/Users/jacobwu/Documents/gym-app-watch`；未切换、未合并 `develop`，主 `develop` 工作区保持原样
- 做了什么：
  - 拉取 `4508de2`，`cd ios && xcodegen generate`
  - `swift test --package-path FitAIWorkoutCore`：**10/10 通过**
  - Xcode 27.2 构建 FitAI scheme（iPhone 17 模拟器，Debug），watch target 作为依赖一起构建
  - 在 Apple Watch Ultra 4 模拟器安装并运行 watch App
  - 截图确认：训练页（哑铃卧推、1/3 组、8–10 次、60kg、下一个平板支撑、完成一组）、Pro 锁定页、动作占位页（动作演示 / 等待动作素材 / 右滑回到训练）
- 发现并修复：
  - **Watch Debug 缺少 `SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG`**：`#if DEBUG` 不成立，`isPro` 走 `false`，所以 Debug 一打开就是 Pro 锁定页。已在 `project.yml` 的 Watch Debug 配置补上；临时把 `isPro` 改 `false` 看锁定页、把默认页改 `.action` 看占位页，截图后均已还原。
  - **Xcode 27.2 + XcodeGen 2.46 下多平台 framework 生成异常**：
    - `FitAIWorkoutCore` 生成后 `SDKROOT=auto`、`SUPPORTED_PLATFORMS=""`、没有 Info.plist
    - App 生成后没有 `SDKROOT`，Xcode 只把 FitAI 识别成 macOS 目标，报 “no destination matching”
    - framework 安装名是 `/Library/Frameworks/...`，App 也没有 `@executable_path/Frameworks` rpath，运行时 `dyld: Library not loaded`
  - 已在 `project.yml` 修复（提交 `94f8afa`）：
    - 项目级 `SDKROOT: iphoneos`
    - FitAI：`SUPPORTED_PLATFORMS: "iphoneos iphonesimulator"` + `LD_RUNPATH_SEARCH_PATHS: "$(inherited) @executable_path/Frameworks"`
    - FitAIWatch：`LD_RUNPATH_SEARCH_PATHS: "$(inherited) @executable_path/Frameworks"`
    - FitAIWorkoutCore：`SUPPORTED_PLATFORMS: "iphoneos iphonesimulator watchos watchsimulator"`、`GENERATE_INFOPLIST_FILE: YES`、`DYLIB_INSTALL_NAME_BASE: "@rpath"`
    - FitAIWatch Debug：`SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG`
- 验证结果：
  - FitAI scheme build：**BUILD SUCCEEDED**
  - watch App 已嵌入：`FitAI.app/Watch/FitAIWatch.app`
  - Debug watch bundle：`com.wjk.fitai.dev.watchkitapp`，companion `com.wjk.fitai.dev`
  - `FitAIWorkoutCore` 测试覆盖完成组、暂停/恢复、撤销、跳过休息、幂等命令
  - 没有启动本地后端，watch 壳不依赖登录/Pro
- 没验证 / 不要用这个壳判断：
  - 左右滑的真实手势：没有触摸注入，代码和页面已确认，需人工在 Device Hub 拖动验证
  - AVKit 真实播放：`ios/FitAIWatch/sample_loop.mp4` 不存在，当前只显示占位；素材到位后再验
  - 真实计划同步、真实 Pro 权益、离线队列、HealthKit、语音教练、3D 动画
  - 真机签名、Watch App ID、HealthKit capability、配对设备
- Windows 需要做：
  - 确认 `94f8afa` 的 Xcode 27 兼容配置是否保留/上游；Xcode 16 CI 可能不需要，但不要回退
  - 保留 Watch Debug 的 DEBUG 编译条件，否则所有 Debug 构建都会落到 Pro 锁定页
  - 补 `sample_loop.mp4` 或 3D 素材后，重新 `xcodegen generate` 再验 AVKit
  - 不要把这个分支合并到 `develop`，也不要让 watch 壳依赖后端登录/Pro
- 不要恢复：
  - 不要删除 `SDKROOT` / `SUPPORTED_PLATFORMS` / `DYLIB_INSTALL_NAME_BASE` / `LD_RUNPATH_SEARCH_PATHS` / `GENERATE_INFOPLIST_FILE` 这组 Xcode 27 修复
  - 不要删除 Watch Debug 的 `SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG`
  - 不要改 Debug/Release watch bundle ID
  - 不要把 `FitAIWorkoutCore` 改回本地 package 依赖

### 2026-11-07 · Windows / OpenCode（Watch 壳 + 后端契约 + CI 绿）

- 分支：`feature/watch-standalone-workout`
- 提交：`082ced8`（上一核心提交 `ca5095e`）
- 已推送并 CI 通过：
  - GitHub Actions `iOS Build` **success**：shared framework、watchOS target、App target、package tests 全部构建通过
  - `swift test --package-path FitAIWorkoutCore` 通过
  - 后端 `200 passed`（Watch bootstrap/media/Pro gate/每日额度）
  - admin-server Maven verify 通过；admin-web typecheck 通过
- 做了什么：
  - 新增 watchOS target，嵌入 iOS App；Pro 锁定页、训练页、动作页、左右滑分页
  - 训练页使用 `WorkoutSessionEngine`：完成组、暂停/恢复、撤销、跳过休息、下一个动作
  - 动作页使用 AVKit `VideoPlayer` + 循环通知；watchOS 不支持 `WatchKit` 模块，已改 AVKit
  - 新增 `WatchMovieView`，静音、关闭 hit testing
  - 后端新增 `/watch/bootstrap`（Pro only），返回当天计划、access、media 和 server_time
  - 新增 `exercise_media_assets` 模型和 `V23__watch_training.sql`（auth/workout 字段 + 媒体表）
  - 媒体选择：按用户性别优先，unisex 次之，其他性别兜底；未发布媒体忽略
  - 新增 `watch_training` 权益 key；iOS `ProFeature.watchTraining`、`canTrain` 解码
  - 修复 `LoadProgression.estimateWeight` 缺参数标签的编译错误
  - admin server 教练用量从周改为日，admin-web 显示“今日 AI 教练”
- 验证：
  - Windows 未真机；未在 Apple Watch 上验证
  - 未验证：视频循环、左右滑、Pro 锁定、真实手表电量、HealthKit、语音
  - watch AppIcon 暂未完成，当前关闭 `ASSETCATALOG_COMPILER_APPICON_NAME`；TestFlight 前必须补
- Mac 需要做：
  - `git pull` → `git switch feature/watch-standalone-workout` → `cd ios && xcodegen generate`
  - 真机跑 watch target，确认嵌入、签名、info.plist、HealthKit entitlement
  - 验证训练页按钮、左右滑、暂停、完成组
  - 补 watch AppIcon（Icon Composer/Asset Catalog）
  - 检查 `FitAIWorkoutCore` framework 的 watchOS deployment target 和嵌入
- 不要恢复：
  - 不要 `import WatchKit`（watchOS SDK 当前没有该模块）
  - 不要把 `FitAIWorkoutCore` 改回本地 package 依赖；Xcode 构建使用 framework target
  - 不要删除 `V23` 或 `exercise_media_assets`
  - 不要关闭 `/watch/bootstrap` 的 Pro gate

### 2026-11-07 · Windows / OpenCode（Watch 共享训练核心）

- 分支：`feature/watch-standalone-workout`
- 提交：`ca5095e`
- 做了什么：
  - 新增 `ios/FitAIWorkoutCore` Swift Package，iOS 17 / watchOS 10 共用
  - 新增确定性 `WorkoutSessionEngine`：完成组、撤销、暂停/恢复、跳过休息、切换动作、结束
  - 所有命令带 `operationID`；`(exerciseID, setIndex)` 幂等；不读系统时钟，时间由命令携带
  - Codable/Hashable/Sendable snapshot，支持崩溃恢复和 WatchConnectivity 传输
  - 新增 `WorkoutCoreAdapter`，把现有 `PlanDay` / `PlanExercise` / `SetLog` 映射到共享模型
  - `AppConfig.watchWorkoutEnabled = false` 作为后续功能开关
  - iOS CI 增加 `swift test --package-path FitAIWorkoutCore`
- 验证：
  - tree-sitter 语法检查 0 error
  - 未在 Windows 编译 Swift；未跑 package 单测
  - GitHub Actions `iOS Build` 会在推送分支时执行 package 单测和 simulator build
- Mac 需要做：
  - `git pull` → `git switch feature/watch-standalone-workout`
  - `cd ios && xcodegen generate`
  - `swift test --package-path FitAIWorkoutCore`
  - `xcodebuild ... build`（已有 CI 也会跑）
  - 确认 XcodeGen 本地 package 依赖正常、FitAITests 能 import `FitAIWorkoutCore`
- 不要恢复：
  - 不要把训练状态直接写回 View 的 `@State`
  - 不要让命令依赖系统时间
  - 不要用 `(slug, setIndex)` 替代 `(exerciseID, setIndex)` 做去重（自定义动作可能同 slug）

### 2026-11-06 · Windows / OpenCode（免费教练改为每天 3 条 + 提前订阅弹窗修复）

- 提交：`ebf5752`；额度文案 `5855d90`
- 做了什么：
  - 免费教练额度从 10 条/周改为 3 条/天，不累计；按北京时间 00:00 在服务端刷新
  - `/me/access` 新增 `daily_limit=3`，保留 `weekly_limit=3` 兼容旧客户端
  - `FeatureUsage` 周期改为自然日；`reserve_coach_message` 支持传入 period，避免跨午夜判断不一致
  - 教练文案改为「今日免费 AI 教练剩余 X/Y 条」「北京时间每天 00:00 恢复 3 条」
  - 删除教练欢迎页「升级 Pro · AI 教练不限条数」大卡；0 条时才显示额度用完卡
  - 免费用户文字消息一律先走 Agent，不再因计划类关键词或计划调整阶段提前弹订阅
  - `sendAgentChat` 的 `PRO_REQUIRED` 增加防御：Pro 或额度 > 0 时不弹教练订阅页
  - 新增 `ProFeature.coachVision`（拍照问教练）；拍照/相册/动作点评改用它
  - 拍照/相册/视频/器械/动作点评对免费用户显示「Pro」标识；文案明确文字教练仍有每天免费额度
  - 免费用户欢迎文案不再邀请「发照片」
  - 更新 `FeaturePolicyTests`，新增 daily_limit 优先、旧 weekly_limit 兼容测试
- 验证：
  - 后端 **197 passed**，Ruff app/tests 通过
  - 生产已部署；`/health`、`/health/ready` 200
  - 生产 `/me/access`（test_reviewer）：`daily_limit=3`、`weekly_limit=3`、`remaining=3`、`reset_at=2026-11-06T16:00:00+00:00`（北京时间次日 00:00）
  - Windows 未编译 iOS；未真机验证每日刷新和订阅弹窗路径
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate` → build/test
  - 运行 `FeaturePolicyTests`（daily_limit 优先、weekly_limit 兼容）
  - 免费账号验证：每天 3 条；第 4 条显示「今天的免费 AI 教练额度已用完」；次日北京时间 00:00 后恢复 3 条
  - 改手机时间/时区后仍不能刷新余额（服务端时间）
  - 免费账号发文字：额度 >0 时不弹订阅；问计划问题也不提前弹
  - 确认欢迎页大升级卡已消失；0 条时额度用完卡正常
  - 免费账号点「拍照 · Pro / 相册 · Pro / 动作点评 · Pro」：弹「拍照问教练」订阅页，文案应说明文字教练仍有每天免费额度
  - 视频点评/器械识别显示「Pro」标识
  - 旧客户端兼容：旧包仍会读 `weekly_limit=3`，但文案可能显示「本周」，服务端实际按天
- 不要恢复：
  - 不要把免费教练额度改回 10 条/周
  - 不要删除 `daily_limit` 或把 `weekly_limit` 设回 10
  - 不要恢复欢迎页「升级 Pro · AI 教练不限条数」大卡
  - 不要用 `.coachAI` 作为拍照/相册/动作点评的 Paywall（会再次让人误以为额度用完）
  - 不要在免费用户文字发送前用 `isPlanScheduleRequest` / `planAdjustmentStage` 拦订阅
  - 不要用手机本地时间计算额度或重置

### 2026-11-06 · Windows / OpenCode（重复点 Tab 回根 + 顶部留白统一）

- 提交：`40f3027`
- 做了什么：
  - 新增 `TabBarReselectObserver`：在今日 Tab 的宿主层给底层 `UITabBar` 加非阻塞 tap 识别，重复点当前 Tab 时调用 `resetTabPaths()`
  - `cancelsTouchesInView = false` + 允许同时识别，普通切 Tab、Tab 栏点击和滑动不受影响
  - 切换 Tab 与重复点 Tab 共用同一套 path 重置逻辑
  - 新增 `AppLayout.pageTopPadding = 16` 和 `.appPageTopPadding()`
  - 所有标准页面滚动容器统一 16pt 顶部留白；修复今日饮食、训练重点等贴住导航栏的页面
  - 新增 UI 测试 `testTappingCurrentTabReturnsToSectionRoot`
- 验证：
  - tree-sitter 语法检查 35 个改动 Swift 文件，0 error
  - Windows 未编译 iOS；未真机验证 `UITabBar` 手势和 16pt 视觉效果
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate`（新增 `App/TabBarReselectObserver.swift`，必须重新生成工程）→ build/test
  - 运行 `testTappingCurrentTabReturnsToSectionRoot`、`testSwitchingTabsReturnsToSectionRoot`
  - 真机验证：我的 → 设置 → 再点我的 = 我的根
  - 真机验证：记录 → 训练记录 → 再点记录 = 记录根
  - 真机验证：今日 → 变化 → 再点今日 = 今日根
  - 确认普通切 Tab、Tab 栏点击和滑动没有被 observer 拦截
  - 逐页确认顶部留白：今日饮食、训练重点、设置、变化、训练历史、计划历史、器械识别、饮食记录、体型照片；不能出现 double padding
- 不要恢复：
  - 不要用 `.id()` 重建 Tab 根页面
  - 不要把 observer 改成 `cancelsTouchesInView = true` 或独占手势
  - 不要恢复各页面 2 / 8 / 10 / 12 / 14 的零散顶部 padding
  - 不要把 `.appPageTopPadding()` 套到 action bar / sticky footer

### 2026-11-06 · Windows / OpenCode（切换 Tab 回根页面）

- 提交：`03eb5ee`；UI 测试：`b6b0d75`
- 做了什么：
  - 新增 `AppTab` / `TabRoute` / `appTabDestinations()`，统一五个 Tab 的 tag 和根级 push 目的地
  - `MainTabView` 为今日 / 记录 / 发现 / 我的各持有一个 `NavigationPath`；切换 Tab 时清空全部 path，只弹掉二级页面，不重建根页面
  - 根级入口改为 `NavigationLink(value:)`：变化、训练记录、饮食、编辑档案、设置、动作教程、器械库
  - 设置仍从「我的」工具栏进入，改用 value 路由
  - 新增 UI 回归测试 `testSwitchingTabsReturnsToSectionRoot`：我的 → 设置 → 今日 → 我的，应回到我的根
- 验证：
  - tree-sitter Swift 语法检查 13 个文件，0 error
  - Windows 未编译 iOS，未在模拟器 / 真机验证
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate`（新增 `App/TabRoute.swift`，必须重新生成工程）→ build/test
  - 运行 `testSwitchingTabsReturnsToSectionRoot` 和现有 UI 导航测试
  - 验证：我的 → 设置 → 切今日 → 回我的 = 我的根
  - 验证：今日 → 变化 → 切记录 → 回今日 = 今日根
  - 验证：记录 → 训练记录 → 切今日 → 回记录 = 记录根
  - 验证：发现 → 动作教程 → 切今日 → 回发现 = 发现根
  - 确认切 Tab 后各根页面滚动位置、教练输入、记录页选中日期仍保留
  - 重复点当前 Tab 回根已在 `40f3027` 补上
- 不要恢复：
  - 不要用 `.id()` 重建 Tab 根页面
  - 不要恢复根级 `NavigationLink { destination }`（会绕过 path）
  - 不要在切 Tab 时清空教练输入或根页面状态

### 2026-11-06 · Windows / OpenCode（饮食份量区间 + 文案精简）

- 提交：见 `git log -1`
- 做了什么：
  - 饮食视觉 prompt 改为先找盘子/碗/勺子/手等自然参照物，再按覆盖面积、高度和密度估算
  - 输出 `grams_min` / `grams_max` / `portion_confidence` / `portion_basis`，不再只给一个假精确数字
  - 后端校验热量与宏量营养，偏差过大时按蛋白/碳水/脂肪反推
  - 免责声明压缩为一行；拍照提示、结果页重复的模型说明和重复免责声明删除
  - 教练欢迎卡删掉重复的剩余额度，只在输入框上方显示
  - 训练编排、编辑档案、组间提示、目标重量说明压缩
- 验证：
  - 后端 **196 passed**，Ruff 通过
  - 生产 `/health`、`/health/ready` 200
  - Windows 未编译 iOS；未用真实餐食照片做端到端验证
- Mac 需要做：
  - `git pull` → `xcodegen generate` → build/test
  - 用真实餐食照片检查份量区间、置信度、Stepper 修改后热量重算
  - 检查饮食拍照、教练、训练编排、编辑档案没有因删文案出现空洞或截断
  - 安全、过敏、隐私、支付、注销提示必须仍在
- 不要恢复：
  - 不要恢复「结果来自远程识别服务，照片未保存」等重复模型说明
  - 不要把饮食免责声明重复放在结果卡和页面底部
  - 不要把教练剩余额度同时放在欢迎卡和输入框

### 2026-11-06 · Windows / OpenCode（训练阶段 + 按动作负荷 + 额度 10）

- 提交：见 `git log -1`
- 做了什么：
  - V22 增加 `profiles.training_stage`，0–59 小白 / 60–119 有基础 / 120+ 进阶，按 Asia/Shanghai 完成训练日回填，只升不降
  - 新增 `training_history` / `load_progression`：读取最近 12 周每个动作的 SetLog，回退最近计划目标，最后才估算
  - 计划生成不再信任 AI 重量，服务端按动作覆盖 `weight_kg`；模板和本地兜底同一规则
  - 4 周渐进：小白周 2/4、有基础周 3、进阶周 4；上肢 2.5%、下肢 5%（进阶减半）
  - 每周 AI 调整改为按动作 RPE/完成情况逐动作乘系数，不再全局 ×1.025
  - iOS `LoadProgression`、`training_stage` 解码、阶段标签、`PlanAdjustmentCoach` 按动作权重
  - 免费教练额度 3 → 10；iOS 文案从服务端 `weekly_limit` 读取
- 验证：
  - 后端 **193 passed**，Ruff `app/tests` 通过
  - V22 Flyway `success=1`；生产 `/me/access` 返回 `weekly_limit=10`
  - `training_stage` 登录/`/auth/me` 返回 `beginner`
  - Windows 未编译 iOS；后端未做真实计划生成的端到端真机验证
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate` → build/test
  - 真机：有历史动作的计划生成应显示基于上次重量的目标；无历史动作显示保守估算
  - 教练「调整计划」按动作变化，不再所有动作同一个比例
  - 训练阶段显示在「我的」页；免费教练文案显示 10 条
- 不要恢复：
  - 不要恢复全局 `weightMultiplier` 的每周调整
  - 不要让 AI 输出直接覆盖服务端计算的历史重量
  - 不要把 `COACH_WEEKLY_LIMIT` 改回 3
  - 不要删除 V22 或 `training_stage` 回填

### 2026-11-06 · Windows / OpenCode（今日→记录日期联动 + 编辑按钮）

- 提交：见 `git log -1`
- 做了什么：
  - `AppStore.pendingRecordDate` + `openRecord(for:)`，跨 Tab 传日期
  - Today「查看这一天的计划」带上当前 `selectedDate`
  - 记录页接收后设置 `selectedDate` / `visibleMonth`，滚动到当天卡片
  - 返回 Today 时 Today 和记录页都重置到今天
  - 记录页「编辑」改为荧光绿实心胶囊「编辑计划」+ pencil 图标
- 验证：
  - Windows 未编译 iOS；只做代码修改和静态检查
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate` → build
  - Today 选 11/5 → 查看这一天的计划 → 记录页选中 11/5，日历在 11 月
  - 记录页看 11/7 → 点今日 → 再点记录 → 回到今天
  - Today 直接点记录 → 保留记录页上次日期
  - 编辑计划按钮明显可点，打开对应日期编辑器
- 不要恢复：
  - 不要把「查看这一天的计划」改回只 `selectedTab = 1`
  - 不要删除 `pendingRecordDate` 和 `onChange` 联动
  - 不要把编辑按钮改回微型文字

### 2026-11-06 · Windows / OpenCode（设置页清理 + 移除第三方署名）

- 提交：见 `git log -1`
- 做了什么：
  - 删除设置页 `动作图：Exercise data by RepDB (repdb.co)` 和 `体型人台：RawPheasant5745 · CC BY 4.0` 两条署名
  - `legacy_exercises.json` 中 `xj_0011` / `xj_0320` 的 `motion_start_url` / `motion_end_url` 置空，旧本地数据不再加载 RepDB 图
  - `FrameMotionBoard` 改为通用「双帧示意」，移除 RepDB 角标、链接和无障碍文案；代码保留给自有素材
  - `tools/db/import_xunji_movements.py` 清空 RepDB 样例，保留空 hook，避免重新导入
  - Release 隐藏「服务状态」整段；Debug 保留；Release 不再请求 `/health`
  - 隐私政策移除 RepDB 第三方提及
- 验证：
  - `legacy_exercises.json` 解析成功，1293 条；非空 motion URL 为 0
  - iOS 用户可见文案中已无 RepDB / RawPheasant 署名
  - 后端无改动
  - Windows 未编译 iOS
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate` → build/test
  - Release 设置页确认没有「服务状态」、没有两条署名
  - Debug 设置页确认「服务状态」仍在
  - 打开 `xj_0011` / `xj_0320` 动作详情，确认只显示占位轨迹，不加载 RepDB 图片
- 不要恢复：
  - 不要把 RepDB URL 写回 `legacy_exercises.json`
  - 不要把 RawPheasant / RepDB 署名加回设置页
  - 不要删除 `#if DEBUG` 里的服务状态代码

### 2026-11-06 · Windows / OpenCode（头像上传/移除）

- 提交：`c6e6eb4`（代码）；文档见本次提交
- 做了什么：
  - 复用 `users.avatar_url TEXT`，不新建表、不新增迁移
  - 新增 `POST /api/v1/me/avatar`、`DELETE /api/v1/me/avatar`
  - 服务端 Pillow 校验、中心裁剪 512×512、转 JPEG、去 EXIF，限制 8MB
  - `/auth/me`、`/me`、登录响应返回顶层 `avatar_url`
  - iOS `AvatarEditorButton`：相册 + 拍照、昵称首字占位、上传中 spinner、失败提示、移除头像
  - `AuthStore.avatarURL`、`APIClient+Avatar`、`AppConfig.resolveMediaURL` 支持相对媒体路径
  - 隐私政策补充头像上传与服务器存储说明
- 验证：
  - 后端 **184 passed**，Ruff `app/tests` 通过
  - 真实上传 200，下载 512×512 RGB；`/auth/me` 返回 `avatar_url`
  - 换头像后旧文件 404；移除后新文件 404、`avatar_url` 为空
  - 未登录上传 401；`text/plain` 上传 415
  - Windows 未编译 iOS
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate` → build/test
  - 真机验证：相册选图、拍照、上传、重启后头像保留、移除后回到昵称首字
  - 确认「我的」页头像 52×52，不挤压昵称和箭头布局
  - 确认 Release 仍然没有「开发服务器」「测试连接」
- 不要恢复：
  - 不要新增 `user_avatars` 历史表；当前头像只放 `users.avatar_url`
  - 不要把头像字段放进 `profiles` 表
  - 不要移除 Pillow/EXIF 清理/512 裁剪
  - 不要删除 `AvatarEditorButton` 或把上传逻辑塞回 `ProfileView`

### 2026-11-05 · Windows / OpenCode（Release 隐藏测试入口）

- 提交：`07e6936`
- 做了什么：
  - `ios/project.yml` 的 Release `FITAI_API_BASE_URL` 固定为 `https://hk-api.jiaolianfit.cn/api/v1`
  - 登录页「开发服务器」入口仅 Debug 显示
  - 设置页 API 地址 + 「测试连接」仅 Debug 显示
  - `AuthStore` / `APITransport` / `SubscriptionManager` 的 Debug 提示在 Release 改为普通用户提示
  - 测试代码全部保留，用 `#if DEBUG` + 注释标记，未删除
- 验证：
  - Windows 只做代码修改和静态检查，没有 Xcode，**未编译 iOS**
  - 后端仍在运行，Release API 地址已确认
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate`
  - Release build 确认 `FitAIAPIBaseURL` 是 `https://hk-api.jiaolianfit.cn/api/v1`
  - 确认 Release 登录页没有「开发服务器」、设置页没有「测试连接」/API 地址
  - 真机验证 Apple 登录、手机验证码、建档、AI 计划、教练对话、拍照上传
  - 如果编译报错，把报错原文发回
- 不要恢复：
  - 不要把测试入口重新暴露到 Release
  - 不要删除 `#if DEBUG` 里的开发服务器/测试连接/调试提示代码
  - 不要把 Release 地址改回 `https://api.invalid/api/v1`

### 2026-11-05 · Windows / OpenCode（香港 TestFlight 后端上线）

- 提交：`f8e085e`（后端上线）；隐私页与文档见本次提交
- 做了什么：
  - 香港 ECS：2 核 4G / Ubuntu 22.04.5 / Docker 29.9.3 / Compose v5.7.0
  - 域名 `hk-api.jiaolianfit.cn` → `8.218.205.149`，Caddy 自动申请 Let's Encrypt 证书
  - MySQL 8.4 容器，Flyway V1–V21 全部 `success=1`
  - FastAPI 2 worker + Caddy 反代；`fitai-db` / `fitai-api` / `fitai-caddy` 全部 healthy
  - `ios/project.yml` 的 Release `FITAI_API_BASE_URL` 改为 `https://hk-api.jiaolianfit.cn/api/v1`
  - 新增 `docs/48-hk-testflight-backend.md`（服务器、命令、备份、迁移说明）
  - 新增 `deploy/hk/`：Caddyfile、docker-compose、隐私政策/支持页
  - 隐私政策 `https://hk-api.jiaolianfit.cn/privacy`、支持页 `https://hk-api.jiaolianfit.cn/support`
  - 创建 App Review 测试账号 `test_reviewer`（`is_test=true`，密码只在 Windows 桌面文件，不入库）
  - 阿里云 PNVS 短信已接通：`SMS_PROVIDER=aliyun_pnvs`，赠送签名「恒创联众」，模板 100001；真实手机号发送成功
  - iOS Release 隐藏开发服务器、测试连接、Debug 网络错误提示；相关代码用 `#if DEBUG` 保留并加注释，未删除
- 验证：
  - `https://hk-api.jiaolianfit.cn/health` → `{"status":"ok","env":"production","llm":"deepseek-flash","vision":"deepseek-flash"}`
  - `https://hk-api.jiaolianfit.cn/health/ready` → `{"status":"ready"}`
  - `http://` → `308` 跳 HTTPS
  - DeepSeek `/chat/completions` 真实调用返回 200
  - 账号密码登录 → `/auth/me` → `/me/access` 全链路 200；免费教练额度 10 条/周
  - `/privacy`、`/support` 返回 200 `text/html`
  - MySQL 27 个动作已 seed；当前内存 API 175MB + DB 517MB + Caddy 11MB
  - 后端 **178 tests passed**，Ruff（改动文件）通过；`alibabacloud_dypnsapi20170525` 已安装进 API 镜像
  - `POST /auth/phone/send-code` 返回 200，`delivery=aliyun_pnvs`；用户已收到验证码
  - Windows 没有编译 iOS；Release 隐藏测试入口需 Mac 构建确认
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate`
  - Release build 确认 `FitAIAPIBaseURL` 是 `https://hk-api.jiaolianfit.cn/api/v1`
  - 真机验证：Apple 登录、手机验证码、建档、AI 计划、教练对话、拍照上传、`/me/access`
  - 确认 Release 登录页没有「开发服务器」、设置页没有「测试连接」/API 地址
  - 手机验证码已可用；短信发送方显示「恒创联众」，内测帖需提前说明
- 不要恢复：
  - `ios/project.yml` 里的 `https://api.invalid/api/v1`
  - 不要把 `/opt/fitai/.env`、MySQL 密码、JWT、DeepSeek Key 提交到仓库
  - 不要对公网开放 3306 / 8000
- 仍 BLOCKED：IAP 商品与协议、App Store Server API Key/Issuer/p8、Notifications V2 URL、TestFlight 外部 Beta 审核、Mac Release 签名上传、Watch 3D 动作素材、真实 Watch App ID/HealthKit capability、TestFlight/App Store 真机验收

### 2026-11-05 · Windows / OpenCode（男性椭圆/梯形 16–20% 素材）

- 提交：`483508e`
- 做了什么：
  - 用新源图 `椭圆型16%-20%.png`、`梯型16%-20%.png` 替换：
    - `BodyFigureMaleOvalFat16To20`
    - `BodyFigureMaleTrapezoidFat16To20`
  - 新源图是 1440×2560、带浅灰纹理背景的 RGB 图，不是纯白底
  - 用“最大前景连通域 + 填洞 + 轻微边缘羽化”抠图，去掉纹理背景和零星噪点
  - 输出保持 400×667、14px 边距、透明背景；alpha bbox 与旧图一致 `(38, 14, 362, 653)`
  - 没有改 UI、枚举、资产名或测试
- 验证：深色/浅色合成预览干净，无白边/灰底残留；尺寸、四角透明、bbox 正确；
  Swift 文件未改；Windows 没有跑 iOS 构建
- Mac 需要做：`git pull` → `xcodegen generate` → build；在浅色/深色下看男性“椭圆型/梯形 + 16–20%”的体型页、体脂卡和报告组合图
- 不要恢复：旧的两张 16–20% 椭圆/梯形图；不要把新源图原图直接导入

### 2026-11-04 · macOS

- 提交：`9f138e8`（测试修复）、`a52ca9f`（上一条同步）均未推送；本轮 Debug 签名修复未提交；键盘排查未改产品代码
- 做了什么：
  - 拉取 `95e8e5c`，完成 iOS 构建、SwiftLint、单元测试、UI 导航测试和 backend 测试。
  - 修复 `BodyFigureAssetTests.alphaChannel` 的测试辅助 bug：`CGImage` 绘制到 bitmap context 后 row 0 已经是顶部，重复做垂直翻转会让 torso 探针读到画布下半区，造成 `testTorsoCropKeepsTheBodyOpaque` 假失败。只改测试，不改 UI/素材。
- 验证：
  - iOS build 成功；SwiftLint **0 violation**
  - iOS unit **44/44**；UI 导航测试通过
  - backend **175 passed** + Ruff 通过
- Debug 真机签名方案（已实现）：
  - Debug 使用独立 Bundle ID `com.wjk.fitai.dev` 和 `FitAI-Debug.entitlements`（保留 HealthKit，不含 applesignin）。
  - Debug 隐藏 Apple 登录入口；Keychain service 使用 `com.fitai.app.auth.debug`，不与 Release 共享登录态。
  - Release 继续使用 `com.wjk.fitai` + `FitAI.entitlements`，Apple 登录和正式 capability 不变。
  - Debug 真机构建 **成功**，已安装并启动 `com.wjk.fitai.dev`；模拟器 44 个单测 + UI 测试通过，SwiftLint 0 violation。
- 键盘首次加载专项（已完成定位，未改产品代码）：
  - `xctrace` 直接启动 / attach：0 个 >250ms 主线程 hang；主线程 CPU 分别约 3.15s / 2.34s，键盘相关约 0.99s / 0.83s。
  - Xcode `Start the active scheme`（带 LLDB/诊断）首次键盘：出现 539ms、725ms、1.64s 和 **2.27s/2.33s Severe Hang**。
  - 临时关闭 Debug executable + Main Thread Checker + Thread Performance Checker 后，用户实测不再卡顿。
  - 结论：是 Xcode 调试运行环境放大了首次键盘/CoreText 初始化成本，不是 App 业务逻辑或 UI 布局问题。
  - 诊断用的 scheme 临时改动已通过 `xcodegen generate` 恢复；临时 `TextInputPrewarm` 和键盘计时测试已移除。
- 仍待处理：
  - Release 真机/TestFlight 仍需支持 Sign in with Apple capability 的付费团队；`FITAI_API_BASE_URL` 仍是占位域名。
  - 如 Release 首次键盘仍复现，再继续查系统键盘进程。
- Windows 需要提供：
  - 生产 API 域名；Release 真机/TestFlight 的付费 Team/描述文件。
  - 键盘专项暂不需要 Windows 继续排查；如 Release 仍复现再回传。

### 2026-11-04 · Windows / OpenCode（真机键盘卡顿排查请求）

- 提交：暂无代码变更；当前代码 HEAD `a6de43d`
- 现象：
  - iPhone 14 Pro / iOS 18 真机
  - 所有输入框调起系统键盘都卡 5–10 秒，登录页最明显
  - 空账号也卡
  - 只用系统键盘，没有第三方输入法
- Windows 初步判断：
  - 基本排除第三方键盘
  - 空账号也卡，持久化 state 不是唯一原因
  - 优先怀疑 App 级主线程阻塞或 SwiftUI 键盘布局/全屏背景重绘
- 可能热点（按优先级）：
  1. `LoginView`：`GeometryReader` + `ScrollView` + `.scrollDismissesKeyboard(.interactively)` + 条件 `.safeAreaInset` 键盘完成栏，键盘出现时布局链较复杂
  2. `AppBackground` / `GrainTexture`：全屏渐变 + 平铺纹理，每次键盘 safe-area 变化都可能重绘
  3. `FitAIApp.task` 启动即 `await subscriptions.load()`：StoreKit 首次商品请求可能占用主线程
  4. `RootView.task` 的 `auth.restoreIfNeeded()`；`AppStore.load()` / `switchUser()` 同步 JSON 读盘解码
  5. 登录页 `.textContentType(.telephoneNumber/.oneTimeCode)` 触发 AutoFill
- Mac 需要做（按顺序，先取证再改）：
  1. `git pull`；分别用 Debug 和 Release 真机测试，确认是否只在 Debug 卡
  2. 删除 App 重装，不登录，点登录手机号框；仍卡则不是本地 state
  3. Xcode 控制台搜 `STRESS load`；下载 App container，查看 `Documents/fitai-state*.json` 大小
  4. Instruments Time Profiler 录 10 秒：启动 → 点手机号输入框；抓主线程最重栈（重点看 JSONDecoder、Data(contentsOf:)、StoreKit、SwiftUI layout、Text/Gradient 绘制）
  5. 逐项隔离（每项单独测，记录结果）：
     - 注释 `FitAIApp.task` 里的 `await subscriptions.load()`
     - 注释 `RootView.task` 里的 `auth.restoreIfNeeded()`
     - LoginView 临时把 `AppBackground()` 换成 `Theme.background`
     - 临时去掉 `.safeAreaInset` 的键盘完成栏
     - 临时去掉 `.scrollDismissesKeyboard(.interactively)`
     - 临时去掉外层 `GeometryReader`（用固定 compact 值）
  6. 做一个最小 SwiftUI TextField 页面，逐项加回背景/ScrollView/safeAreaInset/GeometryReader，确认哪一层触发
  7. 系统设置里关闭 AutoFill Passwords 再试；临时去掉登录页 `textContentType` 再试
  8. 对比 iOS 18 模拟器和另一台真机；排除系统键盘/AutoFill 问题
- 回传：
  - Debug/Release 结果
  - `STRESS load` 日志、state 文件大小
  - Time Profiler 截图/最重栈
  - 哪一项去掉后不卡
- 不要：
  - 不要先猜着提交“修复”
  - 不要删除键盘完成栏/背景组件
  - 不要用 `DispatchQueue.main.sync` 之类方式掩盖问题

### 2026-11-04 · Windows / OpenCode（真实视觉 / AI 计划 / 视频隐藏 / TestFlight 加固）

- 提交：`8b1d57a`、`c133d24`
- 做了什么：
  - 视觉默认复用 DeepSeek Flash：`VISION_MODEL` 留空时回退 `LLM_MODEL`，
    `VISION_BASE_URL`/`VISION_API_KEY` 留空时复用 `LLM_*`
  - 已用本地图片实测 `deepseek-flash` 的 image_url 输入返回 200，真实视觉可用
  - 计划生成默认 `LLM_PLAN_ENABLED=true`，reasoning 用 `low`；
    AI 失败/超时仍走规则模板；iOS 计划 toast 区分 AI / 模板
  - 首次建档计划也允许走远程 AI，失败再回退本地模板
  - 教学视频入口全部隐藏：`AppConfig.exerciseVideosEnabled=false`；
    播放器/占位代码保留在 `EquipmentDetailView+Media.swift`，不要删除
  - 器械详情加固：
    - 资源 JSON 缺失/重复不再 `assertionFailure` 崩溃
    - 图表过滤非有限值，避免 NaN 导致 Charts 异常
    - 视频请求在开关关闭时不再触发（生产 `PUBLIC_BASE_URL` 为空时该接口会 503）
  - 补 Sign in with Apple entitlement
  - Release API 改为从 `Info.plist`/`FITAI_API_BASE_URL` 读取，Debug 才允许 localhost；
    当前占位 `https://api.invalid/api/v1`，上 TestFlight 前必须替换
  - `PrivacyInfo.xcprivacy` 补 Device ID / Purchase History / Product Interaction；
    视频大小检查改用 `resourceValues(forKeys:)`，避开 File Timestamp required-reason API
  - 后端生产启动校验：缺 JWT/PUBLIC_BASE_URL/Apple/StoreKit/LLM 配置直接启动失败
  - 新增 `docs/47-testflight-checklist.md`
- 验证：backend **175 passed** + Ruff 通过；真实视觉调用成功；
  Swift 语法解析通过；Windows 没有跑 iOS 构建/单测
- Mac 需要做：`git pull` → 填 `FITAI_API_BASE_URL` → `xcodegen generate` → build/test；
  重点回归器械详情（之前报错）、计划生成、拍照识别、视频入口是否完全隐藏
- 如果器械详情仍报错：把 Xcode 控制台第一行或崩溃堆栈发给 Windows agent；
  本次已修掉最可能的资源初始化、Charts NaN、视频接口三条路径
- 不要恢复：旧的 Mock 视觉、视频入口、localhost Release API、JSON `assertionFailure`

### 2026-11-04 · Windows / OpenCode（桌面图标 / 欢迎文案 / 透明性别素材）

- 提交：`c2c71bc`、`c79df35`
- 做了什么：
  - 桌面 `AppIcon` 换成 `logo.png` 的 1024×1024 版本：RGB、无 alpha、不做圆角
  - 旧哑铃/L 标志全部清理：启动恢复页、登录页头部、器械详情教练卡都改用 `CoachMark`
  - 欢迎页第一段改成「您好，/ 我是叫练」，打字参数不变
  - 性别页换用 `性别女-卡通-透明.png` / `性别男-卡通-透明.png`：
    直接使用自带 alpha，重新生成 800×1422 全身和 250×250 头像
  - 透明背景、手臂空隙、背景采样测试继续通过
- 验证：性别页深/浅色预览干净；AppIcon 1024×1024 RGB 无 alpha；
  Swift 语法解析通过；backend **174 passed** + Ruff 通过；
  Windows 没有跑 iOS 构建和单测
- Mac 需要做：`git pull` → `xcodegen generate` → build/test；
  看桌面图标、启动恢复页、登录页、器械详情教练卡、欢迎文案，
  以及性别页全身/头像的浅色和深色显示
- 不要恢复：旧 AppIcon、旧哑铃/L 标志、旧欢迎文案、旧性别素材

### 2026-11-04 · Windows / OpenCode（App 内新 Logo）

- 提交：`b1407f6`
- 做了什么：
  - `CoachMark` 不再画圆底 + L，改用 `BrandLogo` 图片资产
  - 新增 `BrandLogo.imageset`：由 `logo.png` 缩到 512×512，保持黑底 + 荧光绿图形
  - 显示时裁成 iOS 风格圆角方形（圆角约 23.5%），加一圈自适应细边，
    深色模式下也能看出边界
  - 影响位置：首页右上、教练聊天头部、首页教练笔记、欢迎页、名字页提示
  - 桌面 AppIcon 未改，仍是旧的哑铃图标
  - 新增 `BrandAssetTests`，检查 `BrandLogo` 存在、是正方形且不小于 256
- 验证：76/58/38/34 四档深色/浅色预览目检通过；Swift 语法解析通过；
  backend **174 passed** + Ruff 通过；Windows 没有跑 iOS 构建和单测
- Mac 需要做：`git pull` → `xcodegen generate` → build/test；
  检查首页右上 38、欢迎页 76、聊天头部 58、教练笔记 34 的显示，
  深色模式下圆角边界和荧光绿是否清楚
- 不要恢复：旧的 SwiftUI 圆底 + L `CoachMark`；不要把 2048 原图直接塞进 assets

### 2026-11-04 · Windows / OpenCode（性别页卡通素材）

- 提交：`f9633fe`
- 做了什么：
  - 性别页大人台和双卡头像换成 `性别男-卡通.png` / `性别女-卡通.png`
  - 男性源图是棋盘格背景（已烤进像素，不是真透明），女性源图是纯白底；
    两者都重新抠成透明背景
  - 男性源图底部/右侧有 1px 黑色导出边框，处理前裁掉 2px
  - 保留女性白色腕带、短裤白色条纹；男性短裤白条也保留
  - 全身图 `800×1422`，头像 `250×250`；资产名不变，页面代码不变
  - 测试新增顶部左右两个背景采样点，防止棋盘格/白底残留
- 验证：深色/浅色合成预览目检通过，手臂/腿间无白条，腕带和白条纹保留；
  Swift 语法解析通过；backend **174 passed** + Ruff 通过；Windows 没有跑 iOS 构建和单测
- Mac 需要做：`git pull` → `xcodegen generate` → build/test；
  浅色/深色看性别页，重点看 52×52 小头像有没有裁到脸、
  大人台底部渐隐是否自然、头发边缘有没有白边
- 不要恢复：旧性别插画、棋盘格/白底版本；不要把 `性别男-卡通.png` 原图直接导入

### 2026-11-04 · Windows / OpenCode（体脂卡改躯干图）

- 提交：`5c906fb`
- 做了什么：
  - `BodyFigure` 新增 `crop` 参数：`.fullBody`（默认）/ `.torso`
  - 体脂卡改用 `.torso`：按 400×667 共享画布裁掉头、手和腿，
    只保留肩颈到胯部，胸腹腰的体脂差异更直观
  - 裁切矩形 `(0.215, 0.142, 0.570, 0.398)`，运行时按比例裁切，
    不新增 54 张图片，54 张组合图本身未改动
  - 去掉体脂卡图片的 shadow，避免沿裁切边缘出现横向阴影
  - 体型页大图/缩略图和最终报告仍显示全身
  - 新增测试：组合图必须都是 400×667、裁切矩形在画布内、
    代表图躯干中心不透明
- 验证：深色/浅色裁切预览目检通过；Swift 语法解析通过；
  backend **174 passed** + Ruff 通过；Windows 没有跑 iOS 构建和单测
- Mac 需要做：`git pull` → `xcodegen generate` → build/test；
  在浅色/深色下看体脂页，确认 6 张卡只显示躯干、没有头/手/腿，
  选中边框和标签高度不跳动
- 不要恢复：体脂卡全身图、体脂卡图片 shadow、`BodyFigureCrop` 之外的硬编码裁切

### 2026-11-04 · Windows / OpenCode（性别插画白底修复）

- 提交：`8c3ba77`
- 做了什么：
  - 重新处理 `性别男.png` / `性别女.png` 的透明通道：不再只从边缘泛洪，
    改为按连通区域删除封闭白块（手臂与躯干之间、双腿之间）
  - 覆盖 `GenderMale` / `GenderFemale` 的 `body-figure.png`
  - `GenderMalePortrait` / `GenderFemalePortrait` 头部裁切无封闭白块，文件未变
  - 新增 `BodyFigureAssetTests.testGenderAssetsHaveTransparentBackground`：
    检查四角透明、手臂空隙透明、躯干不透明
- 验证：深色/浅色合成图目检通过；Swift 语法解析通过；backend **174 passed** + Ruff 通过；
  Windows 没有跑 iOS 构建和单测
- Mac 需要做：`git pull` → `xcodegen generate` → build/test；
  在浅色和深色下看性别页，确认手臂/腿间没有白色竖条，腕带和短裤白条仍在
- 不要恢复：旧的整图泛洪抠图脚本；不要把白底图片重新导入 `GenderMale` / `GenderFemale`

### 2026-11-04 · Windows / OpenCode（欢迎打字速度）

- 提交：`420ea75`
- 做了什么：欢迎页打字速度第一段 42→90ms/字，第二段 30→70ms/字；
  标点停顿 160→280ms，新增换行 220ms；触感频率降到 5/7
- 验证：Swift 语法解析通过；Windows 没有跑 iOS 构建
- Mac 需要做：build 后看一遍欢迎页，确认能看清、不拖沓；点屏幕仍可立即显示全文
- 不要恢复：旧的 42/30ms 快速打字参数

### 2026-11-04 · Windows / OpenCode（性别 / 体型 / 体脂重做）

- 提交：`5707370`
- 做了什么：
  - 性别页改用 `性别男.png` / `性别女.png` 插画：完整图做大人台，头部裁切做双卡头像
  - 删除旧的 `BodyFigureMalePortrait` / `BodyFigureFemalePortrait`
  - 体型页改为「上方大图 + 下方横向缩略图」；默认用第三档体脂预览（女 19–22%，男 16–20%）
  - 删除体型卡上的「建议」标签和 `BodyTypeCard`
  - 体脂页改为 2×3 图片网格；选中卡深色边框 + 深色标签条；不再显示备注文案
  - 新增 `BodySelectionViews.swift`，体型/体脂卡从 `BodyShapes.swift` 拆出
- 验证：backend **174 passed** + Ruff 通过；Windows 只做 Swift 语法解析，**没有跑 iOS 构建**
- Mac 需要做：`xcodegen generate`；重点检查性别插画裁切、体型默认第三档、体脂 2×3 网格、浅色/深色选中态
- 不要恢复：`BodyTypeCard`、`BodyFigureMalePortrait`、`BodyFigureFemalePortrait`、体型卡「建议」标签
- BLOCKED：同上

### 2026-11-04 · Windows / OpenCode

- 提交：`a313cf7`（文档）、`7324577`（训练重点）、`f78cf1e`（性别页）、
  `2ce8ae1`（体型/体脂图）、`4fcf8c4`（免费教练额度）
- 做了什么：
  - 免费教练文本改走 `/agent/chat`；额度用尽不再本地回复，聊天页显示内联 Pro 卡
  - 接入 54 张体型/体脂组合图；onboarding 改为先体型后体脂；报告显示组合图
  - 性别页改为头像双卡 + 自适应大人台
  - 训练重点改为器械页同款卡片网格；「均衡练全身」为互斥卡；取消最多 2 个限制
  - 计划生成不再截断前 2 个重点；全选 7 个按均衡处理
  - 删除 `BodyFocusMap`、`BodySilhouette`、`BodyType.shoulder/waist/hip` 等旧人体图代码
- 验证：backend **174 passed** + Ruff 通过；Windows 只做 Swift 语法解析，**没有跑 iOS 构建**
- Mac 需要做：`xcodegen generate`；重点检查浅色/深色性别页、体型/体脂卡、训练重点 8 张卡、报告组合图
- 不要恢复：旧轮廓人体组件、`BodyFocusMap`、`BodySilhouette`、`BodyType` 比例参数
- BLOCKED：同上，外部 Apple/真机/预发环境仍未验证

### 2026-11-03 · macOS

- 品牌改名「叫练」：iOS 显示名、登录/付费墙、法律文档、AI 提示词、后台和文档
- 运营者：深圳市龙岗区叫练软件开发工作室；技术标识保持不变
- 验证：iOS 构建成功、SwiftLint 0 violation、29/29 单测、backend 171 + smoke
- 待 Windows 复核：品牌残留、法律主体、后台旧品牌

---

## 1. 当前工作区与状态

- Windows 仓库：`E:\Projects\FitAI`
- macOS 工作区：`/Users/jacobwu/gym-app`
- 当前分支：`feat/pro-access-followup-2026-11`，基于 `develop`
- 远端 `develop`：代码 `483508e`；文档提交在其后，见 `git log -1`
- 正式发布前仍需真实数据库、真机和 App Store Connect 配置

> **2026-11-03 macOS 进展：品牌已改名「叫练」。** 用户可见品牌、法律文档、
> AI 提示词、后台和文档均已同步；运营者为「深圳市龙岗区叫练软件开发工作室」。
> 技术标识保持不变：Bundle ID `com.wjk.fitai`、IAP `com.fitai.app.pro.*`、
> URL Scheme `fitai`、Keychain/UserDefaults/本地存储、Xcode target/module
> `FitAI`、Java 包名和数据库名。图标暂不改。
>
> 验证：iOS 构建成功，SwiftLint **0 violation**，单元测试 29/29，UI 导航测试通过；
> backend 171 个测试 + smoke 通过；全仓库 `练途` 已清零。
> 外部凭据/真机/预发库/App Store Connect 项仍标 BLOCKED。

历史 CI（改名提交后请以新 CI 结果为准；不要引用旧提交的绿色状态）：

- Backend Tests #102：✅ `afd4afc`
- iOS Build #224：✅ `314cd49`
- Admin CI #27：✅ `296b3eb`

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
- AI 教练 10 条/周；安全/医疗回复不占额度、不弹付费墙
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

### 品牌与工程收尾（2026-11-02/03，已完成，不要重做）

- **品牌改名「叫练」**：iOS 显示名、登录/付费墙/权限/水印、法律文档、AI 提示词、
  FastAPI 标题、admin-web/admin-server 品牌、README/docs/preview 用户可见文案均已更新。
- **App Store 名称**先用「叫练」；App Store Connect 名称/副标题/截图/隐私政策 URL 需手工更新。
- **运营者**：深圳市龙岗区叫练软件开发工作室；法律文档范围「叫练 iOS 内测版」，
  更新日期 2026-11-03；客服邮箱仍为 `wjk0759@163.com`。
- **App Store Server API**：`backend/app/services/app_store_api.py`、`POST /iap/app-store/reconcile`、
  `backend/scripts/reconcile_storekit.py` 和 mock 测试已完成；真实 Apple 请求因缺 Key/Issuer/p8 而 BLOCKED。
- **拍照幂等**：`feature_result_cache` V21 + `photo_cache`，覆盖体型/饮食/器械/教练视觉；
  只缓存脱敏 JSON，TTL 300 秒，写入时清理过期行；不落原图。
- **设备会话**：缺 `X-Device-ID` 兼容放行；刷新 401/403 清 token、发 `.fitaiSessionExpired`
  回登录页；客服文档见 `docs/46-device-session-support.md`。
- **模块化**：AppStore/Agent/Sync/Plan/Profile/Workouts/Settings/Export 拆分；
  PlanHome/CoachOnboarding/WorkoutSession/EquipmentDetail/HomeV2/Login/Settings/
  CoachChat/Nutrition/Progress/WorkoutHistory 等大 View 已拆；Models 与 APIClient 已分域；
  代码中已无 `swiftlint:disable file_length type_body_length`，SwiftLint 0 violation。
- **测试**：backend 171 个测试通过；iOS 单元测试 29/29；UI 导航性能测试通过。

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
  - 已实现 `backend/app/services/app_store_api.py`、`POST /iap/app-store/reconcile`、
    `scripts/reconcile_storekit.py` 与 mock 测试。
  - 已实现 ES256 JWT、订阅查询、Apple JWS 二次校验、幂等台账写入；空/畸形响应会报错，
    不会伪造成功。
  - 真实 Apple 请求 BLOCKED：缺少 App Store Connect 的 Key ID、Issuer ID、p8 私钥。

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

- [ ] **BLOCKED · App Store Connect 名称与素材**
  - 代码/桌面显示名已用「叫练」；App Store Connect 名称需手工改为「叫练」，
    副标题待定。截图、隐私政策 URL、TestFlight 信息也需同步检查。
  - 名称可用性需在 App Store Connect 确认；如被占用需准备备选。

- [ ] **BLOCKED · 给测试账号 30 天 Pro 真机端到端验证**
  - 真机 `Wu-Tang` 已配对且 DDI 可用，但本机 Xcode 未登录 Apple ID、无开发证书，无法签名安装。
  - 测试账号已设置，见第 1 节。
  - 真机验证免费体验、付费墙、AI 额度、StoreKit 购买、恢复、退款。

- [ ] **BLOCKED · V14–V21 在预发/生产 MySQL 执行并核对回填**
  - 缺少预发/生产 MySQL 连接与 Flyway 权限；本次新增了 V21 `feature_result_cache`，未在任何 MySQL 执行。
  - 开发库 3307 已完成，不要重复改开发库。
  - 预发/生产只通过 Flyway 执行，不手工改表。
  - 核对 `feature_trials` 与历史 onboarded/meal week 数量。

### P1 iOS 收费体验

- [x] **拍照分析幂等键**
  - 已实现 `feature_result_cache` V21 + `photo_cache` 服务，覆盖体型、饮食、器械、教练视觉；只缓存脱敏 JSON 文本，TTL 300 秒，不落原图。
  - 客户端在体型/饮食/器械/教练视觉请求带 `Idempotency-Key`；免费用户仍先过 Pro 校验并返回 403。
  - 服务端已有同用户并发 1 和 5 秒冷却；同 key 重试会返回同一份结果。
  - 过期缓存会在写入新结果时清理；并发写入保留首个幂等结果，不覆盖。
  - 免费用户仍先过 Pro 校验；原图不落盘。

### P2 防滥用与成本

- [ ] **BLOCKED · App Attest / DeviceCheck**
  - 需要 Apple 团队配置、App Attest capability 和真机；未编写未经验证的声明式接口，避免假装上线。
  - 不要在未验证的情况下声称已上线。
  - 建议先设计 challenge/attestation 接口和开关，默认关闭。

- [ ] **BLOCKED · 重复提示词、批量注册的后台筛选与告警看板**
  - 风控看板尚未实现；本机仍缺 Java/Node/admin 测试数据库，无法本地运行 admin-server/admin-web 的 CI。
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

## 10. Windows OpenCode 同步快照

- 先拉取最新 `develop`；当前改名提交在 `develop` 历史中；本地不要重命名目录。
- 最新 Windows 提交：`7324577`（训练重点卡片网格）；之前还有 `f78cf1e`（性别页）、
  `2ce8ae1`（体型/体脂图）、`4fcf8c4`（免费教练额度）。
- **不要恢复**：`BodyFocusMap`、`BodySilhouette`、`BodyType.shoulder/waist/hip`
  等旧轮廓人体组件；用户要求删除。
- **不要改**：`ios/FitAI/`、`FitAITests/`、`FitAIUITests/`、`FitAIApp.swift`、
  `FitAI.entitlements`、`FitAI.xcodeproj`、Bundle ID、IAP 商品 ID、URL Scheme、
  Keychain/UserDefaults key、Java 包名、数据库名。
- **只改用户可见品牌**：显示名、文案、法律文档、AI 提示词、后台品牌。
- V21 迁移必须通过 Flyway 执行；后台启动前确认 `feature_result_cache` 存在。
- App Store 名称/副标题/截图/隐私政策 URL 在 App Store Connect 手工处理，代码里没有 App Store 名称配置。
