# NetIPv4Doctor - Detect + attempt automatic remediation of the
# "IPv4-over-IPv6 tunnel down" signature (ping OK / IPv4 TCP NG / IPv6 TCP OK).
# Never reboots the PC. Only restarts the network adapter, and only when
# already running elevated. Falls back to guiding the user to reboot the
# router when PC-side remediation doesn't help.
#
# Run via Run-NetIPv4Doctor.bat (recommended - it requests admin rights),
# or manually: powershell -ExecutionPolicy Bypass -File Fix-Ipv4Tunnel.ps1

param(
    [switch]$NoOpenRouterPage,
    [switch]$Silent  # for scheduled/unattended runs: no browser popup, no MessageBox (log file only)
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'Ipv4HealthCore.ps1')

$logDir = Join-Path $here 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir 'netipv4doctor.log'

function Write-Log {
    param([string]$Message, [string]$Color = 'Gray')
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Write-Host $line -ForegroundColor $Color
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

Write-Log "=== 診断開始 ===" 'Cyan'
$result = Test-Ipv4Health
Write-Log ("状態: {0} (IPv4-TCP={1}, ICMPv4={2}, IPv6-TCP={3})" -f $result.Status, $result.Tcp4, $result.Icmp4, $result.Tcp6)

if ($result.Status -eq 'OK') {
    Write-Log "IPv4は正常です。対応不要です。" 'Green'
    exit 0
}

if ($result.Status -ne 'IPV4_TUNNEL_DOWN') {
    Write-Log "既知のパターン(IPv4 over IPv6トンネル障害)とは一致しません。自動修復は行いません。手動で確認してください。" 'Red'
    exit 1
}

Write-Log "IPv4 over IPv6トンネル障害の兆候を検知しました。自動修復を試みます。" 'Yellow'

# Step 1: flush DNS cache.
Write-Log "手順1/3: DNSキャッシュをクリア"
ipconfig /flushdns | Out-Null

# Step 2: release/renew the active adapter's IPv4 lease.
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
if ($adapter) {
    Write-Log ("手順2/3: アダプタ '{0}' のIPv4リースを再取得" -f $adapter.Name)
    ipconfig /release "$($adapter.Name)" | Out-Null
    ipconfig /renew "$($adapter.Name)" | Out-Null
}

Start-Sleep -Seconds 2
$result = Test-Ipv4Health
Write-Log ("再検査: 状態={0}" -f $result.Status)

if ($result.Status -eq 'OK') {
    Write-Log "DNSクリア+リース再取得で復旧しました。" 'Green'
    exit 0
}

# Step 3: restart the network adapter (admin only - a router/WAN-side tunnel
# issue is expected to survive this, but it's cheap and safe to try).
if ((Test-IsAdmin) -and $adapter) {
    Write-Log ("手順3/3: アダプタ '{0}' を再起動(管理者権限あり)" -f $adapter.Name)
    try {
        Restart-NetAdapter -Name $adapter.Name -Confirm:$false
        Start-Sleep -Seconds 5
    } catch {
        Write-Log ("アダプタ再起動に失敗: {0}" -f $_.Exception.Message) 'Red'
    }
    $result = Test-Ipv4Health
    Write-Log ("再検査: 状態={0}" -f $result.Status)
    if ($result.Status -eq 'OK') {
        Write-Log "アダプタ再起動で復旧しました。" 'Green'
        exit 0
    }
} else {
    Write-Log "手順3/3: 管理者権限がないためアダプタ再起動はスキップ(Run-NetIPv4Doctor.batから実行すると管理者権限で動きます)" 'Yellow'
}

# Step 4: PC-side remediation exhausted - this needs a router/ONU reboot.
$gateway = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty NextHop

Write-Log "PC側の対応では復旧しませんでした。ルーター/ホームゲートウェイの再起動が必要です。" 'Red'
if ($gateway) {
    Write-Log ("ルーター管理画面: http://{0}" -f $gateway)
    if (-not $NoOpenRouterPage -and -not $Silent) {
        Start-Process ("http://{0}" -f $gateway)
    }
}

if (-not $Silent) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $msg = "インターネット(IPv4)接続の問題を検知しましたが、PC側の自動修復では解決しませんでした。`n`nルーター(ホームゲートウェイ)本体の電源を入れ直してください。"
        if ($gateway) { $msg += "`n`n管理画面を開きました: http://$gateway" }
        [System.Windows.Forms.MessageBox]::Show(
            $msg,
            'NetIPv4Doctor - ルーター再起動が必要です',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
    } catch {
        # GUI not available (e.g. non-interactive session) - the console/log message above still stands.
    }
}

exit 2
