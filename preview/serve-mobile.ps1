$port = 5174
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$listening = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue

if (-not $listening) {
    Start-Process -FilePath "python" `
        -ArgumentList "-m", "http.server", $port, "--bind", "0.0.0.0" `
        -WorkingDirectory $root `
        -WindowStyle Hidden
    Start-Sleep -Seconds 1
}

$ips = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.254.*" -and
        $_.InterfaceAlias -notmatch "VMware|vEthernet|Loopback"
    } |
    Select-Object -ExpandProperty IPAddress -Unique

Write-Host ""
Write-Host "FitAI 手机预览已启动" -ForegroundColor Green
Write-Host "手机和电脑需要连接同一个 Wi-Fi。" -ForegroundColor Yellow
Write-Host ""
Write-Host "在 iPhone Safari 打开："
foreach ($ip in $ips) {
    Write-Host "  http://${ip}:${port}/" -ForegroundColor Cyan
}
Write-Host ""
Write-Host "如果手机打不开："
Write-Host "  1. 确认电脑与 iPhone 在同一 Wi-Fi"
Write-Host "  2. Windows 防火墙允许 Python 访问专用网络"
Write-Host "  3. 关闭 VPN / 访客网络隔离后再试"
Write-Host ""

Start-Process "http://127.0.0.1:$port/"
