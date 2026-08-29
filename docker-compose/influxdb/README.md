# InfluxDB

Self-hosted [InfluxDB 2.x](https://www.influxdata.com/) time-series database.

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Configuration](#3-configuration)
4. [Usage](#4-usage)
5. [Access](#5-access)

## 1. Overview

InfluxDB stores time-series metrics (e.g. from Telegraf, Home Assistant) and is commonly visualized in the sibling `gafana/` stack. It initializes automatically in setup mode with an org, bucket, and admin user. Data persists in the `influxdb-data` volume; config at `/etc/influxdb2`.

## 2. Prerequisites

- Docker and Docker Compose

## 3. Configuration

Initial setup is driven by environment variables (change these before first run):

| Variable | Purpose |
|----------|---------|
| `DOCKER_INFLUXDB_INIT_MODE=setup` | Auto-initialize on first start |
| `DOCKER_INFLUXDB_INIT_USERNAME` | Admin username |
| `DOCKER_INFLUXDB_INIT_PASSWORD` | Admin password |
| `DOCKER_INFLUXDB_INIT_ORG` | Default organization |
| `DOCKER_INFLUXDB_INIT_BUCKET` | Default bucket |

Optional retention and admin-token variables are commented in the compose file.

## 4. Usage

```bash
docker compose up -d
```

## 5. Access

- `http://<host>:8086`
