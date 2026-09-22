@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0.artifacts\social-relations-v27\tools\play_social_relations.ps1" %*
if errorlevel 1 pause
