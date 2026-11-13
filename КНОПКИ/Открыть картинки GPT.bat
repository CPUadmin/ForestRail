@echo off
chcp 65001 >nul
cd /d "%~dp0.."
start "" "tools\art_sources\inbox"
start "" "tools\art_sources\ART_QUEUE.md"
