@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\play_unified.ps1" -Scene "res://scenes/porcelain_v42.tscn" %*
