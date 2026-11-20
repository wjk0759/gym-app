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

Write-Host "==> Uploading site to $target"
ssh -i $Key $target "rm -rf $remoteTmp && mkdir -p $remoteTmp"
Get-ChildItem -LiteralPath $siteDir -File | ForEach-Object {
    scp -i $Key $_.FullName "${target}:${remoteTmp}/"
}

Write-Host "==> Installing nginx and publishing files"
ssh -i $Key $target @"
set -e
if ! command -v nginx >/dev/null 2>&1; then
  if command -v dnf >/dev/null 2>&1; then dnf install -y nginx; else yum install -y nginx; fi
fi
mkdir -p $RemoteRoot
cp -r $remoteTmp/* $RemoteRoot/
"@

Write-Host "==> Writing nginx site config"
$nginx = Get-Content (Join-Path $PSScriptRoot "nginx.conf") -Raw
$nginx = $nginx.Replace("__DOMAIN__", $Domain)
$nginx | ssh -i $Key $target "cat > /etc/nginx/conf.d/jiaolian.conf"

Write-Host "==> Testing and reloading nginx"
ssh -i $Key $target @"
set -e
nginx -t
systemctl enable --now nginx
systemctl reload nginx
if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-service=http >/dev/null
  firewall-cmd --permanent --add-service=https >/dev/null
  firewall-cmd --reload >/dev/null
fi
"@

Write-Host "==> Done. Open http://$Domain"
