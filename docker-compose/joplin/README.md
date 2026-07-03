# Joplin Server

Self-hosted [Joplin Server](https://joplinapp.org/) for syncing notes across devices, backed by PostgreSQL.

## Table of Contents

1. [Overview](#1-overview)
2. [Services](#2-services)
3. [Prerequisites](#3-prerequisites)
4. [Configuration](#4-configuration)
5. [Usage](#5-usage)
6. [Access](#6-access)

## 1. Overview

Joplin Server provides an end-to-end-encrypted sync target for the Joplin note-taking apps, with a PostgreSQL 16 database. The database has a healthcheck gating app startup.

## 2. Services

| Service | Image | Purpose |
|---------|-------|---------|
| `db` | `postgres:16` | Notes database (`./joplin-data`) |
| `app` | `joplin/server:latest` | Joplin sync server |

## 3. Prerequisites

- Docker and Docker Compose
- External network `frontend`

## 4. Configuration

Provide a `.env` file with:

```env
POSTGRES_USER=
POSTGRES_PASSWORD=
POSTGRES_DB=joplin
APP_PORT=22300
APP_BASE_URL=
APP_PORT=22300
```

The compose file maps `POSTGRES_DATABASE` from your `POSTGRES_DB` value automatically.

## 5. Usage

```bash
docker compose up -d
```

## 6. Access

- `http://<host>:${APP_PORT}` (container port `22300`)
