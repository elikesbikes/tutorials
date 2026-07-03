# Grocery Forecast

Self-hosted grocery forecasting app built on [PocketBase](https://pocketbase.io/) with a custom app and proxy.

## Table of Contents

1. [Overview](#1-overview)
2. [Services](#2-services)
3. [Prerequisites](#3-prerequisites)
4. [Configuration](#4-configuration)
5. [Usage](#5-usage)

## 1. Overview

This stack pairs a PocketBase backend with a locally built application and proxy. Logs from all three services ship to syslog at `192.168.5.16:514`. See `CLAUDE.md` for architecture notes.

## 2. Services

| Service | Source | Purpose |
|---------|--------|---------|
| `grocery-pb` | `ghcr.io/muchobien/pocketbase:latest` | Database / backend (data in `./pb_data`) |
| `grocery-proxy` | built from `./proxy` | Reverse proxy / API gateway |
| `grocery-app` | built from `./app` | Frontend application |

## 3. Prerequisites

- Docker and Docker Compose
- External network `FRONTEND`
- `./app` and `./proxy` build contexts

## 4. Configuration

Copy `env.example` to `.env` and fill in the required values.

## 5. Usage

```bash
docker compose up -d --build
```
