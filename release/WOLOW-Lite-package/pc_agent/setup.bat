@echo off
setlocal EnableExtensions
title WOLOW Agent Setup

set "TASK_NAME=WOLOW Agent"
set "AGENT_DIR=%~dp0"
set "AGENT_SCRIPT=%AGENT_DIR%agent.py"

echo.
echo  ============================================
echo   WOLOW Agent - Background Service Setup
echo  ============================================
echo.

net session >nul 2>&1
if errorlevel 1 (
    echo  [!] Run this file as Administrator.
    exit /b 1
)

echo  [1/4] Checking Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo  [!] Python is not installed or is not available on PATH.
    echo      Install Python, select "Add Python to PATH", then run setup again.
    exit /b 1
)

for /f "usebackq delims=" %%P in (`python -c "import sys; print(sys.executable)" 2^>nul`) do set "PYTHON_EXE=%%P"
if not defined PYTHON_EXE (
    echo  [!] Could not determine the Python executable.
    exit /b 1
)
for %%P in ("%PYTHON_EXE%") do set "PYTHON_DIR=%%~dpP"
set "PYTHONW_EXE=%PYTHON_DIR%pythonw.exe"
if not exist "%PYTHONW_EXE%" set "PYTHONW_EXE=%PYTHON_EXE%"

echo  [2/4] Installing agent dependencies...
"%PYTHON_EXE%" -m pip install -r "%AGENT_DIR%requirements.txt" --quiet
if errorlevel 1 (
    echo  [!] Dependency installation failed.
    exit /b 1
)

echo  [3/4] Ensuring agent configuration exists...
if not exist "%AGENT_DIR%config.yaml" (
    "%PYTHON_EXE%" "%AGENT_DIR%generate_token.py"
    if errorlevel 1 exit /b 1
) else (
    echo       Existing config.yaml kept.
)

echo  [4/4] Registering one boot-start task and starting it...
"%PYTHON_EXE%" "%AGENT_DIR%install_task.py" --task-name "%TASK_NAME%" --python "%PYTHONW_EXE%" --agent "%AGENT_SCRIPT%"
if errorlevel 1 (
    echo  [!] Failed to register the WOLOW Agent task.
    exit /b 1
)

schtasks /run /tn "%TASK_NAME%" >nul
if errorlevel 1 (
    echo  [!] The task was registered but could not be started. Check Task Scheduler history.
    exit /b 1
)

echo.
echo  Setup complete. The agent runs silently at every Windows boot.
echo  Logs: %AGENT_DIR%wolow-agent.log
exit /b 0
