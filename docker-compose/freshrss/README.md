# FreshRSS

Self-hosted [FreshRSS](https://freshrss.org/) feed aggregator, served through Traefik.

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Configuration](#3-configuration)
4. [Usage](#4-usage)
5. [Access](#5-access)

## 1. Overview

FreshRSS (container `freshrss-prod-1`) is a lightweight, self-hosted RSS/Atom aggregator with API support enabled for mobile clients. Feeds refresh every 30 minutes (`CRON_MIN=*/30`). It is not published on a host port — Traefik routes `rss.home.elikesbikes.com` to port 80.

## 2. Prerequisites

- Docker and Docker Compose
- External network `frontend`
- Traefik running on the same network

## 3. Configuration

Provide a `.env` file with:

```env
BASE_URL=https://rss.home.elikesbikes.com
```

Volumes: `./data` (database) and `./extensions`.

## 4. Usage

```bash
docker compose up -d
```

## 5. Access

- `https://rss.home.elikesbikes.com`
