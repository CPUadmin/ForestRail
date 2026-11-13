@echo off
chcp 65001 >nul
cd /d "%~dp0.."
echo Собираю пробную версию из последнего коммита (5-10 минут). Устанавливать и выпускать не буду.
echo.
python tools\build_trial.py
echo.
if errorlevel 1 (echo ИТОГ: сборка с ошибками, напиши Claude.) else (echo ИТОГ: сборка готова, папка release\trial.)
pause
