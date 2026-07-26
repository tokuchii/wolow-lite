@echo off
setlocal EnableExtensions
title WOLOW Lite Setup

echo.
echo  ============================================
echo   WOLOW Lite - PC Setup
echo  ============================================
echo.

net session >nul 2>&1
if errorlevel 1 (
    echo  [!] Run this file as Administrator.
    exit /b 1
)

echo  [1/2] Configuring firewall rules...
rem WinRM is optional — agent uses Flask on port 8220, not WinRM
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_winrm.ps1"
rem Continue even if WinRM setup had issues — agent works via HTTP

echo  [2/2] Installing the background agent...
call "%~dp0pc_agent\setup.bat"
if errorlevel 1 exit /b 1

echo.
echo  Setup complete.
exit /b 0
