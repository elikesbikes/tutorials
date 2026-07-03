# Nginx Proxy Manager

Self-hosted [Nginx Proxy Manager](https://nginxproxymanager.com/) (NPM) with a MariaDB backend.

## Table of Contents

1. [Overview](#1-overview)
2. [Services](#2-services)
3. [Prerequisites](#3-prerequisites)
4. [Configuration](#4-configuration)
5. [Usage](#5-usage)
6. [Access](#6-access)

## 1. Overview

NPM provides a web UI for managing reverse-proxy hosts and Let's Encrypt certificates. This stack runs the app (`npm-app`) and its MariaDB database (`npm-db`).

> **Note:** The compose file is named `docker-compose-yml` — rename to `docker-compose.yml` or pass with `-f`. The `80:80` / `443:443` port mappings are commented out; uncomment them if this instance handles inbound HTTP/HTTPS directly.

## 2. Services

| Service | Image | Purpose |
|---------|-------|---------|
| `nginx_npm-app` | `jc21/nginx-proxy-manager:latest` | Proxy + admin UI |
| `nginx_npm-db` | `jc21/mariadb-aria:latest` | Configuration database |

## 3. Prerequisites

- Docker and Docker Compose
- External network `frontend`

## 4. Configuration

Database credentials are set inline in the compose file (`npm`/`npm`). Data persists in `./data`, certs in `./letsencrypt`, and MySQL in `./mysql`.

## 5. Usage

```bash
docker compose -f docker-compose-yml up -d
```

## 6. Access

- Admin UI: `http://<host>:82` (container `81`)
- Default login: `admin@example.com` / `changeme` (change immediately)
