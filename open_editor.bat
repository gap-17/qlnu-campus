@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\godot_task.ps1" -Task editor
exit /b %ERRORLEVEL%