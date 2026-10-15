# SCR

Self-hosted, invite-only streaming + chat app (web + Android) for a small group.

- **Streaming / calls:** LiveKit (WebRTC SFU), screen + system audio, 720p/1080p30
- **Chat & files:** end-to-end encrypted, history stored (as ciphertext) on the server
- **Stack:** Node.js + TypeScript backend, React web app, React Native Android app, Postgres
- **Hosting:** Windows Server 2022, Docker Desktop (WSL2), nginx on the host

## Repository layout

```
infra/             Docker Compose, Postgres init, nginx configs, PowerShell scripts
docs/PHASE-*.md    step-by-step runbook per phase
```

## Phases

| Phase | Scope | Status |
|---|---|---|
| 0 | Infrastructure: Docker, Postgres, nginx, TLS, firewall | in progress |
| 1 | Accounts & invite-only auth, backend + web skeleton | — |
| 2 | E2EE chat (1:1 + group), paged history, client cache | — |
| 3 | Encrypted media sharing (≤100 MB) | — |
| 4 | Calls & streaming on web (LiveKit) | — |
| 5 | Android app (React Native) | — |
| 6 | Windows desktop streaming app | — |
| 7 | Hardening, backups, monitoring | — |

Start with [docs/PHASE-0.md](docs/PHASE-0.md).
