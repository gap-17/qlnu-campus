@echo off
chcp 65001 >nul
echo [qlnu] Copying reference photos...
node "%~dp0copy_photos.js"
if errorlevel 1 (
  echo [qlnu] Copy failed. Check the source path in tools\copy_photos.js
) else (
  echo [qlnu] Done.
)
pause