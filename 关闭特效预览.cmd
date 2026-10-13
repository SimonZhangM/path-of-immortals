@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\spine-preview\stop.ps1"
if errorlevel 1 pause
