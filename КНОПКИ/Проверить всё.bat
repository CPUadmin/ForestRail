@echo off
chcp 65001 >nul
cd /d "%~dp0.."
echo Проверяю игру: все наборы тестов по одному (около 40 минут). Можно свернуть окно.
echo.
python tools\run_all_checks.py
echo.
if errorlevel 1 (echo ИТОГ: есть красные наборы, напиши Claude.) else (echo ИТОГ: всё зелёное.)
pause
