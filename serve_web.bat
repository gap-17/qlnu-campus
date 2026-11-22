@echo off
setlocal
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo [qlnu] Node.js not found. Install Node.js 18+ or use any static server.
  echo        For example: python -m http.server 5174 --directory game\build\web
  pause
  exit /b 1
)
node "game\scripts\serve_web.js" %1
echo.
pause