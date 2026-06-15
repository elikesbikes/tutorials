# Traefik — Homelab Reverse Proxy (IaC Baseline)

A version-controlled, infrastructure-as-code Traefik v3 deployment that fronts homelab
applications with automatic HTTPS. Routers are discovered from Docker container labels
(via socket-proxy) and from file-based dynamic config. Certificates are issued
automatically by Let's Encrypt using the Cloudflare DNS-01 challenge (wildcard-capable).

> Cooper, this is the front door. Everything that wants a hostname comes through here.
> — TARS

## Table of Contents

1. [Architecture](#1-architecture)
2. [Prerequisites](#2-prerequisites)
3. [Project Structure](#3-project-structure)
4. [Configuration](#4-configuration)
5. [Installation](#5-installation)
6. [Routing an Application](#6-routing-an-application)
7. [Dashboard](#7-dashboard)
8. [Certificates](#8-certificates)
9. [Logging](#9-logging)
10. [Deployment / Backup](#10-deployment--backup)
11. [Troubleshooting](#11-troubleshooting)

## 1. Architecture

- **Host:** tars (`192.168.5.127`) — development
- **Image:** `traefik:v3.7.5`, run as non-root (`1000:1000`)
- **Network:** `frontend` (external, shared homelab network)
- **Docker access:** through the existing `socket-proxy` container at
  `tcp://socket-proxy:2375` — no raw `/var/run/docker.sock` mount.
- **EntryPoints:** `web` (:80, redirects to HTTPS) and `websecure` (:443)
- **Providers:** Docker (label discovery, `exposedByDefault: false`) and File
  (`/etc/traefik/dynamic`, hot-reloaded)

## 2. Prerequisites

- Docker + Docker Compose
- The external `frontend` network: `docker network create frontend` (already exists in homelab)
- The `socket-proxy` container running on `frontend`
- A Cloudflare API token with `Zone:DNS:Edit` + `Zone:Zone:Read` on `elikesbikes.com`
- DNS: `proxy-tars.home.elikesbikes.com` → `192.168.5.127`

## 3. Project Structure

```
traefik/
├── docker-compose.yml            # Traefik service (parameterized via .env)
├── .env                          # Per-host config + secrets (git-ignored)
├── .env.example                  # Template documenting every host var
├── scripts/
│   └── bootstrap.sh              # One-time per-host setup (idempotent)
├── config/
│   ├── traefik.yaml              # Static config (entrypoints, ACME, providers)
│   └── dynamic/
│       └── middlewares.yaml      # Shared middlewares (security headers, allowlist)
├── secrets/                      # Per-host secrets (git-ignored)
│   ├── dashboard.htpasswd        # basic-auth users (via basicauth.usersfile)
│   └── dashboard.htpasswd.example
└── certs/
    └── acme.json                 # Issued certs (git-ignored, chmod 600)
```

## 4. Configuration

| File | Purpose |
|------|---------|
| `.env` | All host-specific values: CF token, `TRAEFIK_DASHBOARD_HOST`, PUID/PGID, TZ, syslog |
| `config/traefik.yaml` | Static config — entrypoints, ACME resolver, providers (host-agnostic) |
| `config/dynamic/middlewares.yaml` | Hot-reloaded shared middlewares (committed) |
| `secrets/dashboard.htpasswd` | Dashboard basic-auth (referenced by a compose label `basicauth.usersfile`) |
| `docker-compose.yml` labels | Dashboard router — hostname comes from `${TRAEFIK_DASHBOARD_HOST}` |

Nothing host-specific is hardcoded in committed files. Secrets stay out of git: `.env`,
`secrets/*` (except `.example`), and `certs/*.json` are all git-ignored.

## 5. Installation (per host)

The fastest path on any host is the bootstrap script — it's idempotent and prompts for
the per-host values:

```bash
./scripts/bootstrap.sh
```

It ensures the `frontend` network, checks socket-proxy + ports, creates `.env`
(prompting for `CF_DNS_API_TOKEN` and `TRAEFIK_DASHBOARD_HOST`), generates
`secrets/dashboard.htpasswd` (prompting for the shared password), sets `certs/acme.json`
perms, then runs `docker compose up -d`.

Manual equivalent:

```bash
cp .env.example .env && $EDITOR .env          # CF token + TRAEFIK_DASHBOARD_HOST
htpasswd -nbB admin 'your-password' > secrets/dashboard.htpasswd && chmod 600 secrets/dashboard.htpasswd
touch certs/acme.json && chmod 600 certs/acme.json
docker compose config && docker compose up -d
docker logs -f traefik
```

Everything host-specific lives in `.env`; the dashboard hostname and credentials are
**not** baked into committed config.

## 6. Routing an Application

Add labels to any container on the `frontend` network. Example:

```yaml
services:
  myapp:
    image: myapp:latest
    networks:
      - frontend
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.home.elikesbikes.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=production"
      - "traefik.http.services.myapp.loadbalancer.server.port=8080"
      # Optional shared middleware:
      - "traefik.http.routers.myapp.middlewares=security-headers@file"

networks:
  frontend:
    external: true
```

Traefik picks it up automatically — no Traefik restart needed.

## 7. Dashboard

- URL: `https://${TRAEFIK_DASHBOARD_HOST}` (e.g. `https://proxy-tars.home.elikesbikes.com`)
- Auth: HTTP basic-auth via `secrets/dashboard.htpasswd` (compose label
  `basicauth.usersfile`).
- The router is defined by labels on the Traefik container — `api@internal`, `production`
  cert resolver, `security-headers` middleware. Hostname comes from `.env`.

Regenerate credentials (then `docker compose up -d` to reload the usersfile):

```bash
htpasswd -nbB admin 'new-password' > secrets/dashboard.htpasswd
```

## 8. Certificates

- **Issuer:** Let's Encrypt production (`acme-v02`)
- **Challenge:** Cloudflare DNS-01 (supports wildcard certs, no inbound :80 needed)
- **Store:** `certs/acme.json` (bind-mounted, `chmod 600`, owned by UID 1000)
- Renewal is automatic. To force re-issue, stop Traefik, clear `acme.json`, restart.

## 9. Logging

Container logs ship to Graylog via the Docker syslog driver:

- Address: `udp://192.168.5.30:514`
- Format: `rfc3164`, tag `traefik`
- Traefik emits JSON access + app logs to stdout for richer Graylog parsing.

## 10. Deployment / Backup

This folder is not a git repo. Configuration is version-controlled by copying the
safe files into the central `tutorials` repo with the homelab helper:

```bash
gacp_tutorials_wcopy traefik "your commit message"
```

It rsyncs a filtered subset into `tutorials/docker-compose/traefik/` and pushes.
Secrets are never copied — `.env`, `certs/`, and `secrets/` are excluded by the helper.

### Deploying to a new host (one-time bootstrap)

1. Deliver the project dir to the host (code only — no secrets).
2. Add a DNS A record: `proxy-<host>.home.elikesbikes.com → <host IP>`.
3. On the host: `./scripts/bootstrap.sh` — paste the CF token, set
   `TRAEFIK_DASHBOARD_HOST=proxy-<host>...`, enter the shared dashboard password.
4. The same Cloudflare token works on every host; `acme.json` self-issues locally per host.

Prereqs per host: the `frontend` network, a running `socket-proxy`, and ports 80/443 free
(bootstrap checks all three).

## 11. Troubleshooting

| Symptom | Check |
|---------|-------|
| No cert issued | `docker logs traefik` for ACME errors; verify `CF_DNS_API_TOKEN` scope |
| 404 on a host | Container has `traefik.enable=true` and is on `frontend`; rule matches |
| Dashboard 401 loop | Hash in `secrets/dashboard.htpasswd` is bcrypt (`htpasswd -nbB`); re-run `up -d` after changes |
| Dashboard 404 | `TRAEFIK_DASHBOARD_HOST` set in `.env` and DNS points to this host |
| Provider connect error | `socket-proxy` is running on `frontend` and reachable on :2375 |
| `acme.json` permission error | `chmod 600 certs/acme.json`, owned by UID 1000 |

---

_README authored by TARS aka Cooper per homelab standards._
