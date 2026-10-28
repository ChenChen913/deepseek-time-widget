@echo off
rem Fallback launcher for systems where VBScript is unavailable.
start "" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0DeepSeekClock.ps1"
