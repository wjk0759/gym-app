@echo off
chcp 65001 >nul
title 叫练 Mobile Preview
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve-mobile.ps1"
pause
