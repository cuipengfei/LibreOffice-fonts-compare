@echo off
setlocal

:: Set the path to the PowerShell script
set scriptPath=%~dp0generate-font-comparison.ps1

:: Run the PowerShell script
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%scriptPath%"

endlocal