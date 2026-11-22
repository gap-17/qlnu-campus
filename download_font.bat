@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\download_font.ps1"
echo.
pause
exit /b %ERRORLEVEL%