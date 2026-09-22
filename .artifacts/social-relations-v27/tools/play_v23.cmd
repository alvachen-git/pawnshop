@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0play_v23.ps1" %*
exit /b %errorlevel%
