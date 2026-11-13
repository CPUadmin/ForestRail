@echo off
chcp 65001 >nul
cd /d "%~dp0.."
echo Снимаю кадры всех машин и депо (около минуты).
echo.
python tools\visual_audit.py
if not errorlevel 1 start "" "qa\visual_audit_latest"
pause
