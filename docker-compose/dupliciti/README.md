# Duplicati

Self-hosted backup with [Duplicati](https://www.duplicati.com/) (LinuxServer.io image).

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Configuration](#3-configuration)
4. [Usage](#4-usage)
5. [Access](#5-access)

## 1. Overview

Duplicati provides encrypted, incremental, deduplicated backups to local and cloud destinations. The host root (`/`) is mounted read-only at `/source` so any path can be selected as a backup source.

> **Note:** The compose file in this directory is named `docker-compose-yaml`. Rename it to `docker-compose.yml` or pass it explicitly with `-f`.

## 2. Prerequisites

- Docker and Docker Compose
- External network `frontend`
- `./config` and `./backups` directories

## 3. Configuration

| Volume | Purpose |
|--------|---------|
| `./config:/config` | Duplicati configuration and job DB |
| `./backups:/backups` | Local backup destination |
| `/:/source` | Host filesystem as a backup source |

Environment: `PUID=0`, `PGID=0`, `TZ=America/Los_Angeles`.

## 4. Usage

```bash
docker compose -f docker-compose-yaml up -d
```

## 5. Access

- `http://<host>:8200`
