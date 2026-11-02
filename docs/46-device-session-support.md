# 46 · 设备会话兼容与客服处理

## 1. 设备标识来源

- iOS 端 `DeviceIdentity.current` 优先使用 `identifierForVendor`，取不到时使用
  `UserDefaults` 里的安装 UUID。
- 所有需要登录态的请求都带 `X-Device-ID`；刷新和登录接口同样带上。
- 设备 ID 只用于会话绑定，不是用户 ID，也不展示给用户。

## 2. 服务端兼容策略

| 场景 | 行为 |
|---|---|
| 旧客户端完全不传 `X-Device-ID` | 兼容放行，不因缺少设备头拒绝刷新 |
| 会话有设备 ID，请求设备 ID 一致 | 正常轮换 refresh token，滑动延长 30 天 |
| 会话有设备 ID，请求设备 ID 不同 | 撤销该会话，返回 401，写 `refresh_device_mismatch` 事件 |
| 同一设备重新登录 | 撤销该设备旧会话，只保留最新一个 |
| 单账号超过 5 个活跃设备 | 撤销最久未使用的一个会话 |
| 多账号共用设备、异常批量登录 | 写 `auth_events` 告警，不直接封禁 |

对应实现：`backend/app/services/auth.py`，迁移 `V15/V16`。

## 3. 客户端换机/重装

- 换机或重装后 `identifierForVendor` 会变化，旧会话仍可能占用设备名额，
  直到过期或被下一次登录挤出。
- 刷新返回 401/403 时，`TokenRefreshCoordinator` 会清除本地 token 并发出
  `.fitaiSessionExpired` 事件，`RootView` 收到后回到登录页，提示
  “登录已失效，请重新登录”。
- 网络错误、5xx、超时不清理本地会话，避免离线时被误登出。
- 本地未同步的训练记录仍保留在 App 沙盒；重新登录后会走现有的待同步队列，
  不会因为会话失效而删除。

## 4. 客服撤销设备会话

当前后台还没有单独的“设备会话”页面（见交接文档 P3，UI 属于待办）。
客服/运维可通过管理员数据库执行最小范围撤销：

```sql
-- 只撤销一个用户的所有活跃会话
UPDATE auth_sessions
SET revoked_at = UTC_TIMESTAMP()
WHERE user_id = '<user_id>' AND revoked_at IS NULL;

-- 核对撤销结果
SELECT id, device_id, created_at, last_used_at, revoked_at
FROM auth_sessions
WHERE user_id = '<user_id>'
ORDER BY created_at DESC;
```

注意：

- 不要删除 `auth_sessions` 行，保留审计与复用检测记录。
- 操作前确认用户身份；该操作会让所有设备重新登录。
- 若需要后台按钮，后续在 admin-server 增加 `POST /users/{id}/sessions/revoke`，
  写 `USER_SESSIONS_REVOKED` 审计日志，并在 admin-web 用户详情页提供入口。
- 调查异常登录时优先查 `auth_events` 的 `refresh_reuse`、
  `refresh_device_mismatch`、`anomaly_multi_account` 事件。
