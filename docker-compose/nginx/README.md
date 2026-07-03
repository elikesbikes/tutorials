# Nginx

Standalone [Nginx](https://nginx.org/) container (`nginx-prod-2`), used for TLS termination / templated configs.

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Configuration](#3-configuration)
4. [Usage](#4-usage)

## 1. Overview

A minimal Nginx instance that loads config from mounted templates. It listens on host port `8445` (container `443`) and attaches to the shared `frontend` network.

## 2. Prerequisites

- Docker and Docker Compose
- External network `frontend`
- `./templates/` directory containing Nginx config templates

## 3. Configuration

| Volume | Purpose |
|--------|---------|
| `./templates:/etc/nginx/templates:ro` | Nginx `envsubst` templates |

Files ending in `.template` are processed and written to `/etc/nginx/conf.d/` at startup.

## 4. Usage

```bash
docker compose up -d
```

Reachable on `https://<host>:8445`.
