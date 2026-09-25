@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\play_unified.ps1" -Scene res://scenes/start_pawn_v45.tscn %*
