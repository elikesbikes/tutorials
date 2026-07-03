# Syncthing Health

HTTP health, sync-lag, and offline monitoring endpoints for [Syncthing](https://syncthing.net/), for Uptime Kuma, with transition-based ntfy alerts.

## Table of Contents

1. [Overview](#1-overview)
2. [Endpoints](#2-endpoints)
3. [Prerequisites](#3-prerequisites)
4. [Configuration](#4-configuration)
5. [Usage](#5-usage)
6. [Access](#6-access)

## 1. Overview

A single Alpine-based container (built locally with `bash`, `curl`, `jq`, `socat` baked in) runs three `socat` listeners that execute bash health scripts on request. Results are exposed over HTTP for Uptime Kuma, with state-transition ntfy notifications. All dependencies are baked into the image — no runtime `apk` installs. See the header comments in `docker-compose.yml` for the running changelog (current: 1.9.0).

## 2. Endpoints

| Port | Path (via Traefik) | Purpose |
|------|--------------------|---------|
| `9123` | `/health` | Overall Syncthing health |
| `9124` | `/sync-lag` | Device-specific sync lag |
| `9125` | `/offline` | Device offline / last-seen |

Traefik routes these under `syncthing-ranger0-health.home.elikesbikes.com`.

## 3. Prerequisites

- Docker and Docker Compose
- External network `frontend`
- Traefik running on the same network
- `./scripts/` and `./state/` directories

## 4. Configuration

Provide a `.env` file (also mounted at `/root/.syncthing-health.env`) with your Syncthing API URL/key, device thresholds, and ntfy target. Scripts are bind-mounted read-only from `./scripts/`.

## 5. Usage

```bash
docker compose up -d --build
```

## 6. Access

- `https://syncthing-ranger0-health.home.elikesbikes.com/health`
- `.../sync-lag`, `.../offline`
