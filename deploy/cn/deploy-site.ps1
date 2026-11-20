param(
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [Parameter(Mandatory = $true)]
    [string]$Domain,

    [string]$User = "root",
    [string]$Key = "$HOME\.ssh\id_ed25519",
    [string]$RemoteRoot = "/var/www/jiaolian"
)

$ErrorActionPreference = "Stop"

$siteDir = Join-Path $PSScriptRoot "site"
$remoteTmp = "/tmp/jiaolian-site"
$target = "$User@$Server"
$serverNames = if ($Domain.StartsWith("www.")) { $Domain } else { "$Domain www.$Domain" }

Write-Host "==> Uploading site to $target"
ssh -i $Key $target "rm -rf $remoteTmp && mkdir -p $remoteTmp"
Get-ChildItem -LiteralPath $siteDir -File | ForEach-Object {
    scp -i $Key $_.FullName "${target}:${remoteTmp}/"
}

Write-Host "==> Installing nginx and publishing files"
ssh -i $Key $target "if ! command -v nginx >/dev/null 2>&1; then if command -v dnf >/dev/null 2>&1; then dnf install -y nginx; else yum install -y nginx; fi; fi"
ssh -i $Key $target "mkdir -p $RemoteRoot && cp -r $remoteTmp/* $RemoteRoot/"

Write-Host "==> Writing nginx site config"
$nginx = Get-Content (Join-Path $PSScriptRoot "nginx.conf") -Raw
$nginx = $nginx.Replace("__DOMAIN__", $serverNames)
$nginx | ssh -i $Key $target "cat > /etc/nginx/conf.d/jiaolian.conf"

Write-Host "==> Testing and reloading nginx"
ssh -i $Key $target "nginx -t && systemctl enable --now nginx && systemctl reload nginx"
ssh -i $Key $target "if systemctl is-active --quiet firewalld; then firewall-cmd --permanent --add-service=http >/dev/null; firewall-cmd --permanent --add-service=https >/dev/null; firewall-cmd --reload >/dev/null; fi"

Write-Host "==> Verifying local response"
ssh -i $Key $target "curl -sS -o /dev/null -w 'index=%{http_code}\n' -H 'Host: $Domain' http://127.0.0.1/; curl -sS -o /dev/null -w 'privacy=%{http_code}\n' -H 'Host: $Domain' http://127.0.0.1/privacy; curl -sS -o /dev/null -w 'support=%{http_code}\n' -H 'Host: $Domain' http://127.0.0.1/support"

Write-Host "==> Done. Make sure Aliyun security group allows 80/443 and DNS points to this server."
