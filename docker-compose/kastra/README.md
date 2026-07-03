# Kestra

Self-hosted [Kestra](https://kestra.io/) workflow orchestration platform, backed by PostgreSQL.

## Table of Contents

1. [Overview](#1-overview)
2. [Services](#2-services)
3. [Prerequisites](#3-prerequisites)
4. [Configuration](#4-configuration)
5. [Usage](#5-usage)
6. [Access](#6-access)

## 1. Overview

Kestra is an event-driven workflow/data-orchestration engine. This deployment runs the standalone server (`kastra_app-prod-1`) with a PostgreSQL backend (`kastra_db-prod-1`) for the repository, queue, and storage.

> **Note:** The compose file is named `docker-compose-yml`. Rename to `docker-compose.yml` (or pass with `-f`). It also nests `volumes`/`services` under a `services` key — flatten these to top level before use. This config is development-oriented (runs as root, basic-auth disabled).

## 2. Services

| Service | Image | Purpose |
|---------|-------|---------|
| `postgres` | `postgres` | Repository / queue / metadata |
| `kestra` | `kestra/kestra:latest-full` | Orchestration server |

## 3. Prerequisites

- Docker and Docker Compose
- External network `frontend`
- Docker socket access (`/var/run/docker.sock`) for Docker task runners

## 4. Configuration

Provide a `.env` file with:

```env
POSTGRES_DB=kestra
POSTGRES_USER=kestra
POSTGRES_PASSWORD=
```

Kestra config is passed inline via `KESTRA_CONFIGURATION`.

## 5. Usage

```bash
docker compose -f docker-compose-yml up -d
```

## 6. Access

- UI: `http://<host>:8080`
