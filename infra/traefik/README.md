---
revision: 6
updated: 2026-10-05 16:45
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
4. Apply: `scripts/sync-traefik.sh <host> --apply` (backs up each replaced file on the host in `.sync-backups/<time>/`, copies, checks the compose file, and writes `NEW_FILES.txt` and an exact `rollback.sh` there). Traefik keeps running the old configuration.
5. Restart on purpose: `ssh <host> 'docker restart traefik'` (a few seconds without web access on that host). Use `docker restart`, never a plain `docker compose up` on tars, endurance or rocky: the Cloudflare token reaches the container only through each host's `start.sh`, so a recreate without it would break certificate renewal. The container logs go to syslog, so `docker logs` shows nothing: verify with the smoke test, the allowlist tests and Graylog.
   **On hailmary use the guarded restart instead** (its Traefik also fronts GitLab): copy `scripts/traefik-restart-guarded.sh` to the host and run it detached with the backup folder name and the expected answers, e.g. `setsid nohup ~/traefik-restart-guarded.sh <backup> gitlab.home.elikesbikes.com=302 auth.home.elikesbikes.com=200 graylog.home.elikesbikes.com=200 proxy-hailmary.home.elikesbikes.com=401 &`. It restarts Traefik, checks those addresses for up to 40 seconds and, if they do not answer as before, runs `rollback.sh`, restarts again and reports `RESULT=ROLLED_BACK_OK` (or `ROLLBACK_FAILED` if even the old files fail). Before restarting you can test the new files with a throwaway Traefik that has no network and no ports (`docker run -d --network none ...`, read its log, remove it).
   If GitLab is unreachable during an outage: `ssh -L 18080:<gitlab container ip>:80 hailmary` and use `curl -H 'Host: gitlab.home.elikesbikes.com' http://127.0.0.1:18080/api/v4/...` (the container address comes from `docker inspect gitlab`; command-line and API use verified, browser use not).
6. Check: `scripts/traefik_smoke.py <host> --compare /tmp/<host>.before.txt`, the allowlist tests from other machines (including, on hailmary, from inside a container, which reaches Traefik as the Docker bridge `172.18.0.1`), and forced MCC rechecks.
7. Refresh the snapshot (`scripts/snapshot-traefik.sh <host>`) and commit with `gacp`.

## 4. Rollout status per host

| Host | State |
|---|---|
| tars | **applied and restarted 2026-10-05 16:18**; checked: smoke test unchanged, allowlist tested from allowed and non-allowed machines, certificate unchanged |
| rocky | **applied and restarted 2026-10-05 16:22**; checked: smoke test unchanged (33 addresses), allowlist behaves as before from tars, hailmary and endurance, certificate unchanged |
| endurance | **applied and restarted 2026-10-05 16:27** (about 10 seconds without web access); checked: smoke test unchanged (5 addresses), both allowlists behave as before, chat, sign-in and Hermes login fine, MCC checks ok, 8 containers still running, certificate unchanged |
| hailmary | **applied and restarted 2026-10-05 16:40** with the guarded restart (about 12 seconds without web access, GitLab included; no rollback needed); checked: smoke test unchanged (44 addresses), socket-proxy allowlist identical from five vantage points including the Docker-bridge path used by Uptime Kuma, Ollama route, Proton mail ports 993 and 465, certificate, 55 containers still running, GitLab API and runners, MCC |

## 5. Why Traefik is not deployed by the pipeline

Restarting Traefik cuts web access for a few seconds. On hailmary that includes GitLab, so a pipeline job that restarts Traefik would cut off its own connection. The CI jobs therefore refuse the project `traefik` (and so does `gacp_tutorials_wcopy`); changes go through `sync-traefik.sh` with a deliberate restart.

## 6. Revision History

| Rev | Date | Commit | Change |
|---|---|---|---|
| 6 | 2026-10-05 16:45 | (this revision) | hailmary applied and verified; `sync-traefik.sh` now writes an exact `rollback.sh` for every apply (restores replaced files and removes created ones); guarded restart script and offline checks documented. |
| 5 | 2026-10-05 16:28 | 7c0ebb2 | endurance applied and verified. |
| 4 | 2026-10-05 16:24 | 4449ef9 | Corrected commit ids and times in this table (earlier values were not taken from git). |
| 3 | 2026-10-05 16:23 | 1b71182 | rocky applied and verified. |
| 2 | 2026-10-05 16:19 | a13bb01 | tars applied and verified; restart notes added. |
| 1 | 2026-10-05 16:10 | 98afddd | Desired-state layout, verifier, smoke test and sync script created; nothing applied to any host yet. |
