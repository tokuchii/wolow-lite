@echo off
title WOLOW Agent Setup
color 0F
echo.
echo  ============================================
echo   WOLOW Agent - One-Click Setup
echo  ============================================
echo.

:: Check admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] Right-click this file and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

:: Check Python
echo  [1/5] Checking Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] Python is not installed or not in PATH.
    echo.
    echo  Download Python: https://www.python.org/downloads/
    echo  IMPORTANT: Check "Add Python to PATH" during install.
    echo.
    pause
    exit /b 1
)
python --version
echo.

:: Install dependencies
echo  [2/5] Installing dependencies...
pip install -r requirements.txt --quiet 2>nul
if %errorlevel% neq 0 (
    echo  [!] Failed to install dependencies. Try running as Administrator.
    pause
    exit /b 1
)
echo       Done.
echo.

:: Generate token
echo  [3/5] Generating authentication token...
python generate_token.py
if %errorlevel% neq 0 (
    echo  [!] Failed to generate token.
    pause
    exit /b 1
)
echo.

:: Register auto-start (at system boot, not on login)
echo  [4/5] Registering auto-start task...
schtasks /create /tn "WOLOW Agent" /tr "pythonw agent.py" /sc onstart /rl highest /f >nul 2>&1
if %errorlevel% equ 0 (
    echo       Agent will auto-start on boot.
) else (
    echo       Warning: Could not create auto-start task.
    echo       Agent may need to be started manually after reboot.
)
echo.

:: Done
echo  [5/5] Setup complete!
echo.
echo  ============================================
echo.
echo  Starting WOLOW agent now...
echo  It will auto-start on boot.
echo  Press Ctrl+C to stop (you can close this window).
echo.
echo  ============================================
echo.

python agent.py
