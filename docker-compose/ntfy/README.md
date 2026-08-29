# ntfy

Self-hosted [ntfy](https://ntfy.sh/) pub/sub push-notification server, served through Traefik.

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Configuration](#3-configuration)
4. [Usage](#4-usage)
5. [Access](#5-access)

## 1. Overview

ntfy sends push notifications to phones and desktops via simple HTTP. It is used across the homelab for alerts (Uptime Kuma, WatchYourLAN, backup jobs, etc.). It is not published on a host port — Traefik routes `ntfy.home.elikesbikes.com` to port 80. Logs ship to syslog at `192.168.5.20:1514`.

## 2. Prerequisites

- Docker and Docker Compose
- External network `frontend`
- Traefik running on the same network
- `./cache/ntfy` and `./etc/ntfy` directories

## 3. Configuration

Server config lives in `./etc/ntfy/server.yml` (mounted at `/etc/ntfy`). Cache/attachments persist in `./cache/ntfy`. A healthcheck polls `/v1/health`.

## 4. Usage

```bash
docker compose up -d
```

Publish a test message:

```bash
curl -d "hello" https://ntfy.home.elikesbikes.com/mytopic
```

## 5. Access

- `https://ntfy.home.elikesbikes.com`
