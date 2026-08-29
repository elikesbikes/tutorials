# WatchYourLAN

LAN device discovery and monitoring with [WatchYourLAN](https://github.com/aceberg/WatchYourLAN).

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Configuration](#3-configuration)
4. [Usage](#4-usage)
5. [Access](#5-access)

## 1. Overview

WatchYourLAN scans a network interface, tracks devices on the LAN, and can send notifications when devices appear/disappear. It runs in `host` network mode. (See also the sibling `ipscanner/` directory for an alternate configuration.)

> **Note:** The compose file's top-level `services:` key is missing indentation — the `wyl:` service should sit under `services:`. Fix the YAML structure before running.

## 2. Prerequisites

- Docker and Docker Compose
- Host network access
- `/home/ecloaiza/docker/wyl` data directory

## 3. Configuration

| Variable | Value | Purpose |
|----------|-------|---------|
| `IFACES` | `ens18` | Interface to scan |
| `HOST` / `PORT` | `0.0.0.0` / `8840` | Web UI bind |
| `SHOUTRRR_URL` | `ntfy://ntfy.home.elikesbikes.com/lan` | Notifications via ntfy |

## 4. Usage

```bash
docker compose up -d
```

## 5. Access

- `http://<host>:8840`
