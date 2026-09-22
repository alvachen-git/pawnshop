@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\play_v27.ps1" %*
set "GAME_EXIT=%ERRORLEVEL%"
if not "%GAME_EXIT%"=="0" pause
exit /b %GAME_EXIT%
