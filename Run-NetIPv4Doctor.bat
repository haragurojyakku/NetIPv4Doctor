@echo off
rem NetIPv4Doctor - detect and try to auto-fix an IPv4-over-IPv6 tunnel outage.
rem Requests admin rights (one UAC prompt) so it can restart the network adapter
rem if the lighter fixes don't work. Never restarts the PC.
setlocal
set SCRIPT_DIR=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -NoExit -File \"%SCRIPT_DIR%Fix-Ipv4Tunnel.ps1\"'"
endlocal
