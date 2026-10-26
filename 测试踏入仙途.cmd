@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch-game.ps1" -Entry preparation
if errorlevel 1 pause
