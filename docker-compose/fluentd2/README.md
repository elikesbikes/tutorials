# Fluentd2 (ARM build)

Custom [Fluentd](https://www.fluentd.org/) log-collector image built for ARM (arm32v7) via QEMU cross-build.

## Table of Contents

1. [Overview](#1-overview)
2. [What's Here](#2-whats-here)
3. [Building](#3-building)
4. [Running](#4-running)
5. [Notes](#5-notes)

## 1. Overview

This directory holds a `Dockerfile` that builds Fluentd 1.16.2 on a Ruby 3.1 slim (arm32v7) base, using a `golang:alpine` builder stage to fetch the Balena QEMU static binary for cross-architecture builds. jemalloc and tini are compiled/installed for stability. See the sibling `fluentd/` project for the standard build and full documentation.

## 2. What's Here

| File | Purpose |
|------|---------|
| `dockerfile` | Multi-stage ARM Fluentd image definition |

The Fluentd config (`fluent.conf`) and `entrypoint.sh` are expected at build context root — see the sibling `fluentd/` directory.

## 3. Building

```bash
docker build -f dockerfile -t fluentd-arm:1.16.2 .
```

## 4. Running

```bash
docker run -d -p 24224:24224 -p 5140:5140 fluentd-arm:1.16.2
```

Exposed ports: `24224` (forward), `5140` (syslog).

## 5. Notes

- Base image `arm32v7/ruby:3.1-slim-bullseye` targets 32-bit ARM (e.g. Raspberry Pi).
- The `LD_PRELOAD` jemalloc tweak disables `MADV_FREE` to reduce memory usage.
