# WOLOW Lite - WinRM + Agent Setup Script
# Run this ONCE on the target PC (as Administrator)
# Enables Windows Remote Management and installs the WOLOW agent

#Requires -RunAsAdministrator

Write-Host ""
Write-Host "WOLOW Lite - Enabling WinRM..." -ForegroundColor Cyan
Write-Host ""

# Enable PowerShell Remoting (also enables WinRM)
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Allow connections from any IP (for LAN use)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Configure WinRM to allow unencrypted connections (for simplicity)
# Note: For production use, you should configure HTTPS
winrm set winrm/config/service '@{AllowUnencrypted="true"}'

# Set service to auto-start
Set-Service -Name WinRM -StartupType Automatic

# Open firewall port
New-NetFirewallRule -DisplayName "WOLOW WinRM" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Done! WinRM is enabled." -ForegroundColor Green

# --- Agent Setup ---
Write-Host ""
Write-Host "Setting up WOLOW Agent..." -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AgentDir = Join-Path $ScriptDir "pc_agent"

if (Test-Path $AgentDir) {
    # Check Python
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        # Install dependencies
        Write-Host "  Installing agent dependencies..." -ForegroundColor Gray
        pip install -r "$AgentDir\requirements.txt" --quiet 2>$null

        # Generate token (only if missing)
        if (-not (Test-Path "$AgentDir\config.yaml")) {
            Write-Host "  Generating authentication token..." -ForegroundColor Gray
            python "$AgentDir\generate_token.py"
        } else {
            Write-Host "  Config already exists, keeping existing token." -ForegroundColor Gray
        }

        # Register auto-start task
        Write-Host "  Registering auto-start task..." -ForegroundColor Gray
        schtasks /create /tn "WOLOW Agent" /tr "pythonw $AgentDir\agent.py" /sc onlogon /rl highest /f 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Agent will auto-start on login." -ForegroundColor Gray
        } else {
            Write-Host "  Warning: Could not create auto-start task." -ForegroundColor Yellow
        }

        # Open firewall ports for agent
        Write-Host "  Opening firewall ports for agent..." -ForegroundColor Gray
        New-NetFirewallRule -DisplayName "WOLOW Agent HTTP" -Direction Inbound -LocalPort 8220 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName "WOLOW Agent UDP" -Direction Inbound -LocalPort 8221 -Protocol UDP -Action Allow -ErrorAction SilentlyContinue

        # Start agent now
        Write-Host "  Starting WOLOW agent..." -ForegroundColor Gray
        Start-Process -WindowStyle Hidden -FilePath "pythonw" -ArgumentList "$AgentDir\agent.py"
        Write-Host "  Agent started." -ForegroundColor Gray
    } else {
        Write-Host "  [!] Python not found. Install Python and run this script again." -ForegroundColor Yellow
        Write-Host "  Download: https://www.python.org/downloads/" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [!] pc_agent/ directory not found. Skipping agent setup." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Your PC is now ready for WOLOW commands." -ForegroundColor Cyan
Write-Host "In the app, enter your PC's IP address as the Agent." -ForegroundColor Cyan
Write-Host ""
Write-Host "To disable later, run: Disable-PSRemoting -Force" -ForegroundColor DarkGray
Write-Host ""
