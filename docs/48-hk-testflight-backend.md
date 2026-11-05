# 叫练 TestFlight 香港后端部署

> 用途：TestFlight 外部内测的临时生产后端。香港地域，不需要 ICP。
> 正式中国区上线仍要迁回大陆服务器，并完成 ICP 备案、App 备案、AI 登记等。

## 1. 服务器

```text
地域：中国香港
公网 IP：8.218.205.149
私网 IP：172.30.49.167
系统：Ubuntu 22.04.5 LTS
规格：2 核 4G / 40G ESSD
Docker：29.9.3
Docker Compose：v5.7.0
```

登录：仅 SSH 密钥，密码登录已关闭。

## 2. 域名

```text
hk-api.jiaolianfit.cn → 8.218.205.149
```

- 域名 `jiaolianfit.cn` 已在阿里云注册并实名。
- DNS 解析在阿里云云解析。
- HTTPS 证书由 Caddy 自动申请、自动续期。

## 3. 目录

```text
/opt/fitai
├── docker-compose.yml
├── Caddyfile
├── .env                 # 生产环境变量，权限 600，不入库
├── backend/             # FastAPI 代码 + data
├── media/               # 动作图片/视频，挂载到 /app/media
├── admin/               # fitai-admin-server.jar，仅用于 Flyway 迁移
└── migration/           # V1–V21 SQL 备份
```

## 4. 服务

| 容器 | 镜像 | 说明 |
|---|---|---|
| `fitai-db` | mysql:8.4 | 仅 Docker 内网，不映射 3306 |
| `fitai-api` | 本地构建 | FastAPI，2 worker，内网 8000 |
| `fitai-caddy` | caddy:2-alpine | 80/443，HTTPS 反代到 api:8000 |

MySQL 表由 admin-server 的 Flyway 管理，V1–V21 已全部执行成功。

## 5. 地址

```text
API：https://hk-api.jiaolianfit.cn/api/v1
健康检查：https://hk-api.jiaolianfit.cn/health
就绪检查：https://hk-api.jiaolianfit.cn/health/ready
隐私政策：https://hk-api.jiaolianfit.cn/privacy
支持页：https://hk-api.jiaolianfit.cn/support
```

iOS Release 的 `FITAI_API_BASE_URL` 已指向：

```text
https://hk-api.jiaolianfit.cn/api/v1
```

## 6. 常用命令

```bash
cd /opt/fitai

# 状态
docker compose ps

# 日志
docker logs -f fitai-api
docker logs -f fitai-caddy
docker logs -f fitai-db

# 重启
docker compose restart api
docker compose restart caddy

# 重建 API
docker compose build api
docker compose up -d api

# 健康检查
curl -fsS https://hk-api.jiaolianfit.cn/health
curl -fsS https://hk-api.jiaolianfit.cn/health/ready
```

## 7. 更新后端

从 Windows 重新打包并上传 `backend.tar.gz` 后：

```bash
cd /opt/fitai
tar -xzf backend.tar.gz -C backend
docker compose build api
docker compose up -d api
```

如果新增了 Flyway 迁移，先用新 jar 跑一次迁移，再重建 API。

## 8. 安全

- 安全组只开放：22、80、443。
- 不开放：3306、8000、6379。
- MySQL 只在 Docker 网络内可访问。
- `.env` 权限 600，包含 JWT、DeepSeek Key、MySQL 密码。
- SSH 仅密钥登录。
- Caddy 的 admin API 只监听容器内 localhost:2019，未映射到公网。

## 9. 当前未配置

- App Store Server API Key / Issuer / p8
- App Store Server Notifications V2
- 阿里云短信认证 AccessKey / 赠送签名 / 模板 CODE（代码已支持 `aliyun_pnvs`，当前仍为 `dev`）
- 管理后台 admin-web
- 生产 MySQL 备份任务

配置完成前，TestFlight 登录请使用 **Sign in with Apple** 或账号密码。手机号验证码暂不可用。

## 9.1 App Review 测试账号

```text
账号：test_reviewer
登录方式：账号密码
密码：不写入仓库，保存在 Windows 桌面「叫练-TestFlight测试账号.txt」
```

- `is_test=true`，不含真实用户数据。
- 首次登录需要完成建档。
- 正式上线前删除该账号或修改密码。

## 9.2 阿里云短信认证（PNVS）

代码已支持 `SMS_PROVIDER=aliyun_pnvs`，使用号码认证服务的「短信认证」：

- 个人实名可用，不需要企业资质。
- 不需要自己申请签名和模板，必须使用控制台的「赠送签名 + 赠送模板」，两者不可混用。
- 仅支持中国大陆手机号。
- 验证码仍由叫练生成并校验，PNVS 只负责发送。

需要配置：

```env
SMS_PROVIDER=aliyun_pnvs
ALIYUN_PNVS_ACCESS_KEY_ID=
ALIYUN_PNVS_ACCESS_KEY_SECRET=
ALIYUN_PNVS_SIGN_NAME=
ALIYUN_PNVS_TEMPLATE_CODE=
```

RAM 用户建议只授予 `AliyunDypnsFullAccess`。配置后：

```bash
cd /opt/fitai
docker compose restart api
```

然后用真实手机号调用 `/api/v1/auth/phone/send-code` 验证。

## 10. 额度提醒

免费试用页面显示有效期到 2027-02-05，但按小时额度大约只够 2C4G 跑 40 天左右。  
需要在小红书外测前确认余额/续费，避免测试中途停机。

## 11. 迁移到大陆时的改动

- 大陆服务器部署同一套 Docker Compose。
- `hk-api` 保留为测试环境，正式环境用 `api.jiaolianfit.cn`。
- 迁移 MySQL 数据、`media` 目录。
- 更新 `PUBLIC_BASE_URL`、iOS `FITAI_API_BASE_URL`、App Store Notifications URL。
- 切换 DNS 前把 TTL 调低，香港服务器保留 7–14 天回滚。
