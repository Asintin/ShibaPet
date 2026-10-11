@echo off
chcp 65001 >nul
title Shiba Pet
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0shiba.ps1"
