#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

function Ensure-FirewallRule {
    param([string]$Name, [int]$Port, [string]$Protocol)
    if (-not (Get-NetFirewallRule -DisplayName $Name -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $Name -Direction Inbound -LocalPort $Port -Protocol $Protocol -Action Allow | Out-Null
    }
}

Enable-PSRemoting -Force -SkipNetworkProfileCheck
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM
Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force
winrm set winrm/config/service '@{AllowUnencrypted="true"}' | Out-Null
Ensure-FirewallRule -Name 'WOLOW WinRM' -Port 5985 -Protocol TCP
Ensure-FirewallRule -Name 'WOLOW Agent HTTP' -Port 8220 -Protocol TCP
Ensure-FirewallRule -Name 'WOLOW Agent UDP' -Port 8221 -Protocol UDP
Write-Host 'WinRM and WOLOW firewall rules are configured.'
