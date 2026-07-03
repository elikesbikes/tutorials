# Prometheus

Metrics collection with [Prometheus](https://prometheus.io/), Node Exporter, and cAdvisor.

## Table of Contents

1. [Overview](#1-overview)
2. [Services](#2-services)
3. [Prerequisites](#3-prerequisites)
4. [Configuration](#4-configuration)
5. [Usage](#5-usage)
6. [Access](#6-access)

## 1. Overview

This stack scrapes and stores time-series metrics, with Node Exporter for host metrics and cAdvisor for per-container metrics. It typically feeds the sibling `gafana/` dashboards.

## 2. Services

| Service | Image | Purpose |
|---------|-------|---------|
| `prometheus` | `prom/prometheus:latest` | Metrics DB / scraper |
| `node_exporter` | `quay.io/prometheus/node-exporter` | Host metrics |
| `cadvisor` | `gcr.io/cadvisor/cadvisor:v0.47.0` | Container metrics |

## 3. Prerequisites

- Docker and Docker Compose
- External network `frontend`
- Prometheus config at `/home/ecloaiza/prometheus/prometheus.yml`

## 4. Configuration

Prometheus reads `--config.file=/etc/prometheus/prometheus.yml` (host-mounted from `/home/ecloaiza/prometheus`). Data persists in the `prometheus-data` volume. Node Exporter runs with `pid: host` and the root filesystem mounted read-only; cAdvisor mounts Docker/sys/disk paths read-only.

## 5. Usage

```bash
docker compose up -d
```

## 6. Access

- Prometheus UI: `http://<host>:9090`
- cAdvisor: port `8080` (commented out by default)
