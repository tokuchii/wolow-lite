#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'

function Ensure-FirewallRule {
    param([string]$Name, [int]$Port, [string]$Protocol)
    if (-not (Get-NetFirewallRule -DisplayName $Name -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $Name -Direction Inbound -LocalPort $Port -Protocol $Protocol -Action Allow | Out-Null
    }
}

# WinRM is optional — agent uses Flask on port 8220, not WinRM
try {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Set-Service -Name WinRM -StartupType Automatic
    Start-Service -Name WinRM
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force
    winrm set winrm/config/service '@{AllowUnencrypted="true"}' | Out-Null
    Write-Host 'WinRM configured.'
} catch {
    Write-Host 'WinRM skipped (network is Public). Agent will still work via HTTP on port 8220.'
}

# Firewall rules are required for the agent
Ensure-FirewallRule -Name 'WOLOW Agent HTTP' -Port 8220 -Protocol TCP
Ensure-FirewallRule -Name 'WOLOW Agent UDP' -Port 8221 -Protocol UDP
Write-Host 'Firewall rules configured for WOLOW agent.'
