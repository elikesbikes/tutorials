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

| Port | Host + path (via Traefik) | Checks |
|------|---------------------------|--------|
| `9123` | `syncthing-homenas-health.home.elikesbikes.com/health` | NAS Syncthing API answers; no NAS folder paused or in error |
| `9124` | `syncthing-kipp-health.home.elikesbikes.com/sync-lag` | kipp behind (needItems > 0, at least `SYNCTHING_SYNC_PHANTOM_BYTES`) for longer than `SYNCTHING_SYNC_BEHIND_THRESHOLD_SECONDS` in **any** folder the NAS shares with it (or `SYNCTHING_FOLDER_IDS` if set). Body lists each folder; failures name the folder, item count and first paths |
| `9125` | `syncthing-kipp-health.home.elikesbikes.com/offline` | kipp disconnected from the NAS longer than `SYNCTHING_OFFLINE_THRESHOLD_SECONDS` |

Only kipp (`SYNCTHING_DEVICE_ID`) is checked by `/sync-lag` and `/offline`. The hostnames were `syncthing-ranger0-health` until 2026-10-08.

Consumers: Uptime Kuma on hailmary and rocky (monitors 52/53/55), and CheckMK HTTP checks `HTTPS Syncthing homenas health` (host homenas) and `HTTPS Syncthing kipp sync-lag` / `HTTPS Syncthing kipp offline` (host kipp), limited to the `homenas_online` time period (08:15-17:00) because the NAS powers off evenings.

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

- `https://syncthing-homenas-health.home.elikesbikes.com/health`
- `https://syncthing-kipp-health.home.elikesbikes.com/sync-lag`
- `https://syncthing-kipp-health.home.elikesbikes.com/offline`
