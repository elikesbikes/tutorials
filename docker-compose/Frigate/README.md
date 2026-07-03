# Frigate

Self-hosted [Frigate](https://frigate.video/) NVR with NVIDIA GPU-accelerated object detection.

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Configuration](#3-configuration)
4. [Usage](#4-usage)
5. [Ports](#5-ports)

## 1. Overview

Frigate (container `frigate-prod-1`) is a network video recorder with real-time object detection. This deployment uses the NVIDIA runtime for hardware acceleration and a tmpfs cache to reduce disk wear. It runs `privileged` with a 30s stop grace period for clean shutdown.

## 2. Prerequisites

- Docker and Docker Compose
- NVIDIA drivers + NVIDIA Container Toolkit (`runtime: nvidia`)
- External network `frontend`
- `./config/config.yml` (Frigate configuration) and `./storage/` for recordings

## 3. Configuration

Provide a `.env` file with:

```env
FRIGATE_RTSP_PASSWORD=
```

Camera definitions, detectors, and recording settings live in `./config/config.yml`. `shm_size` (512 MB here) should be tuned to your camera count/resolution.

## 4. Usage

```bash
docker compose up -d
docker compose logs -f frigate
```

## 5. Ports

| Port | Purpose |
|------|---------|
| `8971` | Authenticated web UI |
| `5001` | Internal unauthenticated API (expose carefully) |
| `8554` | RTSP feeds |
| `8555/tcp`, `8555/udp` | WebRTC |
