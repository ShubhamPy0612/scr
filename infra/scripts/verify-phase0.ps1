# SCR Phase 0 verification - v0.2.0
# Usage:  powershell -ExecutionPolicy Bypass -File C:\scr\infra\scripts\verify-phase0.ps1
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$domain    = 'p2p.testerapp.in'
$hostnames = @($domain, "rtc.$domain", "turn.$domain")
$failures  = 0

function Test-Step([string]$Name, [scriptblock]$Check) {
    try {
        $ok = [bool](& $Check)
    } catch {
        $ok = $false
        $detail = $_.Exception.Message
    }
    if ($ok) {
        Write-Host "[PASS] $Name" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Name $detail" -ForegroundColor Red
        $script:failures++
    }
}

function Get-RemoteCertificate([string]$HostName) {
    $tcp = New-Object Net.Sockets.TcpClient($HostName, 443)
    try {
        $ssl = New-Object Net.Security.SslStream($tcp.GetStream(), $false, { $true })
        try {
            $ssl.AuthenticateAsClient($HostName)
            New-Object Security.Cryptography.X509Certificates.X509Certificate2($ssl.RemoteCertificate)
        } finally { $ssl.Dispose() }
    } finally { $tcp.Dispose() }
}

Write-Host "--- Docker / Postgres ---"
Test-Step 'Docker engine running' {
    docker info --format '{{.ServerVersion}}' 2>$null | Out-Null
    $LASTEXITCODE -eq 0
}
Test-Step 'scr-postgres container healthy' {
    (docker inspect -f '{{.State.Health.Status}}' scr-postgres 2>$null) -eq 'healthy'
}
Test-Step 'scr_app role exists with search_path=app' {
    (docker exec scr-postgres psql -U scr_app -d scr -tAc 'select current_schema()' 2>$null) -eq 'app'
}
Test-Step 'Postgres bound to 127.0.0.1 only' {
    $bindings = docker port scr-postgres 5432 2>$null
    $bindings -and -not ($bindings | Where-Object { $_ -notmatch '^127\.0\.0\.1:' })
}

Write-Host "--- nginx / TLS ---"
Test-Step 'nginx process running' { Get-Process nginx -ErrorAction Stop }
Test-Step 'nginx config test passes' {
    Push-Location 'C:\krm_doc\nginx-1.30.3'
    try { & .\nginx.exe -t 2>$null; $LASTEXITCODE -eq 0 } finally { Pop-Location }
}
foreach ($h in @($domain, "rtc.$domain")) {
    Test-Step "https://$h/healthz returns 200" {
        (Invoke-WebRequest "https://$h/healthz" -UseBasicParsing -TimeoutSec 10).StatusCode -eq 200
    }
}
foreach ($h in $hostnames) {
    Test-Step "certificate valid for $h (>14 days left)" {
        $cert = Get-RemoteCertificate $h
        $chain = New-Object Security.Cryptography.X509Certificates.X509Chain
        $chain.Build($cert) -and $cert.NotAfter -gt (Get-Date).AddDays(14)
    }
}
Test-Step 'http:// redirects to https://' {
    # PowerShell 5.1 returns the 301; PowerShell 7 throws with the response attached
    try {
        $resp = Invoke-WebRequest "http://$domain/" -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 10 -ErrorAction Stop
    } catch {
        $resp = $_.Exception.Response
        if (-not $resp) { throw }
    }
    $location = if ($resp.Headers.Location) { "$($resp.Headers.Location)" } else { "$($resp.Headers['Location'])" }
    [int]$resp.StatusCode -eq 301 -and $location -like "https://$domain/*"
}

Write-Host "--- Firewall ---"
Test-Step 'SCR firewall rules present (6)' {
    @(Get-NetFirewallRule -DisplayName 'SCR - *' -ErrorAction Stop).Count -eq 6
}

Write-Host ""
if ($failures -eq 0) {
    Write-Host "Phase 0 verified - all checks passed." -ForegroundColor Green
} else {
    Write-Host "$failures check(s) failed." -ForegroundColor Red
    exit 1
}
