# Socket Proxy

A hardened [LinuxServer.io socket-proxy](https://github.com/linuxserver/docker-socket-proxy) deployment that exposes a filtered, read-only view of the Docker API to other containers — instead of giving them direct access to `/var/run/docker.sock`.

Access is brokered internally over a shared `frontend` network and published externally only through Traefik (HTTPS + IP allowlist). The Docker API is **not** exposed on the LAN.

## Table of Contents

1. [Overview](#1-overview)
2. [Features](#2-features)
3. [Prerequisites](#3-prerequisites)
4. [Usage](#4-usage)
5. [Configuration](#5-configuration)
6. [Networking & Traefik](#6-networking--traefik)
7. [Security Notes](#7-security-notes)

## 1. Overview

Many tools (Traefik, Portainer, dashboards, etc.) need to talk to the Docker API. Mounting the raw Docker socket into those containers is dangerous — it is effectively root on the host. This project runs `socket-proxy` as a middleman that:

- Mounts the Docker socket **read-only**.
- Whitelists only the API endpoints you explicitly enable.
- Serves the filtered API on internal port `2375` to other containers on the `frontend` network.

## 2. Features

- **Least-privilege API access** — per-endpoint allow/deny via environment variables.
- **Read-only container filesystem** with a `tmpfs` for `/run`.
- **No host port published** — the Docker API is reachable only inside the Docker network.
- **Traefik integration** — external access is HTTPS-only, behind an IP allowlist and security-headers middleware.
- **Auto-restart** via `restart: unless-stopped`.

## 3. Prerequisites

- Docker and Docker Compose.
- An existing external Docker network named `frontend`:

  ```bash
  docker network create frontend
  ```

- A running Traefik instance attached to the `frontend` network (for external access).
- Traefik middlewares `socketproxy-allowlist@file` and `security-headers@file` defined in your Traefik file provider.

## 4. Usage

Copy the example environment file and set the host-specific values:

```bash
cp .env.example .env
# edit .env and set HOSTNAME for this machine
```

Start the proxy:

```bash
docker compose up -d
```

View logs:

```bash
docker compose logs -f socket-proxy
```

Stop the proxy:

```bash
docker compose down
```

Other containers on the `frontend` network reach the Docker API at:

```
tcp://socket-proxy:2375
```

## 5. Configuration

Permissions are controlled by environment variables in [docker-compose.yml](docker-compose.yml). Each is `1` (allow) or `0` (deny). Current settings:

| Variable | Value | Purpose |
|----------|-------|---------|
| `CONTAINERS` | 1 | Access container endpoints |
| `IMAGES` | 1 | Access image endpoints |
| `NETWORKS` | 1 | Access network endpoints |
| `VOLUMES` | 1 | Access volume endpoints |
| `SERVICES` / `TASKS` / `SWARM` / `NODES` | 1 | Swarm-related endpoints |
| `ALLOW_START` | 1 | Permit starting containers |
| `ALLOW_STOP` | 1 | Permit stopping containers |
| `ALLOW_RESTARTS` | 0 | Deny container restarts |
| `POST` | 1 | Permit POST (write) requests |
| `EXEC` | 1 | Permit exec into containers |
| `INFO` / `VERSION` / `PING` / `EVENTS` | 1 | Read-only daemon endpoints |
| `LOG_LEVEL` | info | Proxy log verbosity |
| `TZ` | Etc/UTC | Timezone |

Tighten this to the minimum your consumers actually need. For example, if only Traefik consumes the proxy, you can disable `POST`, `EXEC`, `ALLOW_START`, and `ALLOW_STOP`.

## 6. Networking & Traefik

- The container joins the external `frontend` network only.
- Host port `2375` is **intentionally not published** — there is no LAN exposure.
- Traefik routes external traffic to the proxy via the labels in the compose file. The host-specific parts come from `.env`:
  - Host rule: `socketproxy-${HOSTNAME}.home.elikesbikes.com` (e.g. `socketproxy-tars.home.elikesbikes.com`)
  - Router/service names are also suffixed with `${HOSTNAME}` so multiple hosts sharing a Traefik instance don't collide.
  - Entrypoint: `websecure` (HTTPS)
  - TLS cert resolver: `production`
  - Middlewares: IP allowlist + security headers
  - Upstream service port: `2375`

### Multi-host deployment

The compose file is host-agnostic; only `.env` changes per machine. On each host:

```bash
cp .env.example .env   # set HOSTNAME=<this host>
docker compose up -d
```

## 7. Security Notes

- The Docker socket is mounted **read-only** (`:ro`).
- The container runs with a **read-only root filesystem**.
- Avoid enabling `EXEC` and `POST` unless a consumer genuinely requires them — together they significantly expand what a compromised consumer could do.
- Keep external access behind the Traefik IP allowlist.

---

**Image:** [`lscr.io/linuxserver/socket-proxy:latest`](https://github.com/linuxserver/docker-socket-proxy)
