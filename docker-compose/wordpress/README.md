# WordPress

Self-hosted [WordPress](https://wordpress.org/) with MySQL, served through Traefik for `elikesbikes.com`.

## Table of Contents

1. [Overview](#1-overview)
2. [Services](#2-services)
3. [Prerequisites](#3-prerequisites)
4. [Configuration](#4-configuration)
5. [Usage](#5-usage)
6. [Access](#6-access)

## 1. Overview

Runs the WordPress site behind Traefik, with TLS via the `production` cert resolver. Traefik routes both `elikesbikes.com` and `emilikesbikes.home.elikesbikes.cloud` to the app on port 80. Data persists in named volumes.

## 2. Services

| Service | Image | Purpose |
|---------|-------|---------|
| `wordpress` | `wordpress` | PHP/Apache web app (`wordpress-prod-1-app`) |
| `db` | `mysql:8.0` | Database (`wordpress-prod-1-db`) |

## 3. Prerequisites

- Docker and Docker Compose
- External network `frontend`
- Traefik running on the same network

## 4. Configuration

Provide a `.env` file with:

```env
MYSQL_DATABASE=
MYSQL_USER=
MYSQL_PASSWORD=
MYSQL_ROOT_PASSWORD=
```

## 5. Usage

```bash
docker compose up -d
```

## 6. Access

- `https://elikesbikes.com`
- `https://emilikesbikes.home.elikesbikes.cloud`
- Local: `http://<host>:8080`
