---
revision: 1
updated: 2026-10-05 17:30
---

# Traefik configuration snapshots

**Author:** TARS (Emmanuel Loaiza)

## Table of Contents

1. [What this is](#1-what-this-is)
2. [Why snapshots and not a deploy](#2-why-snapshots-and-not-a-deploy)
3. [Layout](#3-layout)
4. [How to update a snapshot](#4-how-to-update-a-snapshot)
5. [How the hosts differ](#5-how-the-hosts-differ)
6. [Safety guards](#6-safety-guards)
7. [Later: making Traefik deployable from git](#7-later-making-traefik-deployable-from-git)
8. [Revision History](#8-revision-history)

## 1. What this is

A read-only copy of the Traefik configuration that each host really runs (tars, endurance, hailmary, rocky), kept in git for history and backup. Nothing here is deployed anywhere: a snapshot never writes to a host and never restarts Traefik.

## 2. Why snapshots and not a deploy

The four hosts do not run the same Traefik files (section 5). The pipeline copies yaml files from the repo into a host's live folder, so deploying a shared Traefik folder would overwrite a host's own settings and could break it (for example it would remove hailmary's mail ports and the `172.18.0.1` allowlist entry that Uptime Kuma depends on). Until the host-specific parts are separated (section 7), Traefik stays hand-managed and git only records what is there.

## 3. Layout

`infra-snapshots/traefik/<host>/` holds, for each host: `docker-compose.yml`, `start.sh` (where it exists), `.env.example`, `.gitignore`, `scripts/*.sh`, `config/traefik.yaml`, `config/dynamic/*.yaml` (the shared middlewares and allowlists), `config/dynamic-hosts/**` (the route files of each host) and, on hailmary and rocky, an unused leftover `configs/traefik.yaml`. The older README and Docker notes are kept in `docs/` as history.

Never copied: `.env`, `certs/`, `secrets/`, `acme.json`, backup files (`*.bak*`).

## 4. How to update a snapshot

On tars, from the repo root:

```bash
scripts/snapshot-traefik.sh            # all four hosts; or: scripts/snapshot-traefik.sh hailmary
```

Then commit with `gacp "traefik snapshot: <what changed>"`. The script reads over ssh, copies only the allow-listed files, and scans the result for secret-looking values; if anything matches it deletes that host's snapshot and stops. Git shows what changed since the last snapshot, which is also a quick way to spot an unexpected edit on a host.

## 5. How the hosts differ

| Item | tars / endurance / rocky | hailmary |
|---|---|---|
| `config/traefik.yaml` | standard entry points | plus two extra entry points, `proton-imaps` (:993) and `proton-smtps` (:465), for Proton Mail Bridge |
| `docker-compose.yml` | standard | publishes ports 993 and 465 and loads `.env` as `env_file`; default syslog address `192.168.5.25` (the other three still show the retired default `192.168.5.30`; the real value may come from each host's `.env`, not checked) |
| `socketproxy-allowlist` | per host (endurance and rocky list their own clients) | includes `172.18.0.1` (Uptime Kuma reaches Traefik through the Docker bridge) |
| other allowlists | tars also has `ollama-allowlist` and `honcho-allowlist`; endurance has `honcho-allowlist` | none |
| `start.sh` | tars and endurance identical; rocky's differs | none |
| route files (`dynamic-hosts/`) | each host has its own folder | the most routes (proxmox, ha, nas, ollama, proton-bridge, ...) |

Verified by comparing the live files on 2026-10-05. Each host's `middlewares.yaml` and route files are the source of truth for that host.

## 6. Safety guards

- `.gitlab-ci.yml`: `preflight:hailmary` and `deploy:hailmary` stop with "REFUSED" when the changed project is `traefik`; the endurance jobs only accept hermes, honcho and open-webui.
- `gacp_tutorials_wcopy traefik ...` refuses, with or without a host.
- The old shared folder `docker-compose/traefik` was removed from the repo on 2026-10-05 (it was stale: it still listed retired hosts). Its history stays in git.

## 7. Later: making Traefik deployable from git

Optional, one host at a time, each needing a Traefik restart (a few seconds without web access on that host) and the owner's approval. The idea: move everything host-specific into per-host files (allowlists into `config/dynamic-hosts/<host>/`, hailmary's mail entry points and ports into a hailmary-only override), leave only identical files in a shared folder, then deploy. Not started.

## 8. Revision History

| Rev | Date | Commit | Change |
|---|---|---|---|
| 1 | 2026-10-05 17:30 | (this revision) | First snapshots of tars, endurance, hailmary and rocky; guards added; stale shared folder removed. |
