# Uptime Kuma

Self-hosted [Uptime Kuma](https://uptime.kuma.pet/) uptime monitoring, served through Traefik.

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Configuration](#3-configuration)
4. [Usage](#4-usage)
5. [Access](#5-access)

## 1. Overview

Uptime Kuma (container `uptime-prod-1`) monitors HTTP(s), TCP, ping, and Docker container status with alerting and status pages. It is not published on a host port — Traefik routes `uptime.home.elikesbikes.com` to port 3001. The Docker socket is mounted for container-level checks.

## 2. Prerequisites

- Docker and Docker Compose
- External network `frontend`
- Traefik running on the same network

## 3. Configuration

- Data persists in `./uptime-kuma` (mounted at `/app/data`)
- `TZ=America/Los_Angeles`
- `/var/run/docker.sock` mounted for Docker monitors

## 4. Usage

```bash
docker compose up -d
```

## 5. Access

- `https://uptime.home.elikesbikes.com`
