@echo off

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\play_unified.ps1" %*

exit /b %errorlevel%
