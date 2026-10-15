# Phase 0 — Infrastructure (v0.1.0)

Goal: Postgres running in Docker (localhost only), nginx on the Windows host serving HTTPS
for `p2p.testerapp.in` and `rtc.p2p.testerapp.in`, one TLS certificate covering all three
hostnames with auto-renewal, and all ports opened.

Run every command in **PowerShell as Administrator** on the server.

Fixed locations used throughout the project:

| Path | What |
|---|---|
| `C:\scr` | this git repo |
| `C:\nginx` | nginx for Windows |
| `C:\nginx\acme` | ACME challenge webroot |
| `C:\certs` | TLS certificate (PEM files) |
| `C:\tools\win-acme` | win-acme |

---

## Step 1 — Prerequisites and repo

1. Install **Git for Windows** if missing.
2. Docker Desktop (WSL2) running → Settings → General → enable **Start Docker Desktop when you sign in**.
3. Clone:
   ```powershell
   git clone https://github.com/ShubhamPy0612/scr.git C:\scr
   cd C:\scr
   git checkout claude/charming-mendel-3w9kd8
   ```

> Docker Desktop only runs while a user is signed in. So the containers come back after a
> reboot, set up auto sign-in with Sysinternals **Autologon**, and lock the session afterwards.

## Step 2 — Firewall and router

```powershell
powershell -ExecutionPolicy Bypass -File C:\scr\infra\scripts\open-firewall.ps1
```

Forward these ports on the router to the server's LAN IP:

| Port | Protocol | Purpose | Used from |
|---|---|---|---|
| 80 | TCP | HTTP → HTTPS redirect, certificate validation | Phase 0 |
| 443 | TCP | HTTPS (web, API, WebSocket, LiveKit signaling) | Phase 0 |
| 7881 | TCP | LiveKit media over TCP (fallback) | Phase 4 |
| 7882 | UDP | LiveKit media (main) | Phase 4 |
| 3478 | UDP | TURN | Phase 4 |
| 5349 | TCP | TURN over TLS | Phase 4 |
| 30000–30049 | UDP | TURN relay | Phase 4 |

## Step 3 — Secrets

```powershell
cd C:\scr
powershell -ExecutionPolicy Bypass -File infra\scripts\generate-secrets.ps1
```

This creates `infra\secrets\pg_superuser_password.txt` and `pg_app_password.txt`.
Save both in a password manager.

## Step 4 — Start Postgres

```powershell
cd C:\scr\infra
Copy-Item .env.example .env
docker compose up -d
docker compose ps
```

Wait until `scr-postgres` shows `(healthy)`, then check the init script ran:

```powershell
docker logs scr-postgres 2>&1 | Select-String "scr: app role"
```

> The init script only runs when the `scr-pgdata` volume is empty. To start over, run
> `docker compose down -v`. **This deletes all data.**

Optional, for DB admin with pgAdmin/DBeaver on the server: host `127.0.0.1`, port `5432`,
user `postgres`, password from `pg_superuser_password.txt`.

## Step 5 — nginx (bootstrap, HTTP only)

1. Download the **Stable** nginx/Windows zip (1.28.x or newer) from https://nginx.org/en/download.html
   and extract so that `C:\nginx\nginx.exe` exists.
2. Create folders and copy the bootstrap config:
   ```powershell
   New-Item -ItemType Directory -Force C:\nginx\acme, C:\certs | Out-Null
   Copy-Item C:\scr\infra\nginx\nginx-bootstrap.conf C:\nginx\conf\
   cd C:\nginx
   .\nginx.exe -t -c conf/nginx-bootstrap.conf
   Start-Process .\nginx.exe -ArgumentList '-c', 'conf/nginx-bootstrap.conf' -WorkingDirectory C:\nginx
   ```
3. From your phone on **mobile data** (not Wi-Fi), open `http://p2p.testerapp.in`. You should be
   redirected to `https://...`. That page won't load yet, and that's expected: it proves port 80 is reachable.

## Step 6 — TLS certificate (win-acme, one certificate for all 3 names)

1. Download the latest win-acme **x64 pluggable** zip from https://www.win-acme.com and extract to `C:\tools\win-acme`.
2. Run (replace the email):
   ```powershell
   cd C:\tools\win-acme
   .\wacs.exe --source manual `
     --host p2p.testerapp.in,rtc.p2p.testerapp.in,turn.p2p.testerapp.in `
     --validation filesystem --webroot "C:\nginx\acme" `
     --store pemfiles --pemfilespath "C:\certs" --pemfilesname scr `
     --installation script --script "C:\scr\infra\scripts\reload-nginx.ps1" `
     --emailaddress YOUR_EMAIL --accepttos
   ```
3. Check that `C:\certs\scr-chain.pem` and `C:\certs\scr-key.pem` exist.
4. win-acme creates a **scheduled task** that renews the certificate automatically and runs `reload-nginx.ps1`.
   Confirm it exists: Task Scheduler → `win-acme renew`.

If the command-line flags fail on your win-acme version, run `.\wacs.exe` with no arguments
and choose: `M` (full options) → manual input → enter the 3 hostnames → HTTP validation →
"Save verification files on (network) path" → `C:\nginx\acme` → store: PEM encoded files →
`C:\certs` (name `scr`) → installation: "Start external script" → `C:\scr\infra\scripts\reload-nginx.ps1`.

## Step 7 — nginx (final config, as a Windows service)

1. Stop the bootstrap nginx and install the real config:
   ```powershell
   cd C:\nginx
   .\nginx.exe -s quit
   Copy-Item C:\scr\infra\nginx\nginx.conf C:\nginx\conf\nginx.conf -Force
   .\nginx.exe -t
   ```
2. Install the service with **WinSW v2.12.0**: download `WinSW-x64.exe` from
   https://github.com/winsw/winsw/releases/tag/v2.12.0, save it as `C:\nginx\nginx-service.exe`, then:
   ```powershell
   Copy-Item C:\scr\infra\nginx\winsw\nginx-service.xml C:\nginx\nginx-service.xml
   cd C:\nginx
   .\nginx-service.exe install
   .\nginx-service.exe start
   Get-Service nginx
   ```

From now on, after changing anything in `C:\scr\infra\nginx\sites` or `snippets`, apply it with:
`powershell -ExecutionPolicy Bypass -File C:\scr\infra\scripts\reload-nginx.ps1`

## Step 8 — Verify

```powershell
powershell -ExecutionPolicy Bypass -File C:\scr\infra\scripts\verify-phase0.ps1
```

All checks should be `[PASS]`. Then, from your phone on mobile data:

- `https://p2p.testerapp.in` → "SCR - Phase 0 OK" page, padlock valid
- `https://rtc.p2p.testerapp.in/healthz` → `ok`
- `https://p2p.testerapp.in/api/` → `502 Bad Gateway` (expected: the backend arrives in Phase 1)

## Done when

- [ ] `verify-phase0.ps1` passes all checks
- [ ] Placeholder page loads over HTTPS from outside your network
- [ ] Secrets backed up in a password manager
- [ ] Router forwards all ports in the table above
