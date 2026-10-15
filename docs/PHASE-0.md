# Phase 0 — Infrastructure (v0.3.0)

Goal: Postgres running in Docker (localhost only), and your **existing** nginx serving HTTPS for
`p2p.testerapp.in` and `rtc.p2p.testerapp.in` with one certificate covering all three hostnames.

Run every command in **PowerShell as Administrator** on the server.

| Path | What |
|---|---|
| `C:\scr` | this git repo |
| `C:\krm_doc\nginx-1.30.3` | your existing nginx (shared with other apps) |
| `C:\krm_doc\nginx-1.30.3\certs\p2p.testerapp.in-chain.pem` / `-key.pem` | SCR certificate (issued on another machine, copied in manually) |

## How SCR plugs into your nginx

SCR is one self-contained file, `C:\scr\infra\nginx\scr.conf`, loaded by **one `include` line**.
It never replaces `nginx.conf`, never installs a service, never restarts nginx (reload only,
which is graceful), and never takes over other sites:

- matches only `p2p` / `rtc` / `turn` `.p2p.testerapp.in`, and never uses `default_server`
- uses SCR-prefixed names (`$scr_connection_upgrade`, `SCR_SSL`) so nothing clashes with your config
- puts nothing at `http` level that would change other sites

**Rollback at any time:** delete the include line and reload.

---

## Step 1 — Repo

```powershell
git clone https://github.com/ShubhamPy0612/scr.git C:\scr
cd C:\scr
git checkout claude/charming-mendel-3w9kd8
```

## Step 2 — Firewall and router

```powershell
powershell -ExecutionPolicy Bypass -File C:\scr\infra\scripts\open-firewall.ps1
```

This only adds rules named `SCR - ...`. Your existing rules aren't touched.
Forward these ports on the router to the server's LAN IP (80/443 are probably forwarded already):

| Port | Protocol | Purpose | Used from |
|---|---|---|---|
| 80, 443 | TCP | nginx | Phase 0 |
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

Save both files in `infra\secrets\` in a password manager.

## Step 4 — Start Postgres

```powershell
cd C:\scr\infra
Copy-Item .env.example .env
docker compose up -d
docker compose ps
docker logs scr-postgres 2>&1 | Select-String "scr: app role"
```

Wait for `(healthy)`. DB admin from the server (pgAdmin/DBeaver): `127.0.0.1:5432`, user `postgres`,
password from `pg_superuser_password.txt`.

## Step 5 — Certificate (manual, no auto-renewal on this server)

`infra\nginx\snippets\ssl.conf` points at:

- `C:\krm_doc\nginx-1.30.3\certs\p2p.testerapp.in-chain.pem`
- `C:\krm_doc\nginx-1.30.3\certs\p2p.testerapp.in-key.pem`

Nothing on this server requests or renews certificates. Before the certificate expires (Let's Encrypt: 90 days),
issue a new one on the other machine, overwrite these two files, and run `reload-nginx.ps1`.
`verify-phase0.ps1` fails when fewer than 14 days are left, as a reminder.

## Step 6 — Add SCR to nginx (the only change to your nginx)

```powershell
cd C:\krm_doc\nginx-1.30.3
Copy-Item conf\nginx.conf "conf\nginx.conf.bak-$(Get-Date -Format yyyyMMdd-HHmm)"
notepad conf\nginx.conf
```

Inside the `http { ... }` block, as the **last line before its closing `}`**, add:

```nginx
    include C:/scr/infra/nginx/scr.conf;
```

Then test and reload. The script only reloads if the test passes, so a mistake never takes other sites down:

```powershell
powershell -ExecutionPolicy Bypass -File C:\scr\infra\scripts\reload-nginx.ps1
```

If the test fails, remove the line (or restore the `.bak` file) and send me the error.

## Step 7 — Verify

```powershell
powershell -ExecutionPolicy Bypass -File C:\scr\infra\scripts\verify-phase0.ps1
```

Then from your phone on **mobile data**:

- `https://p2p.testerapp.in` → "SCR - Phase 0 OK", padlock valid
- `https://rtc.p2p.testerapp.in/healthz` → `ok`
- `https://p2p.testerapp.in/api/` → `502 Bad Gateway` (expected until Phase 1)
- your **other apps** still work as before

## Done when

- [ ] `verify-phase0.ps1` passes all checks
- [ ] Placeholder page loads over HTTPS from outside your network
- [ ] Other apps on the same nginx unaffected
- [ ] Secrets backed up
