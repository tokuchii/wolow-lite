@echo off
setlocal EnableExtensions

:: Check admin
net session >nul 2>&1
if errorlevel 1 (
    echo Run this file as Administrator.
    pause
    exit /b 1
)

:: Run setup silently via VBS
echo Set WshShell = CreateObject("WScript.Shell") > "%TEMP%\wolow_setup.vbs"
echo WshShell.Run "cmd /c ""%~dp0pc_agent\setup.bat""", 0, True >> "%TEMP%\wolow_setup.vbs"
wscript.exe "%TEMP%\wolow_setup.vbs"
del "%TEMP%\wolow_setup.vbs" >nul 2>&1

echo.
echo  ============================================
echo   Setup Complete! Agent is running silently.
echo  ============================================
echo.
echo  NEXT STEPS:
echo  1. Open the WOLOW app on your phone
echo  2. Tap "Scan Network" to auto-detect this PC
echo  3. Your phone can now control PC audio, volume, and more!
echo.
exit /b 0
