---
revision: 1
updated: 2026-10-05 19:00
---

# Traefik: desired state in git

**Author:** TARS (Emmanuel Loaiza)

## Table of Contents

1. [What this is](#1-what-this-is)
2. [Layout](#2-layout)
3. [How to change Traefik](#3-how-to-change-traefik)
4. [Rollout status per host](#4-rollout-status-per-host)
5. [Why Traefik is not deployed by the pipeline](#5-why-traefik-is-not-deployed-by-the-pipeline)
6. [Revision History](#6-revision-history)

## 1. What this is

The files Traefik should run on each host, split into what is **identical on every host** (`shared/`) and what is **specific to one host** (`hosts/<host>/`). It follows the structure the compose file already had: every host mounts the shared dynamic folder plus its own `config/dynamic-hosts/<host>/` folder. `infra-snapshots/traefik/` is the other side: a read-only copy of what each host really runs, used to spot drift.

## 2. Layout

| Path | Goes to (on the host) | Content |
|---|---|---|
| `shared/docker-compose.yml` | `docker-compose.yml` | same on all hosts; syslog default is Graylog on hailmary (`192.168.5.25`) |
| `shared/config/traefik.yaml` | `config/traefik.yaml` | static config; includes the two Proton Mail entry points (:993, :465), which are only published on hailmary |
| `shared/config/dynamic/middlewares.yaml` | `config/dynamic/middlewares.yaml` | security headers and https redirect |
| `hosts/<host>/config/dynamic-hosts/<host>/` | `config/dynamic-hosts/<host>/` | that host's route files and its `allowlists.yaml` (socket-proxy, Ollama, Honcho allowlists) |
| `hosts/hailmary/docker-compose.override.yml` | `docker-compose.override.yml` | hailmary only: ports 993 and 465, and `env_file: .env` |

Not managed here: `.env`, certificates, secrets, `start.sh`, `scripts/`. The Cloudflare token on hailmary still lives in its `.env` (tracked as a separate security item).

## 3. How to change Traefik

All from tars, in the tutorials repo:

1. Edit the file under `infra/traefik/` and run `scripts/traefik_verify_layout.py` (offline check against the snapshots: same routes, same middlewares, same rendered compose).
2. Take a baseline: `scripts/traefik_smoke.py <host> --out /tmp/<host>.before.txt` (requests every address the host serves and records the answer).
3. See what would change: `scripts/sync-traefik.sh <host>` (writes nothing).
4. Apply: `scripts/sync-traefik.sh <host> --apply` (backs up each replaced file on the host, copies, checks the compose file). Traefik keeps running the old configuration.
5. Restart on purpose: `ssh <host> 'docker restart traefik'` (a few seconds without web access on that host).
6. Check: `scripts/traefik_smoke.py <host> --compare /tmp/<host>.before.txt`, and the Traefik log for errors.
7. Refresh the snapshot (`scripts/snapshot-traefik.sh <host>`) and commit with `gacp`.

## 4. Rollout status per host

| Host | State |
|---|---|
| tars | not yet applied |
| rocky | not yet applied |
| endurance | not yet applied |
| hailmary | not yet applied (last, and only with the owner present: its Traefik is also the front door to GitLab) |

## 5. Why Traefik is not deployed by the pipeline

Restarting Traefik cuts web access for a few seconds. On hailmary that includes GitLab, so a pipeline job that restarts Traefik would cut off its own connection. The CI jobs therefore refuse the project `traefik` (and so does `gacp_tutorials_wcopy`); changes go through `sync-traefik.sh` with a deliberate restart.

## 6. Revision History

| Rev | Date | Commit | Change |
|---|---|---|---|
| 1 | 2026-10-05 19:00 | (this revision) | Desired-state layout, verifier, smoke test and sync script created; nothing applied to any host yet. |
