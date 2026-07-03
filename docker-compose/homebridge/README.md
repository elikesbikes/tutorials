# Homebridge

Self-hosted [Homebridge](https://homebridge.io/) — a HomeKit bridge for non-native smart-home devices.

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Configuration](#3-configuration)
4. [Usage](#4-usage)
5. [Access](#5-access)

## 1. Overview

Homebridge (container `homebridge-prod-1`) emulates the HomeKit API so unsupported accessories appear in Apple Home. It attaches to the `net.home.elikesbikes` macvlan network with a static IP (`192.168.5.14`) — required for HomeKit's mDNS/Bonjour discovery — and is also routed via Traefik at `homebridge.home.elikesbikes.com`.

## 2. Prerequisites

- Docker and Docker Compose
- External macvlan network `net.home.elikesbikes`
- Traefik (for the web UI hostname)
- `./volumes/homebridge` directory

## 3. Configuration

Configuration and plugins are managed through the Homebridge UI and persisted in `./volumes/homebridge`. The static IP is set in the compose file.

## 4. Usage

```bash
docker compose up -d
```

## 5. Access

- UI: `https://homebridge.home.elikesbikes.com` (or `http://192.168.5.14:8581`)
