@echo off
setlocal EnableExtensions
set "TASK_NAME=WOLOW Agent"

net session >nul 2>&1
if errorlevel 1 (
    echo  [!] Run this file as Administrator.
    exit /b 1
)

:: Stop and delete scheduled task
schtasks /end /tn "%TASK_NAME%" >nul 2>&1
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

:: Kill any running agent processes (pythonw running agent.py)
for /f "tokens=2" %%P in ('tasklist /fi "imagename eq pythonw.exe" /fo csv /nh 2^>nul ^| findstr /i "pythonw"') do (
    wmic process where "ProcessId=%%~P and CommandLine like '%%agent.py%%'" delete >nul 2>&1
)

echo WOLOW Agent stopped and removed.
exit /b 0
