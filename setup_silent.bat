@echo off
setlocal EnableExtensions

:: Check admin
net session >nul 2>&1
if errorlevel 1 (
    echo Run this file as Administrator.
    pause
    exit /b 1
)

:: Run the actual setup hidden via VBS
echo Set WshShell = CreateObject("WScript.Shell") > "%TEMP%\wolow_setup.vbs"
echo WshShell.Run "cmd /c ""%~dp0pc_agent\setup.bat""", 0, True >> "%TEMP%\wolow_setup.vbs"
wscript.exe "%TEMP%\wolow_setup.vbs"
del "%TEMP%\wolow_setup.vbs" >nul 2>&1

echo Setup complete. Agent is running silently.
exit /b 0
