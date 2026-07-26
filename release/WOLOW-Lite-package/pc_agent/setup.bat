@echo off
setlocal EnableExtensions
title WOLOW Agent Setup

set "TASK_NAME=WOLOW Agent"
set "AGENT_DIR=%~dp0"
set "AGENT_SCRIPT=%AGENT_DIR%agent.py"

echo.
echo  ============================================
echo   WOLOW Lite - Agent Setup
echo  ============================================
echo.

net session >nul 2>&1
if errorlevel 1 (
    echo  [!] Run this file as Administrator.
    exit /b 1
)

echo  [1/5] Checking Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo  [!] Python is not installed or is not available on PATH.
    echo      Install Python from https://www.python.org/downloads/
    echo      Select "Add Python to PATH" during install, then run setup again.
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

echo  [2/5] Checking svcl.exe...
if not exist "%AGENT_DIR%svcl.exe" (
    echo  [!] svcl.exe not found in %AGENT_DIR%
    echo      Download from https://www.nirsoft.net/utils/sound_volume_command_line.html
    echo      Place svcl.exe next to agent.py, then run setup again.
    exit /b 1
)
echo       svcl.exe found.

echo  [3/5] Installing agent dependencies...
"%PYTHON_EXE%" -m pip install -r "%AGENT_DIR%requirements.txt" --quiet
if errorlevel 1 (
    echo  [!] Dependency installation failed.
    exit /b 1
)

echo  [4/5] Generating authentication token...
if not exist "%AGENT_DIR%config.yaml" (
    "%PYTHON_EXE%" "%AGENT_DIR%generate_token.py"
    if errorlevel 1 exit /b 1
) else (
    echo       Existing config.yaml kept.
)

echo  [5/5] Registering agent as background service...
"%PYTHON_EXE%" "%AGENT_DIR%install_task.py" --task-name "%TASK_NAME%" --python "%PYTHONW_EXE%" --agent "%AGENT_SCRIPT%"
if errorlevel 1 (
    echo  [!] Failed to register the WOLOW Agent task.
    exit /b 1
)

schtasks /run /tn "%TASK_NAME%" >nul
if errorlevel 1 (
    echo  [!] The task was registered but could not be started.
    exit /b 1
)

echo.
echo  ============================================
echo   Setup Complete!
echo  ============================================
echo.
echo  The WOLOW agent is now running on port 8220.
echo.
echo  NEXT STEPS:
echo  1. Open the WOLOW app on your phone
echo  2. Enter your PC's IP address (find it in Settings ^> Network)
echo  3. Enter the token shown above during setup
echo  4. Your phone can now control PC audio, volume, and more!
echo.
echo  Token shown above during config generation.
echo  Logs: %AGENT_DIR%wolow-agent.log
echo  Stop: stop-agent.bat (run as Administrator)
echo.
exit /b 0
