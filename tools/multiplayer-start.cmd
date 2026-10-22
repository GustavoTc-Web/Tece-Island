@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0manage-multiplayer-pilot.ps1" -Action Start -PublishEndpoint
pause
