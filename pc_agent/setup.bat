@echo off
setlocal EnableExtensions

set "TASK_NAME=WOLOW Agent"
set "AGENT_DIR=%~dp0"
set "AGENT_SCRIPT=%AGENT_DIR%agent.py"

net session >nul 2>&1
if errorlevel 1 (
    echo  [!] Run this file as Administrator.
    exit /b 1
)

:: Get Python path
for /f "usebackq delims=" %%P in (`python -c "import sys; print(sys.executable)" 2^>nul`) do set "PYTHON_EXE=%%P"
if not defined PYTHON_EXE (
    echo  [!] Python not found.
    exit /b 1
)
for %%P in ("%PYTHON_EXE%") do set "PYTHON_DIR=%%~dpP"
set "PYTHONW_EXE=%PYTHON_DIR%pythonw.exe"
if not exist "%PYTHONW_EXE%" set "PYTHONW_EXE=%PYTHON_EXE%"

:: Firewall
netsh advfirewall firewall delete rule name="WOLOW Agent HTTP" >nul 2>&1
netsh advfirewall firewall delete rule name="WOLOW Agent UDP" >nul 2>&1
netsh advfirewall firewall add rule name="WOLOW Agent HTTP" dir=in action=allow protocol=tcp localport=8220 >nul 2>&1
netsh advfirewall firewall add rule name="WOLOW Agent UDP" dir=in action=allow protocol=udp localport=8221 >nul 2>&1

:: Install deps
"%PYTHON_EXE%" -m pip install -r "%AGENT_DIR%requirements.txt" --quiet 2>nul

:: Generate token if missing
if not exist "%AGENT_DIR%config.yaml" "%PYTHON_EXE%" "%AGENT_DIR%generate_token.py"

:: Register task
"%PYTHON_EXE%" "%AGENT_DIR%install_task.py" --task-name "%TASK_NAME%" --python "%PYTHONW_EXE%" --agent "%AGENT_SCRIPT%"

:: Start task
schtasks /run /tn "%TASK_NAME%" >nul 2>&1

exit /b 0
