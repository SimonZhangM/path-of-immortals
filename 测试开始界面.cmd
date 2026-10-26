@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch-game.ps1" -Entry start
if errorlevel 1 pause
