---
revision: 1
updated: 2026-10-02 12:00
---

# Hermes on endurance

Hermes Agent (Nous Research) running in Docker on endurance: an orchestrator that works alongside IT operations.

## Table of Contents

1. [Layout](#1-layout)
2. [Secrets](#2-secrets)
3. [Start, stop, update](#3-start-stop-update)
4. [Revision History](#4-revision-history)

## 1. Layout

| Path | What |
|---|---|
| `docker-compose.yml` | the container (image `nousresearch/hermes-agent`), logs to Graylog |
| `start.sh` | fetches secrets from Proton Pass and runs `docker compose up -d` |
| `data/` | everything Hermes keeps (config, database, memory, skills); mounted at `/opt/data`; not in git |

## 2. Secrets

No `.env` file. `start.sh` logs in with endurance's own vTPM-sealed PAT and exports these from the `HOMELAB` vault:
`hermes - DISCORD_BOT_TOKEN` and `hermes - DISCORD_ALLOWED_USERS` (optional).
Do not run `hermes setup`: it writes keys to `data/.env`.

## 3. Start, stop, update

    ./start.sh                  # start / apply changes
    docker compose logs -f
    docker compose down         # stop
    docker compose pull && ./start.sh   # update

## 4. Revision History

| Rev | Date | Commit | Change |
|---|---|---|---|
| 1 | 2026-10-02 12:00 | (not in git yet) | Initial layout. |
