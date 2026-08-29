# IP Scanner (WatchYourLAN)

LAN device discovery and monitoring with [WatchYourLAN](https://github.com/aceberg/WatchYourLAN).

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Configuration](#3-configuration)
4. [Usage](#4-usage)
5. [Access](#5-access)

## 1. Overview

WatchYourLAN (container `watchyourlan`) scans configured network interfaces, tracks devices seen on the LAN, and stores results in a SQLite database. It runs in `host` network mode for direct network access. Logs ship to syslog at `192.168.5.20:1514`. (See also the sibling `watchyourlan/` directory for an alternate config.)

## 2. Prerequisites

- Docker and Docker Compose
- Host network access
- `./dockerdata/wyl` directory

## 3. Configuration

Key environment variables:

| Variable | Purpose |
|----------|---------|
| `IFACE` | Interfaces to scan (space-separated) |
| `DBPATH` | SQLite DB path (default `/data/db.sqlite`) |
| `GUIIP` / `GUIPORT` | Web UI bind address / port (default `8840`) |
| `TIMEOUT` | Scan interval seconds |
| `SHOUTRRR_URL` | Optional notification URL |
| `THEME` | UI theme (e.g. `darkly`) |

## 4. Usage

```bash
docker compose up -d
```

## 5. Access

- `http://<host>:8840`
