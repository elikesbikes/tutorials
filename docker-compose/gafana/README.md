# Grafana

Self-hosted [Grafana](https://grafana.com/) (OSS) for metrics and dashboards.

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Usage](#3-usage)
4. [Access](#4-access)

## 1. Overview

Grafana OSS provides visualization and dashboarding, typically paired with the sibling `prometheus/` and `influxdb/` stacks as data sources. Data persists in the named volume `grafana-data`.

## 2. Prerequisites

- Docker and Docker Compose

## 3. Usage

```bash
docker compose up -d
```

## 4. Access

- `http://<host>:3000` (default credentials `admin` / `admin` on first login)
