---
revision: 1
updated: 2026-10-02 20:20
---

# honcho (endurance)

## Table of Contents

1. [Purpose](#1-purpose)
2. [Layout](#2-layout)
3. [Install](#3-install)
4. [Revision History](#4-revision-history)

## 1. Purpose

Self-hosted Honcho memory for the Hermes agent. Models run on Ollama on tars (`honcho.env`); there are no credentials anywhere in this project. No ports are published: Hermes reaches `http://honcho-api:8000` over the `frontend` network.

## 2. Layout

`docker-compose.yml`, `honcho.env` (model/provider settings, no secrets), `src/` (Honcho checkout pinned to commit 8e4df99, not in git), `data/` (Postgres and Redis, not in git).

## 3. Install

`git clone https://github.com/plastic-labs/honcho src && git -C src checkout 8e4df99`, then `docker compose up -d --build`. `EMBEDDING_VECTOR_DIMENSIONS` (768, for nomic-embed-text) must be set before the first start.

## 4. Revision History

| Rev | Date | Commit | Change |
|---|---|---|---|
| 1 | 2026-10-02 20:20 | (this revision) | Initial project. |
