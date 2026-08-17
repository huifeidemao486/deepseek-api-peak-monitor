@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deepseek_peak_monitor.ps1" -Selftest
echo.
pause
