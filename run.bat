@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ddtank_farm.ps1" -Manual %*
