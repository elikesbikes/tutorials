# Dashy

Self-hosted [Dashy](https://dashy.to/) dashboard for the homelab, served through Traefik and gated behind Authelia.

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Configuration](#3-configuration)
4. [Usage](#4-usage)
5. [Access](#5-access)

## 1. Overview

Dashy renders a start page / service dashboard from `conf/conf.yml`. It is not published on a host port — Traefik routes `dash.home.elikesbikes.com` to it and Authelia ForwardAuth requires login.

## 2. Prerequisites

- Docker and Docker Compose
- External network `frontend`
- Traefik and Authelia running on the same network
- `./conf/conf.yml` and `./item-icons/` present

## 3. Configuration

Edit `conf/conf.yml` to define your sections and items. Environment:

- `NODE_ENV=production`
- `TZ=America/Los_Angeles`

## 4. Usage

```bash
docker compose up -d
docker compose logs -f dashy
```

## 5. Access

- `https://dash.home.elikesbikes.com` (behind Authelia login)
