# NetIPv4Doctor - IPv4 health-check core functions.
# Detects the "ping (ICMPv4) succeeds but TCP over IPv4 fails, while IPv6 TCP
# works fine" signature typical of a broken IPv4-over-IPv6 (MAP-E / v6プラス /
# transix / OCNバーチャルコネクト style) tunnel session on the router side.
# This file only defines functions; dot-source it, it has no side effects on load.

function Test-TcpEndpoint {
    param(
        [Parameter(Mandatory)][string]$IpAddress,
        [Parameter(Mandatory)][int]$Port,
        [int]$TimeoutMs = 4000
    )
    # TcpClient's parameterless constructor eagerly creates an IPv4-only socket
    # (.NET Framework quirk) - connecting it to an IPv6 literal fails outright,
    # not a timeout. Parse the address and build the client with the matching
    # family, then connect via the IPAddress overload (skips DNS entirely too).
    $ip = [System.Net.IPAddress]::Parse($IpAddress)
    $client = New-Object System.Net.Sockets.TcpClient($ip.AddressFamily)
    try {
        $iar = $client.BeginConnect($ip, $Port, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs)
        if (-not $ok) { return $false }
        $client.EndConnect($iar)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Test-Ipv4Health {
    # Literal IPs on purpose: forces the address family and avoids DNS/Happy-Eyeballs
    # ambiguity, so the IPv4 and IPv6 results are directly comparable.
    $ipv4Targets = @('1.1.1.1', '8.8.8.8')
    $ipv6Targets = @('2606:4700:4700::1111', '2001:4860:4860::8888')

    $tcp4 = $false
    foreach ($t in $ipv4Targets) {
        if (Test-TcpEndpoint -IpAddress $t -Port 443) { $tcp4 = $true; break }
    }

    $tcp6 = $false
    foreach ($t in $ipv6Targets) {
        if (Test-TcpEndpoint -IpAddress $t -Port 443) { $tcp6 = $true; break }
    }

    $icmp4 = $false
    try {
        $icmp4 = [bool](Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)
    } catch {
        $icmp4 = $false
    }

    $status =
        if ($tcp4) { 'OK' }
        elseif ($icmp4 -and $tcp6) { 'IPV4_TUNNEL_DOWN' }
        elseif (-not $icmp4 -and -not $tcp6) { 'FULL_OUTAGE' }
        else { 'UNKNOWN' }

    [PSCustomObject]@{
        Status = $status
        Tcp4   = $tcp4
        Tcp6   = $tcp6
        Icmp4  = $icmp4
        Time   = Get-Date
    }
}

function Test-IsAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}
