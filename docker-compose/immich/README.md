# Immich

Self-hosted [Immich](https://immich.app/) photo and video backup, served through Traefik.

## Table of Contents

1. [Overview](#1-overview)
2. [Services](#2-services)
3. [Prerequisites](#3-prerequisites)
4. [Configuration](#4-configuration)
5. [Usage](#5-usage)
6. [Access](#6-access)

## 1. Overview

Immich is a high-performance, self-hosted photo/video backup solution with mobile apps, ML-powered search, and face detection. The server joins both the project-internal network and the shared `frontend` network so Traefik can route `photos.home.elikesbikes.com` to it.

> **Note:** Always align this compose file with the version matching your release — see the [official releases](https://github.com/immich-app/immich/releases/latest).

## 2. Services

| Service | Image | Purpose |
|---------|-------|---------|
| `immich-server` | `immich-server` | API + web UI |
| `immich-machine-learning` | `immich-machine-learning` | ML (search, faces) |
| `redis` | `redis:6.2-alpine` | Cache / job queue |
| `database` | `tensorchord/pgvecto-rs:pg14` | PostgreSQL + vector search |

## 3. Prerequisites

- Docker and Docker Compose
- External network `frontend`
- Traefik running on the same network

## 4. Configuration

Provide a `.env` file with:

```env
IMMICH_VERSION=release
UPLOAD_LOCATION=./library
DB_DATA_LOCATION=./postgres
DB_PASSWORD=
DB_USERNAME=postgres
DB_DATABASE_NAME=immich
```

## 5. Usage

```bash
docker compose up -d
```

## 6. Access

- `https://photos.home.elikesbikes.com`
