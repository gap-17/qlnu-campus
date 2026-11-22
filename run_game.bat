@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\godot_task.ps1" -Task run
set "CODE=%ERRORLEVEL%"
if not "%CODE%"=="0" (
  echo.
  echo [qlnu] Godot exited with code %CODE%.
  pause
)
exit /b %CODE%