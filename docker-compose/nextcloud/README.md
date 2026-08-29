# Nextcloud

Self-hosted [Nextcloud](https://nextcloud.com/) file sync and collaboration platform.

## Table of Contents

1. [Overview](#1-overview)
2. [Deployment Options](#2-deployment-options)
3. [Services](#3-services)
4. [Prerequisites](#4-prerequisites)
5. [Configuration](#5-configuration)
6. [Usage](#6-usage)

## 1. Overview

Two deployment styles are provided: a manual stack (`docker-compose.yml`) with MariaDB + Redis behind a reverse proxy, and the official All-in-One (`AIO-docker-compose.yml`) master container.

## 2. Deployment Options

| File | Style |
|------|-------|
| `docker-compose.yml` | Nextcloud + MariaDB + Redis, proxied via NPM/Traefik |
| `AIO-docker-compose.yml` | Nextcloud All-in-One master container |

## 3. Services (manual stack)

| Service | Image | Purpose |
|---------|-------|---------|
| `app` | `nextcloud:latest` | Web application |
| `db` | `mariadb:10.6` | Database |
| `redis` | `redis:alpine` | Caching |

## 4. Prerequisites

- Docker and Docker Compose
- External network `frontend`
- A reverse proxy for HTTPS (NPM/Traefik)

## 5. Configuration

Provide a `.env` file with:

```env
HOST_PORT=8080
NEXTCLOUD_DIR=./html
DATA_DIR=./data
DB_DIR=./db
DB_NAME=nextcloud
DB_USER=nextcloud
DB_PASSWORD=
DB_ROOT_PASSWORD=
NC_DOMAIN=nextcloud.home.elikesbikes.com
```

`OVERWRITEPROTOCOL=https` and `NEXTCLOUD_TRUSTED_DOMAINS` are preconfigured for proxy use.

## 6. Usage

```bash
# Manual stack
docker compose up -d

# Or All-in-One
docker compose -f AIO-docker-compose.yml up -d
```

AIO master UI: `https://<host>:8445`.
