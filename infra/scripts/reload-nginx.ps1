# SCR nginx reload - v0.2.0 (Phase 0)
# Tests the WHOLE config first; only reloads if the test passes, so other sites keep running.
# Reload is graceful: no dropped connections. Also usable as the win-acme installation script.
param(
    [string]$NginxDir = 'C:\krm_doc\nginx-1.30.3'
)
$ErrorActionPreference = 'Stop'

Push-Location $NginxDir
try {
    & .\nginx.exe -t
    if ($LASTEXITCODE -ne 0) { throw 'nginx config test failed - NOT reloading, running config unchanged' }
    & .\nginx.exe -s reload
    if ($LASTEXITCODE -ne 0) { throw 'nginx reload failed' }
    Write-Host 'nginx reloaded'
}
finally {
    Pop-Location
}
