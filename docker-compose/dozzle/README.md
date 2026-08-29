# Dozzle

Real-time Docker log viewer using [Dozzle](https://dozzle.dev/).

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Configuration](#3-configuration)
4. [Usage](#4-usage)
5. [Access](#5-access)

## 1. Overview

Dozzle (container `dozzle-prod-1`) provides a lightweight web UI for viewing live container logs. It reads the Docker socket read-only and, in this setup, has container actions and shell access enabled.

## 2. Prerequisites

- Docker and Docker Compose
- External network `frontend`
- Access to `/var/run/docker.sock`

## 3. Configuration

Environment options set in the compose file:

| Variable | Value | Purpose |
|----------|-------|---------|
| `DOZZLE_ENABLE_ACTIONS` | `true` | Allow start/stop/restart from the UI |
| `DOZZLE_ENABLE_SHELL` | `true` | Allow shell access into containers |
| `DOZZLE_LEVEL` | `info` | Dozzle's own log level |

> **Note:** Enabling actions and shell grants significant control — protect access accordingly.

## 4. Usage

```bash
docker compose up -d
```

## 5. Access

- `http://<host>:8888`
