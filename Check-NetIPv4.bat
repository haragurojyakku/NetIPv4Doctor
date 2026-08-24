@echo off
rem NetIPv4Doctor - quick read-only check, no admin rights needed, no changes made.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Check-Ipv4Health.ps1"
pause
