# Jellyfin

Self-hosted [Jellyfin](https://jellyfin.org/) media server.

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Configuration](#3-configuration)
4. [Usage](#4-usage)
5. [Access](#5-access)

## 1. Overview

Jellyfin (container `jellyfin-prod-1`) streams movies, TV, and music from NAS-mounted media. It attaches to the `net.home.elikesbikes` macvlan network with a static IP (`192.168.5.42`) and runs as UID/GID `3000:3001`. GPU transcoding is available but commented out in the compose file.

## 2. Prerequisites

- Docker and Docker Compose
- External macvlan network `net.home.elikesbikes`
- NAS mounts at `/mnt/eminas1/jellyfin_media` and `/mnt/eminas1/jellyfin_data/cache`

## 3. Configuration

| Volume | Purpose |
|--------|---------|
| `./config:/config` | Jellyfin config / metadata |
| `/mnt/eminas1/jellyfin_data/cache:/cache` | Transcode / image cache |
| `/mnt/eminas1/jellyfin_media:/media` | Media library |

Set `JELLYFIN_PublishedServerUrl` to your external URL for autodiscovery.

## 4. Usage

```bash
docker compose up -d
```

## 5. Access

- `http://192.168.5.42:8096`
