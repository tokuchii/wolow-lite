@echo off
title WOLOW Lite Setup
color 0F
echo.
echo  ============================================
echo   WOLOW Lite - PC Setup
echo  ============================================
echo.
echo  This will enable remote control for your PC.
echo  Run this ONCE as Administrator.
echo.

:: Check admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] Right-click this file and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo  [1/6] Enabling PowerShell Remoting...
powershell -Command "Enable-PSRemoting -Force" >nul 2>&1
echo       Done.

echo  [2/6] Configuring WinRM...
powershell -Command "winrm set winrm/config/service '@{AllowUnencrypted=\"true\"}'" >nul 2>&1
powershell -Command "winrm set winrm/config/service/auth '@{Basic=\"true\"}'" >nul 2>&1
powershell -Command "Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force" >nul 2>&1
echo       Done.

echo  [3/6] Opening firewall ports...
powershell -Command "New-NetFirewallRule -DisplayName 'WOLOW WinRM' -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue" >nul 2>&1
powershell -Command "New-NetFirewallRule -DisplayName 'WOLOW RDP' -Direction Inbound -LocalPort 3389 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue" >nul 2>&1
powershell -Command "New-NetFirewallRule -DisplayName 'WOLOW SMB' -Direction Inbound -LocalPort 445 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue" >nul 2>&1
powershell -Command "New-NetFirewallRule -DisplayName 'WOLOW RPC' -Direction Inbound -LocalPort 135 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue" >nul 2>&1
echo       Done.

echo  [4/6] Starting WinRM service...
powershell -Command "Set-Service -Name WinRM -StartupType Automatic; Start-Service WinRM" >nul 2>&1
echo       Done.

echo  [5/6] Testing connection...
powershell -Command "Test-WSMan -ComputerName localhost" >nul 2>&1
if %errorlevel% equ 0 (
    echo       WinRM is working!
) else (
    echo       Warning: WinRM test failed. Try restarting your PC.
)

echo.
echo  [6/6] Setting up WOLOW Agent...
echo.

:: Check Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] Python is not installed or not in PATH.
    echo.
    echo  Download Python: https://www.python.org/downloads/
    echo  IMPORTANT: Check "Add Python to PATH" during install.
    echo.
    echo  Skipping agent setup. Run pc_agent\setup.bat manually after installing Python.
    goto :done
)
echo       Python found.

:: Install dependencies
echo       Installing agent dependencies...
pip install -r pc_agent\requirements.txt --quiet 2>nul
if %errorlevel% neq 0 (
    echo  [!] Failed to install agent dependencies.
    echo  Try: cd pc_agent ^&^& setup.bat
    goto :done
)
echo       Dependencies installed.

:: Generate token (only if config.yaml missing)
if not exist "pc_agent\config.yaml" (
    echo       Generating authentication token...
    python pc_agent\generate_token.py
    echo.
) else (
    echo       Config already exists, keeping existing token.
)

:: Register auto-start
echo       Registering auto-start task...
schtasks /create /tn "WOLOW Agent" /tr "pythonw pc_agent\agent.py" /sc onlogon /rl highest /f >nul 2>&1
if %errorlevel% equ 0 (
    echo       Agent will auto-start on login.
) else (
    echo       Warning: Could not create auto-start task.
    echo       Agent may need to be started manually after reboot.
)

:: Open firewall ports for agent
echo       Opening firewall ports for agent...
powershell -Command "New-NetFirewallRule -DisplayName 'WOLOW Agent HTTP' -Direction Inbound -LocalPort 8220 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue" >nul 2>&1
powershell -Command "New-NetFirewallRule -DisplayName 'WOLOW Agent UDP' -Direction Inbound -LocalPort 8221 -Protocol UDP -Action Allow -ErrorAction SilentlyContinue" >nul 2>&1
echo       Done.

:: Start agent
echo.
echo       Starting WOLOW agent...
start "" /b pythonw pc_agent\agent.py
echo       Agent started.

:done
echo.
echo  ============================================
echo   Setup complete!
echo  ============================================
echo.
echo  If buttons still don't work, try:
echo   1. Restart your PC
echo   2. Check if antivirus is blocking port 5985
echo   3. Run this file again as Administrator
echo.
pause
