# NetIPv4Doctor - Quick check (no remediation, no admin rights needed).
# Double-click Check-NetIPv4.bat, or run:  powershell -ExecutionPolicy Bypass -File Check-Ipv4Health.ps1

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'Ipv4HealthCore.ps1')

$result = Test-Ipv4Health

Write-Host ""
Write-Host "=== NetIPv4Doctor : IPv4接続チェック ===" -ForegroundColor Cyan
Write-Host ("実行時刻        : {0}" -f $result.Time)
Write-Host ("IPv4 TCP接続    : {0}" -f $(if ($result.Tcp4)  { 'OK' } else { 'NG' }))
Write-Host ("IPv4 ping(ICMP) : {0}" -f $(if ($result.Icmp4) { 'OK' } else { 'NG' }))
Write-Host ("IPv6 TCP接続    : {0}" -f $(if ($result.Tcp6)  { 'OK' } else { 'NG' }))
Write-Host ""

switch ($result.Status) {
    'OK' {
        Write-Host "状態: 正常です。IPv4接続に問題は見つかりませんでした。" -ForegroundColor Green
    }
    'IPV4_TUNNEL_DOWN' {
        Write-Host "状態: IPv4 over IPv6(MAP-E系: v6プラス/transix/OCNバーチャルコネクト等)の" -ForegroundColor Yellow
        Write-Host "      トンネル障害の可能性が高いです。" -ForegroundColor Yellow
        Write-Host "      (pingは通るのにTCP接続だけ失敗 = ルーター側のIPv4セッション異常でよくある症状)"
        Write-Host "      Run-NetIPv4Doctor.bat を実行すると自動修復を試み、ダメならルーター再起動を案内します。"
    }
    'FULL_OUTAGE' {
        Write-Host "状態: IPv4・IPv6ともに通信不可です。回線自体の障害の可能性があります。" -ForegroundColor Red
        Write-Host "      ルーター/ONU、または回線契約(ISP)側の状態を確認してください。"
    }
    default {
        Write-Host "状態: 判定不能な組み合わせです(部分的な障害)。手動で確認してください。" -ForegroundColor Red
    }
}
Write-Host ""
