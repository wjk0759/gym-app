# FitAI（中文暂定名：练途）

> **2026-10 架构更新：** 管理后台已独立为 `admin-web/`（Vue3 + TypeScript + Element Plus）与 `admin-server/`（Spring Boot 3 + JWT/RBAC + Flyway），共享 MySQL 8。详见 [企业级管理后台架构](docs/20-admin-enterprise-architecture.md)。FastAPI 继续负责 iOS/Web App API；旧 `/admin` 数据后台已迁移完成后删除，只保留 Spring + Vue 控制台。

![iOS Build](https://github.com/wjk0759/gym-app/actions/workflows/ios-build.yml/badge.svg)
![Backend Tests](https://github.com/wjk0759/gym-app/actions/workflows/backend-tests.yml/badge.svg)

面向中国大陆的 AI 健身教练 iOS App。核心闭环：**建档 → 定目标 → AI 生成计划 → 到点提醒 → 训练记录 → AI 复盘调整**。

> **Windows 上先看效果：** 双击 `preview\启动预览.cmd`，浏览器打开 <http://127.0.0.1:5173/>。这是 Web 界面预览，不是 iOS 模拟器；真实模拟器需要 Mac + Xcode。

> 当前版本：`v0.1.0` 基础工程
> 市场：中国大陆优先
> 形态：SwiftUI 原生 iOS + FastAPI 后端 + Spring 管理控制台 + MySQL 8

---

## 这一版已经交付什么

| 交付物 | 位置 | 状态 |
|---|---|---|
| 产品需求文档（P0） | `docs/01-PRD.md` | 完成 |
| 技术架构 | `docs/02-architecture.md` | 完成 |
| 数据模型说明 | `docs/03-data-model.md` | 完成 |
| PostgreSQL 建表脚本 | `db/schema.sql` | 完成 |
| API 契约 | `docs/04-api.md` | 完成 |
| AI 设计（计划 / 记忆 / 识别 / 问答） | `docs/05-ai-design.md` | 完成 |
| 中国区合规清单 | `docs/06-compliance-cn.md` | 完成 |
| 12 周开发路线 | `docs/07-roadmap.md` | 完成 |
| iOS 上手指南（Mac） | `docs/08-ios-setup.md` | 完成 |
| 交付说明与下一步 | `docs/09-handoff.md` | 完成 |
| 性能优化与基准 | `docs/10-performance.md` | 完成 |
| 训练记录深度迭代 | `docs/12-training-log.md` | 完成 |
| 灵活训练排期 | `docs/26-flexible-plan-scheduling.md` | 完成 |
| App Action Agent | `docs/27-app-action-agent.md` | 完成 |
| 动作库数据与导入 | `docs/28-exercise-library.md` | 完成 |
| 动作演示素材接入 | `docs/29-exercise-demo-media.md` | 免费示例已接 |
| 动作演示视觉方案对比 | `docs/30-exercise-visual-options.md` | 预览已生成 |
| 器械 Tab：动作选择与识别 | `docs/13-equipment-picker.md` | 完成 |
| FastAPI 后端骨架 | `backend/` | 可启动，AI 默认 Mock |
| SwiftUI App 骨架 | `ios/` | 可运行，默认本地 Mock 数据 |

**已经能跑通的产品流程：**

- 首次进入 → 填写档案与目标 → 本地生成 4 周训练计划
- 首页查看今日训练 → 开始训练 → 逐组记录重量/次数 → 休息计时 → 完成
- 训练计划查看、换动作、改组数次数
- 灵活排期：今天没空可顺延到最近空档、明确跳过，或重新安排完整训练日期；每周可以少于基准天数，少选会跳过对应训练
- AI 教练对话（DeepSeek V4.1 Flash 远程思考；含疼痛/伤病安全拦截）
- 训练偏好记忆：删掉的动作会被记住，后续计划尽量避开；复盘会展示本周完成率、RPE、训练容量和具体调整预告
- 服务端 Agent 周复盘：训练完成后自动更新首页的完成率、强度和下周行动建议，并可通过后台审计工具轨迹
- App Action Agent：用户说“明天没空/打开计划/开始训练/改目标”，Agent 生成操作卡，确认后在 App 内执行，而不是只给文字建议
- 体型照片分析：拍照获取训练重点，应用到计划；不做体脂/医疗诊断
- 饮食照片识别：拍照估算食物、热量与三大营养素，可改份量/勾选后加入今日饮食
- 饮食记录不限制“健康食物”：内置螺蛳粉、火锅、奶茶等常见外食，也可以手动添加任意食物并复用
- 器械 Tab：按肌群/器械筛选动作，左下角「已选动作」气泡可生成自选训练或批量加入器械库；支持全量搜索和拍照识别；右上角保留器械库管理
- 计划按周推进：首页和提醒进入当前计划周，4 周结束后可生成下一阶段
- 计划版本历史：重新生成或 AI 调整后保留旧版本，可查看和恢复
- 训练保护：0 组不落记录、支持撤销上一组、参考上次重量/次数
- 训练数据：训练月历、日容量、动作历史、动作容量趋势、历史最佳组（PR）与训练心得
- 后台数据管理系统：用户、计划、训练、对话、识别、动作库与操作审计
- 动作库已收敛为 80 个常用健身房/铁馆动作，以固定器械、绳索和自由重量核心动作为主；不保留宽握/窄握、上斜/下斜、单臂/交替等变式
- 企业级登录：手机验证码、账号密码、微信/QQ OAuth、自动注册、忘记密码、修改密码、JWT + Refresh Token、会话撤销
- 器械拍照/选图 → 识别候选（本地 Mock / 远程视觉）→ 动作卡片与视频播放
- 饮食计划（本地热量与三餐模板 + 食物库/自定义食物记录）→ 美团跳转占位
- Apple 健康：读取体重、写入完成的训练
- FitAI Pro 订阅页（StoreKit 2，商品 ID 占位）
- 设置每周训练日与提醒时间 → 本地通知
- 档案与训练记录本地持久化

**明确还没做的：** 真实视觉模型、教学视频素材（播放链路已接）、Apple 登录、App Store 订阅商品配置（订阅页已接）、Apple Watch、美团联盟接入、备案材料。

---

## 目录结构

```
FitAI/
├── README.md
├── docs/                    # 产品、架构、合规、路线图
├── preview/                 # Windows 可运行的 Web 界面预览
├── db/schema.sql            # PostgreSQL + pgvector 建表脚本
├── backend/                 # FastAPI 服务（Windows 可直接跑）
│   ├── app/
│   │   ├── main.py
│   │   ├── models.py
│   │   ├── routers/         # profile / plans / workouts / coach / equipment / diet
│   │   ├── services/        # LLM 网关、计划生成、校验、问答、识别
│   │   └── prompts/         # 系统提示词
│   ├── requirements.txt
│   ├── docker-compose.yml
│   └── .env.example
└── ios/                     # SwiftUI 工程
    ├── project.yml          # XcodeGen 配置
    └── FitAI/
        ├── App/
        ├── Core/            # 模型、数据、服务、设计系统
        ├── Features/        # Onboarding / Home / Plan / Workout / Coach / Equipment / Profile
        └── Resources/
```

CI：推送到 GitHub 后，`.github/workflows/ios-build.yml` 会在 macOS runner 上编译 iOS 工程，`.github/workflows/backend-tests.yml` 会跑后端测试。这样即使本地只有 Windows，也能先发现编译错误。

### 分支策略

- `develop`：日常开发集成分支
- `testing`：测试/验收分支，只从 `develop` 合并
- `main`：生产分支，只从 `testing` 合并并在发布时打 tag
- `feature/*` / `hotfix/*`：功能与紧急修复分支

完整流程见 [分支与发布流程](docs/25-branch-strategy.md)。

---

## 快速开始（Windows，先跑后端）

```powershell
cd E:\Projects\FitAI\backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
uvicorn app.main:app --reload
```

打开 <http://127.0.0.1:8000/docs> 查看接口。

### 数据管理后台

后台已统一到 Spring Boot + Vue，不再使用 FastAPI 内置页面：

```text
admin-web/       Vue3 + TypeScript + Element Plus
admin-server/    Spring Boot 3 + JWT/RBAC + Flyway
deploy/admin/    MySQL 8 + admin-server + Nginx
```

本地开发地址：<http://127.0.0.1:5173/admin/>。首次启动管理员由
`FITAI_BOOTSTRAP_USERNAME` / `FITAI_BOOTSTRAP_PASSWORD` 注入；创建后请关闭
`FITAI_BOOTSTRAP_ENABLED`。FastAPI 的 `/admin` 与 `/api/v1/admin/*` 已删除。

后台当前支持：

- 数据概览：用户、活跃、训练、计划、AI 对话、安全拦截、器械识别、动作库、饮食计划
- 用户管理：搜索、查看档案/目标/计划/训练/对话/识别/饮食/AI 任务、软注销、恢复、彻底删除、导出 JSON
- 计划与排期：计划详情、归档、设为当前计划；查看跨设备排期、跳过记录与最后写入时间
- 训练记录：逐组详情、删除
- AI 对话：查看消息、安全拦截筛选、删除
- 器械识别：候选结果、置信度、删除
- 动作库：编辑动作说明、器械和禁忌症
- 教学视频：上传视频/封面、绑定动作、预览、编辑、发布/下架；发布后自动同步到 App 只读接口
- AI 使用：模型配置、调用量、成功率、延迟、Token、失败原因和 Coach Skill 使用情况
- Agent：运行轨迹、计划草案、动作执行结果、撤销与失败审计
- 操作日志：所有后台写操作审计，支持管理员账号与 RBAC

> 视频文件默认保存在 `backend/media/`，Spring 与 FastAPI 共用该目录；生产环境应配置数据盘，或替换为 OSS/COS + CDN。视频发布前需要确认版权/教练授权。

> 注意：饮食记录、身体指标、器械库和训练记录已支持服务端同步；体型照片分析结果、自定义食物和器械照片仍主要存储在 iOS 本地，后台只能读取已经同步到服务端的数据。

### 登录配置

后端默认使用开发短信模式：`POST /auth/phone/send-code` 会返回 `dev_code`，登录页会自动填入。手机号首次验证会自动建号；未知账号使用密码登录不会自动注册，客户端必须先用短信验证手机号，再携带已输入的账号和密码调用 `POST /auth/password/register` 完成注册并静默登录。

`.env` 关键配置：

```ini
JWT_SECRET=请替换为强随机字符串
SMS_PROVIDER=dev
# 或接入短信网关：
# SMS_PROVIDER=webhook
# SMS_WEBHOOK_URL=https://your-sms-gateway.example.com/send

WECHAT_APP_ID=
WECHAT_APP_SECRET=
QQ_APP_ID=
QQ_APP_SECRET=
# 留空时自动使用当前请求域名；生产建议配置公开 HTTPS 域名
OAUTH_CALLBACK_BASE=
```

未配置微信/QQ 密钥时，开发环境会打开模拟授权页验证完整 OAuth 链路；生产环境不会伪造第三方登录。真实一键登录还需要在开放平台配置 AppID、Universal Links/回调，并在 iOS 侧接官方 SDK。

共享 MySQL 8 是当前后台与 App API 的默认数据库：

```powershell
cd deploy/admin
Copy-Item .env.example .env
docker compose up -d mysql
# backend/.env：DATABASE_URL=mysql+pymysql://fitai:fitai@127.0.0.1:3307/fitai?charset=utf8mb4
```

> MySQL schema 由 `admin-server` 的 Flyway 创建；首次启动请先启动 admin-server 或执行 Flyway，再启动 FastAPI。纯 App 本地开发仍可使用 SQLite。

---

## 快速开始（Mac，跑 iOS）

**Windows 无法编译 iOS。** 需要一台 Mac（或云 Mac），安装 Xcode 16+。

```bash
brew install xcodegen
cd ios
xcodegen generate
open FitAI.xcodeproj
```

在 Xcode 的 Signing & Capabilities 里选择你的 Team，然后选模拟器运行。详细步骤见 `docs/08-ios-setup.md`。

App 默认使用本地 Mock 数据，不依赖后端。启动后端后，在 App 的「我的 → AI 服务」打开远程模式，即可切换为真实接口；请求失败会自动回退本地。要在真机上连本地后端，把 `ios/FitAI/Core/Services/AppConfig.swift` 里的 `apiBaseURL` 改成电脑局域网 IP。

---

## Mock 与真实的边界

| 模块 | 现在 | 接真实服务要做什么 |
|---|---|---|
| 计划生成 | 本地规则引擎（按器械/目标/频率编排） | 在「我的 → AI 服务」打开远程模式，或调后端 `POST /plans/generate` |
| AI 教练 | 关键词回复 + 安全话术 | 打开远程模式后走 `/coach/chat`，失败自动回退本地 |
| 器械识别 | 从动作库随机返回候选 | 打开远程模式后走 `/equipment/scan` 多模态识别 |
| 通知 | `UNUserNotificationCenter` 每周重复提醒 | iOS 26+ 接 AlarmKit 做系统级闹钟样式 |
| 登录 | 本地假登录 | Sign in with Apple + 后端 JWT |
| 支付 | 无 | StoreKit 2 订阅 |
| 饮食/外卖 | 占位接口 | 自建食物库；美团联盟 CPS 需企业资质 |

---

## 上架前必须补齐（中国区）

1. 公司主体、App 备案、ICP 备案
2. 生成式 AI 应用/功能登记（调用已备案模型也要登记），并在 App 内公示模型名称与备案号
3. 隐私政策、敏感个人信息单独同意、账号注销、数据导出
4. 教学视频版权授权链
5. 健康免责声明与安全边界
6. Apple 审核：HealthKit、IAP、医疗建议边界、权限文案

完整清单见 `docs/06-compliance-cn.md`。

---

## 建议的下一步

1. 在 Mac 上把工程跑起来，确认交互方向
2. 申请 DeepSeek / 通义 / 豆包任一 API，填到 `backend/.env`，把计划生成切到真实模型
3. 拍摄或采购第一批 30 个动作的教学视频
4. 注册公司主体，启动 App 备案与 AI 登记
5. 用 TestFlight 找 20 个真实用户验证“计划完成率”

---

## 说明

- 本项目是工程骨架，不是可直接上架的成品。AI 生成的代码需要在 Mac 上编译验证。
- 所有健康建议必须经过规则校验与免责声明，不能替代医生诊断。
- 美团外卖的菜单与营养数据没有公开接口，CPS 只能提供活动/跳转链接，详见 `docs/05-ai-design.md` 与 PRD 的“不做清单”。

---

## 企业级管理后台（Vue3 + Spring Boot + MySQL）

FastAPI 内置数据后台已完整迁移并删除；唯一正式后台位于：

- `admin-web/`：Vue3 + TypeScript + Element Plus + Pinia + Vue Router
- `admin-server/`：Spring Boot 3 + Spring Security/JWT + RBAC + Flyway + JdbcClient
- `deploy/admin/`：MySQL 8 + admin-server + Nginx 的 Docker Compose
- `docs/20-admin-enterprise-architecture.md`：架构、权限、数据边界、迁移与发布说明

本机开发：

```powershell
# 只启动 MySQL（127.0.0.1:3307）
cd deploy/admin
docker compose up -d mysql

# Spring Boot（连接 3307；密码与 deploy/admin/.env 一致）
cd ..\..\admin-server
$env:FITAI_DB_URL='jdbc:mysql://127.0.0.1:3307/fitai?useUnicode=true&characterEncoding=utf8&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC'
$env:FITAI_DB_USERNAME='fitai'
$env:FITAI_DB_PASSWORD='<MYSQL_PASSWORD>'
$env:FITAI_JWT_SECRET='<至少 32 字节随机串>'
mvn spring-boot:run

cd ..\admin-web
npm install
npm run dev
```

开发地址：<http://127.0.0.1:5173/admin/>。默认初始管理员由环境变量
`FITAI_BOOTSTRAP_USERNAME` / `FITAI_BOOTSTRAP_PASSWORD` 注入；创建后请关闭
`FITAI_BOOTSTRAP_ENABLED`。

Docker 部署：

```powershell
cd deploy/admin
Copy-Item .env.example .env
# 修改 JWT_SECRET、数据库密码和初始管理员密码
docker compose up -d --build
# 打开 http://localhost:8088/admin/
```

App API 继续由 FastAPI 提供；FastAPI 通过 `DATABASE_URL=mysql+pymysql://...`
连接同一个 MySQL。旧 SQLite 数据用 `tools/db/migrate_sqlite_to_mysql.py` 导入。
