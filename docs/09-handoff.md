# 09 · 交付说明与下一步

## 1. 当前完成度

| 模块 | 状态 | 说明 |
|---|---|---|
| 产品文档 | 完成 | PRD、架构、数据模型、API、AI、合规、路线图 |
| 数据库 | 完成 | PostgreSQL + pgvector 建表脚本 |
| 后端 | 可运行 | FastAPI + SQLite/PostgreSQL，AI 默认 Mock |
| 后端测试 | 通过 | 7 个校验器单测 + 端到端 smoke |
| iOS 工程 | 代码完成 | 23 个 Swift 文件，语法检查通过 |
| iOS 编译 | **未验证** | Windows 无法编译，需 Mac 或 GitHub Actions |
| 真实 AI | 未接 | 填 `.env` 即可切换 |
| 教学视频 | 未接 | 需自制或采购授权 |
| 支付/登录 | 未接 | P1 |
| 饮食/外卖 | 占位 | 热量计算可用，美团未配置 |

## 2. 现在就能验证的

### Windows：后端

```powershell
cd E:\Projects\FitAI\backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --reload
```

打开 <http://127.0.0.1:8000/docs>，依次调用：

1. `POST /api/v1/auth/dev-login`
2. `PUT /api/v1/me/profile`
3. `PUT /api/v1/me/goal`
4. `POST /api/v1/plans/generate`
5. `POST /api/v1/coach/chat`，输入“今天练什么？”
6. `POST /api/v1/coach/chat`，输入“胸痛、喘不上气”，应返回 `safety_flag=medical_referral`
7. `POST /api/v1/equipment/scan` 上传一张图片
8. `POST /api/v1/diet/plan`

### Mac：iOS

```bash
brew install xcodegen
cd ios
xcodegen generate
open FitAI.xcodeproj
```

选 Team → 模拟器 → `Cmd + R`。

### GitHub：自动编译

把仓库推到 GitHub 后，`.github/workflows/ios-build.yml` 会自动在 macOS runner 上编译。第一次 push 就能看到真实编译错误，这比等 Mac 到手更快。

## 3. 接真实 DeepSeek

编辑 `backend/.env`：

```ini
LLM_PROVIDER=deepseek
LLM_API_KEY=sk-...
LLM_BASE_URL=https://api.deepseek.com/v1
LLM_MODEL=deepseek-chat
```

> 需要“深度思考/推理”时，把 `LLM_MODEL` 改成 `deepseek-reasoner`。注意：reasoner 更慢、更贵，且对 JSON 输出稳定性要求更高，建议先用 chat 跑通评测集。

重启后端后，`POST /plans/generate` 会走真实模型；失败会自动降级到规则模板，并记录 `ai_jobs.status=fallback`。

## 4. 第一批内容清单（建议 30 个动作）

优先级从高到低：

1. 深蹲、高脚杯深蹲、腿举、罗马尼亚硬拉、箭步蹲
2. 卧推、哑铃卧推、俯卧撑、绳索夹胸
3. 高位下拉、坐姿划船、杠铃划船、单臂哑铃划船、引体向上
4. 哑铃推举、侧平举、面拉
5. 臀推、臀桥
6. 弯举、绳索下压
7. 平板支撑、卷腹、悬垂举腿
8. 划船机、跑步机、波比跳

每个动作需要：

- 15–30 秒竖屏视频（正面 + 侧面）
- 3 张关键帧（起点、最低点、终点）
- 一句常见错误提示
- 授权文件（自制声明或采购合同）

## 5. 合规启动顺序

1. 注册公司主体
2. 注册 Apple Developer（公司账号要 D-U-N-S，预留 2 周）
3. 域名 + ICP 备案
4. App 备案（工信部）
5. 生成式 AI 应用/功能登记（属地网信办）
6. 隐私政策、用户协议、敏感个人信息单独同意
7. 教学视频授权链
8. 提审

详细清单：`docs/06-compliance-cn.md`。

## 6. 已知缺口（按优先级）

| 优先级 | 缺口 | 影响 |
|---|---|---|
| P0 | iOS 未编译验证 | 可能有类型错误，必须先用 Mac/CI 跑一次 |
| P0 | 真实模型未评测 | 计划合法率、伤病禁忌未用真实输出验证 |
| P0 | 视频版权未解决 | 不能上线教学视频 |
| P1 | 通知未在真机验证 | AlarmKit/静音模式行为未知 |
| P1 | 无登录与订阅 | 无法商业化 |
| P1 | 无 HealthKit | 少一个数据入口 |
| P2 | 美团未接 | 不影响核心闭环 |
| P2 | 无 Apple Watch | 体验增强，非必须 |

## 7. 接下来 7 天建议

- Day 1：把仓库推到 GitHub，跑通 iOS CI；修编译错误
- Day 2：在 Mac/云 Mac 上真机跑一遍完整闭环
- Day 3：申请 DeepSeek API，跑 100 组计划评测
- Day 4：拍 5 个动作的样片，确认视频风格与成本
- Day 5：注册公司/开发者账号，启动备案
- Day 6：找 5 个真实用户试用，记录卡点
- Day 7：根据反馈砍功能，锁定 v0.2 范围

## 8. 验收标准（v0.2）

- [ ] iOS 在 GitHub Actions 上编译通过
- [ ] 真机完成一次建档 → 生成 → 训练 → 记录 → 调整
- [ ] 通知在锁屏状态按时触发
- [ ] 100 组计划生成 JSON 合法率 ≥95%，禁忌动作 0
- [ ] 40 条红旗症状 100% 触发安全兜底
- [ ] 器械识别 Top-3 命中率 ≥85%
- [ ] 隐私政策、免责声明、注销入口可用
- [ ] 至少 5 位真实用户完成首次训练
