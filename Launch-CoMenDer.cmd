@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-CoMenDer.ps1"
if errorlevel 1 (
  echo.
  echo CoMenDer could not start. Extract the complete ZIP and try again.
  pause
)
endlocal
