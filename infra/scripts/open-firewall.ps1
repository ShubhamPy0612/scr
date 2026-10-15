# SCR Windows Firewall rules - v0.1.0 (Phase 0)
# Usage (admin PowerShell):  powershell -ExecutionPolicy Bypass -File C:\scr\infra\scripts\open-firewall.ps1
#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

$rules = @(
    @{ Name = 'SCR - HTTP/HTTPS (nginx)';      Protocol = 'TCP'; Ports = @('80', '443') },
    @{ Name = 'SCR - LiveKit ICE TCP';         Protocol = 'TCP'; Ports = @('7881') },
    @{ Name = 'SCR - LiveKit ICE UDP';         Protocol = 'UDP'; Ports = @('7882') },
    @{ Name = 'SCR - TURN UDP';                Protocol = 'UDP'; Ports = @('3478') },
    @{ Name = 'SCR - TURN TLS';                Protocol = 'TCP'; Ports = @('5349') },
    @{ Name = 'SCR - TURN relay UDP';          Protocol = 'UDP'; Ports = @('30000-30049') }
)

foreach ($rule in $rules) {
    Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    New-NetFirewallRule -DisplayName $rule.Name -Direction Inbound -Action Allow `
        -Protocol $rule.Protocol -LocalPort $rule.Ports -Profile Any | Out-Null
    Write-Host ("opened  {0,-30} {1} {2}" -f $rule.Name, $rule.Protocol, ($rule.Ports -join ','))
}

Write-Host ""
Write-Host "Forward the same ports on your router to this server's LAN IP."
