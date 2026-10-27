# 25 · 分支与发布流程

> 2026-10-27 · 将开发、测试、生产拆成三条长期分支，避免功能代码直接进入生产。

## 1. 分支职责

| 分支 | 角色 | 谁可以写入 | 来源 | 合并目标 |
|---|---|---|---|---|
| `develop` | 开发集成分支 | 日常功能分支、修复分支 | `main` 或当前 `develop` | `testing` |
| `testing` | 测试/验收分支 | 只接受 `develop` 的合并或快进 | `develop` | `main` |
| `main` | 生产分支 | 只接受 `testing` 的发布合并 | `testing` | 无，发布后打 tag |
| `feature/*` | 单个功能 | 功能开发者 | `develop` | `develop` |
| `hotfix/*` | 线上紧急修复 | 维护者 | `main` | `main`，再回到 `develop` |

当前 `ios-web-parity` 作为已有功能分支保留，后续新功能不再从它继续开分支；功能验证完成后合入 `develop`，再删除该功能分支。

## 2. 标准流程

```text
feature/xxx
    │  PR / 本地验证
    ▼
develop ──► testing ──► main
    ▲          │        │
    └──────────┴────────┘
        hotfix 修复回流
```

1. 从 `develop` 创建 `feature/<short-name>`。
2. 功能完成并通过本地测试后合入 `develop`。
3. `develop` 通过 Backend Tests / Admin CI / iOS Build 后合入 `testing`。
4. 测试环境/真机验收通过后，从 `testing` 合入 `main`。
5. `main` 发布时打版本 tag，例如 `v0.2.0`。

### 发布前检查

- [ ] `develop` 和 `testing` 的 CI 全绿
- [ ] FastAPI Smoke 通过
- [ ] iOS 模拟器/真机验收通过
- [ ] 后端数据库迁移脚本已在测试库执行
- [ ] `main` 合并后重新跑一次 CI
- [ ] 发布 tag 与 App 版本号一致

### 紧急修复

```text
hotfix/<issue> ──► main ──► develop ──► testing
```

线上问题修复必须先回到 `main`，再同步回 `develop` 和 `testing`，避免下个版本重新引入。

## 3. 环境对应

| 分支 | 环境 | 用途 |
|---|---|---|
| `develop` | Windows 本地 + Mac 预览 | 日常开发、联调、DeepSeek/Agent 验证 |
| `testing` | 测试服务器/TestFlight（后续） | QA、真机验收、回归测试 |
| `main` | 生产环境（后续） | 正式 API、生产 MySQL、App Store 包 |

> 目前真实测试服务器、生产 MySQL、HTTPS 域名和 App Store 分发尚未部署；上表是分支与目标环境的约定。

## 4. 保护规则

- `testing` 和 `main` 禁止直接提交，只接受来自下级的合并。
- 合并到 `testing` 前至少通过一次完整 CI；合并到 `main` 前必须有测试验收记录。
- 不在分支中提交 `.env`、密钥、生产数据库或真实用户数据。
- 生产发布使用 tag；回滚时优先回滚到上一个 tag，而不是强推 `main`。
- 分支名统一小写，功能分支使用 `feature/`、修复分支使用 `fix/` 或 `hotfix/`。

## 5. 当前状态

| 分支 | 说明 |
|---|---|
| `develop` | 当前开发基线，包含 Agent 周复盘、训练同步与最新 iOS 动效 |
| `testing` | 从当前 `develop` 初始化的测试基线 |
| `main` | 生产基线暂保持旧版本，等待 `testing` 验收后合并 |
| `ios-web-parity` | 历史功能分支，保留到下一次清理 |
