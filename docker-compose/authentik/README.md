# Authentik

Self-hosted [Authentik](https://goauthentik.io/) identity provider (SSO / IdP) with PostgreSQL and Redis backends.

## Table of Contents

1. [Overview](#1-overview)
2. [Services](#2-services)
3. [Prerequisites](#3-prerequisites)
4. [Configuration](#4-configuration)
5. [Usage](#5-usage)
6. [Access](#6-access)

## 1. Overview

Authentik provides SSO, OAuth2/OIDC, SAML, and LDAP outposts for the homelab. The stack runs a server and a worker, both backed by PostgreSQL 12 and Redis. Logs are shipped to a syslog collector at `192.168.5.20:1514`.

## 2. Services

| Service | Image | Purpose |
|---------|-------|---------|
| `postgresql` | `postgres:12-alpine` | Authentik database |
| `redis` | `redis:alpine` | Cache / task queue |
| `server` | `ghcr.io/goauthentik/server` | Web / API server |
| `worker` | `ghcr.io/goauthentik/server` | Background worker (Docker integration) |

## 3. Prerequisites

- Docker and Docker Compose
- External network `frontend`

## 4. Configuration

Provide a `.env` file with at least:

```env
PG_PASS=          # required
PG_USER=authentik
PG_DB=authentik
AUTHENTIK_SECRET_KEY=
# optional overrides
AUTHENTIK_TAG=2023.8.3
COMPOSE_PORT_HTTP=9000
COMPOSE_PORT_HTTPS=9443
```

## 5. Usage

```bash
docker compose up -d
```

On first run, complete setup at `/if/flow/initial-setup/`.

## 6. Access

- HTTP: `http://<host>:9000`
- HTTPS: `https://<host>:9443`
