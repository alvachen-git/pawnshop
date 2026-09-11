@echo off
set "APPDATA=%~dp0.artifacts\bedroom-review\appdata"
if not exist "%APPDATA%" mkdir "%APPDATA%"
"%~dp0.tools\godot-4.6.1\Godot_v4.6.1-stable_win64.exe" --path "%~dp0." --script res://tests/bedroom_mirror_ui_smoke.gd -- interactive
