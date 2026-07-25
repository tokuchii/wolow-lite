@echo off
setlocal EnableExtensions
set "TASK_NAME=WOLOW Agent"

net session >nul 2>&1
if errorlevel 1 (
    echo  [!] Run this file as Administrator.
    exit /b 1
)

schtasks /end /tn "%TASK_NAME%" >nul 2>&1
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
echo WOLOW Agent task stopped and removed.
echo No unrelated Python processes were terminated.
exit /b 0
