---
revision: 3
updated: 2026-10-05 15:30
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
`hermes - DISCORD_BOT_TOKEN` (optional; Discord; item type **API Key**, token in its "API Key" field). The allowed Discord user IDs are not secret and live in `.env` as `DISCORD_ALLOWED_USERS`.
Do not run `hermes setup`: it writes keys to `data/.env`.

## 3. Start, stop, update

    ./start.sh                  # start / apply changes
    docker compose logs -f
    docker compose down         # stop
    docker compose pull && ./start.sh   # update

## 4. Source, Git and Deployment

- **Source of truth:** `~/devops/docker/hermes` on **tars**. Edit there, never only on endurance.
- **Git (history and backup):** `gacp_tutorials_wcopy hermes "message"` with **no host argument** copies the compose file, `Dockerfile`, `start.sh`, `hdiag.sh`, `known_hosts.txt`, `skills/` and the README into `tutorials/docker-compose/hermes` and pushes. It never copies `data/` (config, memory, skills Hermes created, and the Claude login). Never pass `hailmary`: that would deploy Hermes onto hailmary.
- **Deploy to endurance (pipeline, since 2026-10-05):** edit on tars, then `gacp_tutorials_wcopy hermes "message" endurance`. That pushes and plays the GitLab job `deploy:endurance`, which a runner on endurance executes (`tutorials/scripts/deploy-endurance.sh`): it checks the host, saves the files it replaces in `~/devops/docker/.deploy-backups/hermes/<time>/`, installs the new files (never `data/` or `.env`), rebuilds the image if the `Dockerfile` changed, runs `./start.sh`, waits up to 3 minutes for a healthy container and restores the old files if it does not come up. The previous hand-copy (`rsync` then `./start.sh`) still works as a fallback.
- **Host settings:** create `.env` from `.env.example` (`TRAEFIK_HOST=hermes.home.elikesbikes.com`, `TRAEFIK_PORT=9119`). It holds no credentials. `.env.example` is not in git because the tutorials repo ignores dotfiles.

## 5. Revision History

| Rev | Date | Commit | Change |
|---|---|---|---|
| 3 | 2026-10-05 15:30 | (this revision) | Deployment now goes through the endurance pipeline (`gacp_tutorials_wcopy hermes "msg" endurance`); Dockerfile changes trigger an image rebuild. |
| 2 | 2026-10-02 13:40 | (this revision) | Added the git and deployment section; moved to Traefik with Authelia login and the Claude subscription plugin. |
| 1 | 2026-10-02 12:00 | (not in git) | Initial layout. |
