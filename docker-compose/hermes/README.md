---
revision: 2
updated: 2026-10-02 13:40
---

# Hermes on endurance

Hermes Agent (Nous Research) running in Docker on endurance: an orchestrator that works alongside IT operations.

## Table of Contents

1. [Layout](#1-layout)
2. [Secrets](#2-secrets)
3. [Start, stop, update](#3-start-stop-update)
4. [Source, Git and Deployment](#4-source-git-and-deployment)
5. [Revision History](#5-revision-history)

## 1. Layout

| Path | What |
|---|---|
| `docker-compose.yml` | the container (image `nousresearch/hermes-agent`), logs to Graylog |
| `start.sh` | fetches secrets from Proton Pass and runs `docker compose up -d` |
| `data/` | everything Hermes keeps (config, database, memory, skills); mounted at `/opt/data`; not in git |

## 2. Secrets

No `.env` file. `start.sh` logs in with endurance's own vTPM-sealed PAT and exports these from the `HOMELAB` vault:
`hermes - DISCORD_BOT_TOKEN` (optional; Discord). The allowed Discord user IDs are not secret and live in `.env` as `DISCORD_ALLOWED_USERS`.
Do not run `hermes setup`: it writes keys to `data/.env`.

## 3. Start, stop, update

    ./start.sh                  # start / apply changes
    docker compose logs -f
    docker compose down         # stop
    docker compose pull && ./start.sh   # update

## 4. Source, Git and Deployment

- **Source of truth:** `~/devops/docker/hermes` on **tars**. Edit there, never only on endurance.
- **Git (history and backup only):** `gacp_tutorials_wcopy hermes "message"` with **no host argument**. It copies the compose file, `Dockerfile`, `start.sh` and the README into `tutorials/docker-compose/hermes`. It never copies `data/` (config, memory, skills and the Claude login). Never pass `hailmary`: that would deploy Hermes onto hailmary.
- **Deploy to endurance (manual for now):** `rsync -a --exclude data/ --exclude .env ~/devops/docker/hermes/ endurance:devops/docker/hermes/`, then on endurance `docker compose build --pull && ./start.sh`. A pipeline for endurance is planned (see the vault note for endurance).
- **Host settings:** create `.env` from `.env.example` (`TRAEFIK_HOST=hermes.home.elikesbikes.com`, `TRAEFIK_PORT=9119`). It holds no credentials. `.env.example` is not in git because the tutorials repo ignores dotfiles.

## 5. Revision History

| Rev | Date | Commit | Change |
|---|---|---|---|
| 2 | 2026-10-02 13:40 | (this revision) | Added the git and deployment section; moved to Traefik with Authelia login and the Claude subscription plugin. |
| 1 | 2026-10-02 12:00 | (not in git) | Initial layout. |
