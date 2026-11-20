# 中国区备案站点

这个目录放的是 ICP 备案用的静态站点和 Nginx 配置，不包含 App 后端。

## 文件

- `site/index.html`：叫练介绍、联系方式、隐私/支持入口
- `site/privacy.html`：隐私政策
- `site/support.html`：支持与联系我们
- `nginx.conf`：Nginx 站点模板，`__DOMAIN__` 会在部署时替换
- `deploy-site.ps1`：Windows 一键上传并配置 Nginx

## 前置条件

1. 大陆 ECS 已购买，安全组放行 22/80/443
2. 域名已实名，A 记录指向 ECS 公网 IP
3. 本机 SSH 公钥已加入 ECS 的 `root` 用户
4. 已申请阿里云“备案服务号”

## 部署

```powershell
cd deploy\cn
.\deploy-site.ps1 -Server <ECS公网IP> -Domain <域名>
```

例如：

```powershell
.\deploy-site.ps1 -Server 1.2.3.4 -Domain jiaolianfit.cn
```

如果使用非 root 用户或自定义私钥：

```powershell
.\deploy-site.ps1 -Server 1.2.3.4 -Domain jiaolianfit.cn -User root -Key C:\Users\Administrator\.ssh\id_ed25519
```

## 部署后检查

```bash
curl -I http://<域名>/
curl -I http://<域名>/privacy
curl -I http://<域名>/support
```

三个地址都应返回 `200`。

## ICP 备案

部署完成后，在阿里云备案控制台提交：

- 主办单位性质：个体工商户
- 主办单位名称：营业执照名称
- 网站名称：叫练
- 服务内容：生活服务 / 健康健身 / 其他
- 域名、服务器 IP、备案服务号
- 上传营业执照、经营者身份证、域名证书、真实性核验单
- 阿里云 App 人脸核验

ICP 通过后，把 `index.html` 底部的“ICP 备案号：备案通过后填写”替换为真实备案号，并链接到 `https://beian.miit.gov.cn/`。
