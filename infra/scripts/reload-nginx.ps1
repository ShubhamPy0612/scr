# SCR nginx reload - v0.1.0 (Phase 0). Called by win-acme after each certificate renewal.
$ErrorActionPreference = 'Stop'

Push-Location 'C:\nginx'
try {
    & .\nginx.exe -t
    if ($LASTEXITCODE -ne 0) { throw 'nginx config test failed - not reloading' }
    & .\nginx.exe -s reload
    if ($LASTEXITCODE -ne 0) { throw 'nginx reload failed' }
    Write-Host 'nginx reloaded'
}
finally {
    Pop-Location
}
