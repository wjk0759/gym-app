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

- `develop` 代码 HEAD：`a1c200a`；`main`/`testing` 仍为 `10d1ad5`（本轮只推 `develop`）；本文件的最新同步提交见 `git log -1`
- Windows 已完成：真实 DeepSeek 视觉、AI 计划默认开启、视频入口隐藏、隐私标签补充、Apple 登录 entitlement、器械详情崩溃加固、男性椭圆/梯形 16–20% 体型图更新、香港 TestFlight 后端上线、阿里云短信验证码接通、Release 隐藏测试入口、头像上传/移除、设置页清理与第三方署名移除、今日→记录日期联动、训练阶段与按动作负荷、免费教练额度 3 条/天、饮食份量区间、文案精简、切换 Tab 回根页面、重复点 Tab 回根、页面顶部留白统一、Watch 共享训练核心
- macOS 最近完成：品牌改名「叫练」；当前 iOS 构建/SwiftLint 通过，44 个单测 + UI 导航测试通过（本轮修复测试辅助）
- macOS 最新完成（2026-11-11）：equipment v2 编译修复（`6556b0a`）、taxonomy v2 测试对齐（`827ea94`）；修复 `AppStore.swift` 非法 UTF-8、`PlanGenerator` 器械池重名；`FitAITests` **62/62** 通过，phone-only Release 已安装并启动 Wu-Tang；此前完成动作库别名/计划白名单/隐藏 `other`、媒体 coverage 校验、phone-only 构建脚本、媒体图库验证、Watch UI 重设计（`fc8634c`/`bc183ae`/`d890a53`/`4af3bcb`/`2d5dea0`）
- Windows 最新完成（2026-11-07）：拉取并保留 macOS 单行语音输入（`9a833b1`）；完成教练内核统一并部署生产；`test_reviewer` 已授 Pro、补齐基础档案和 3 分化计划；生产 Watch 预载/登录/刷新/语音/撤销全链路烟测通过；iPhone 训练页动作循环动画 PoC、`/exercise-media` 批量接口、11 条 sample 媒体已上生产（`341981f`）；器械识别修复：图片归一化、禁止随机 mock、37 类器械目录、生产导入 57 条训记动作、4 张真实照片 + 1 张负例烟测 5/5 命中（`5bf99a1`）；2026-11-08 增加 Vision OCR 标签提示、18 张多品牌评测和准确率实验（`23e41c8`）；生产视觉切 **Qwen3-VL-Plus**；器械识别加 **top-2 候选 + 混淆兜底**，18 张缩略图 top-1 61%、top-2 83%（`0d63191`）；已合并到 `develop`（`48ad5f0`），develop CI 全绿
- Windows 前一轮完成（2026-11-07）：手表独立语音教练、watch 专用登录会话、媒体预载/本地缓存、离线 outbox/ack、手机 inbox 回灌、手机→手表指令、3 天 Pro 宽限与中途到期继续结束、HealthKit 保活/手机单写者、Watch AppIcon 恢复、Watch 隐私清单、训练来源 `phone/watch`
- 本地后台（2026-11-08）：FastAPI `8000`、admin-server `8080`、admin-web `5173/admin`、MySQL `3307` V24；真机 API `http://192.168.1.4:8000/api/v1`
- 最新后端验证：**220 passed**，Ruff app/tests 通过；`/watch/bootstrap`、`/watch/session`、`/coach/voice`、workout `source`、`/exercise-media`、器械目录识别、器械 top-2 已接入测试；生产 Flyway 已到 **V24**；`/me/access` 免费教练额度 `daily_limit=3`、`weekly_limit=3`、`remaining=3`，`reset_at` 为北京时间次日 00:00；`training_stage=beginner`
- 成本提醒：3 条/天 ≈ 21 条/周，是原 10 条/周的约 2.1 倍；上线后监控 DeepSeek 账单和异常调用
- Mac 待办：`git pull` → `xcodegen generate` → Release build/test → 验证计划生成/教练调整按动作读取历史重量、训练阶段显示、3 条/天额度文案；验证今日选日期→记录页自动选中、返回今日回到今天、编辑计划按钮明显；验证切换 Tab 和重复点当前 Tab 都回到各根页面；验证 Tab 栏普通点击/滑动未被 reselect observer 拦截；逐页确认顶部 16pt 留白没有 double padding；验证免费文字额度 >0 不弹订阅、拍照/视频/器械显示 Pro 标识；验证改手机时间不能刷新余额；用 `https://hk-api.jiaolianfit.cn/api/v1` 真机验证 Apple 登录、手机验证码、头像相册/拍照、建档、AI 计划、教练、拍照；确认 Release 无「开发服务器」「测试连接」「服务状态」、无 RepDB/RawPheasant 署名；确认男性椭圆/梯形 16–20% 新图；键盘问题已定位为 Xcode 调试环境，未改产品代码；本轮新增：验证训练页内嵌循环动画/全屏、Reduce Motion、音乐不中断、切后台暂停，以及 Watch 动作页播放 `watch_url`
- 仍 BLOCKED：IAP 商品与协议、App Store Server API Key/Issuer/p8、Notifications V2 URL、TestFlight 外部 Beta 审核、Mac Release 签名上传、正式 1,500 动作 × 男女素材采购与映射、真实 Watch App ID/HealthKit capability、TestFlight/App Store 真机验收

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
