# SCR secret generator - v0.1.0 (Phase 0)
# Usage (from C:\scr):  powershell -ExecutionPolicy Bypass -File infra\scripts\generate-secrets.ps1
# Existing secrets are kept. -Force overwrites them: never use it after the database exists.
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'

$secretsDir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\secrets'))
New-Item -ItemType Directory -Force -Path $secretsDir | Out-Null

function New-RandomHex([int]$ByteCount) {
    $buffer = New-Object byte[] $ByteCount
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($buffer) } finally { $rng.Dispose() }
    -join ($buffer | ForEach-Object { $_.ToString('x2') })
}

$secretNames = @(
    'pg_superuser_password',
    'pg_app_password'
)

foreach ($name in $secretNames) {
    $path = Join-Path $secretsDir "$name.txt"
    if ((Test-Path $path) -and -not $Force) {
        Write-Host "skip    $name (already exists)"
        continue
    }
    # WriteAllText: UTF-8 without BOM and without trailing newline
    [IO.File]::WriteAllText($path, (New-RandomHex 32))
    Write-Host "created $name"
}

# Restrict folder to current user, SYSTEM (S-1-5-18) and Administrators (S-1-5-32-544)
icacls $secretsDir /inheritance:r /grant:r "${env:USERNAME}:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F" | Out-Null

Write-Host ""
Write-Host "Secrets are in $secretsDir - back them up in a password manager."
