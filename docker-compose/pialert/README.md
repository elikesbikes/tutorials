# PiAlert / NetAlertX

Network intrusion / presence detection with [NetAlertX](https://github.com/jokob-sk/NetAlertX) (formerly Pi.Alert).

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Configuration](#3-configuration)
4. [Usage](#4-usage)
5. [Access](#5-access)

## 1. Overview

NetAlertX (container `netalertx`) scans the LAN for connected devices and alerts on new/unknown devices. It runs in `host` network mode for direct scanning access.

> **Note:** The compose file pins the older `jokobsk/pi.alert:latest` image. For current releases switch to `jokob-sk/netalertx:latest`.

## 2. Prerequisites

- Docker and Docker Compose
- Host network access
- `./config`, `./db`, and `./logs` directories

## 3. Configuration

| Variable | Purpose |
|----------|---------|
| `TZ` | Timezone (`America/Los_Angeles`) |
| `HOST_USER_ID` / `HOST_USER_GID` | Host UID/GID (usually 1000) |
| `PORT` | Web UI port (`20211`) |

## 4. Usage

```bash
docker compose up -d
```

## 5. Access

- `http://<host>:20211`
