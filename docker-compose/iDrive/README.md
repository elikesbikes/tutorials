# IDrive

Containerized [IDrive](https://www.idrive.com/) Linux backup client.

## Table of Contents

1. [Overview](#1-overview)
2. [What's Here](#2-whats-here)
3. [Prerequisites](#3-prerequisites)
4. [Configuration](#4-configuration)
5. [Usage](#5-usage)

## 1. Overview

This project runs the IDrive for Linux backup scripts inside a container (`idrive-prod-1`), backing up a mounted NFS source to the IDrive cloud. A `DockerFile` is included to build the client image from scratch (Ubuntu + IDrive Linux scripts); the compose file uses the prebuilt `renofischa/idrive:latest` image.

## 2. What's Here

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Service definition using `renofischa/idrive` |
| `DockerFile` | From-scratch IDrive client image build |
| `entrypoint.sh` | Container startup script |

## 3. Prerequisites

- Docker and Docker Compose
- External network `frontend`
- NFS mount at `/mnt_nfs` (mounted read-only at `/mnt/backup`)

## 4. Configuration

| Volume | Purpose |
|--------|---------|
| `config:/opt/IDriveForLinux/idriveIt` | IDrive account / job config |
| `./files:/mnt/files` | Working files |
| `/mnt_nfs:/mnt/backup:ro` | Backup source (read-only) |

Environment: `TZ=America/Los_Angeles`. Complete IDrive account login on first run.

## 5. Usage

```bash
docker compose up -d
docker compose logs -f idrive
```
