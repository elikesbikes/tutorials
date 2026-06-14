# Restic Backup — Docker + NFS

Restic running in a persistent Docker container with multiple independently scheduled backup jobs, an HTTP health endpoint, and host-managed NFS mounting.

## Docker Image

Published on Docker Hub (multi-arch — `linux/amd64` + `linux/arm64`):

```bash
docker pull ecloaiza/restic-backup:latest
```

The image contains only the application code (`app/`). All configuration —
`.env`, `jobs/*.conf`, data-source mounts, and the `backup` repository — is
provided at runtime via bind mounts and `env_file`, so **no secrets are baked
into the image**. See [Setup](#4-setup) for the required mounts and config.

## Table of Contents

1. [Architecture](#1-architecture)
2. [File Structure](#2-file-structure)
3. [Prerequisites](#3-prerequisites)
4. [Setup](#4-setup)
5. [Configuration](#5-configuration)
6. [Common Commands](#6-common-commands)
7. [Health Endpoint](#7-health-endpoint)
8. [Security](#8-security)

---

## 1. Architecture

```
Host
└── nfs-auto-mount.sh  (root cron, every 5 min)
    └── keeps NFS mount alive at /mnt/homenas/nfs_restic/<hostname>

Container (always running)
├── crond             → one crontab line per job conf in jobs/*.conf
│   └── backup.sh <job.conf> → restic backup --tag <job> → logs/status/<job>.json → ntfy
│       └── cleanup.sh <job.conf> → restic forget --tag <job> (per-job retention)
└── status-api/app.py → GET :8484/health (200 if ALL jobs fresh / 503 if any stale)

Uptime Kuma → polls :8484/health every 5 min
```

**Jobs** — each `jobs/<name>.conf` declares its own schedule, source paths, and optional retention/notification overrides. All jobs share one restic repository: snapshots are tagged with the job name and retention is applied per tag, so jobs never delete each other's snapshots. Concurrent jobs serialize via a repository lock (queue, 2h timeout).

**`./backup` symlink** points to the NFS mount point (git-ignored). The container never touches NFS directly — the host mounts it, the container reads it.

**Host-specific files (never synced between hosts):** `.env`, `jobs/*.conf`, `docker-compose.override.yml` (data-source mounts), the `backup` symlink, and `logs/`. Everything else is identical across hosts.

---

## 2. File Structure

```
restic/
├── Dockerfile                       # Alpine + restic + python3 + crond + flock
├── docker-compose.yml               # Host-generic service definition
├── docker-compose.override.yml      # HOST-SPECIFIC data-source mounts (git-ignored)
├── docker-compose.override.yml.example
├── .env                             # Secrets + defaults (git-ignored)
├── .env.example
├── jobs/                            # One .conf per backup job (host-specific)
│   ├── docker-volumes.conf          # Default job — schedule + sources
│   └── example.conf.example         # Job format reference
├── app/
│   ├── entrypoint.sh                # Validates jobs, installs crontab, starts API + crond
│   ├── scripts/backup.sh            # backup.sh <job.conf> — one run per job
│   ├── scripts/cleanup.sh           # cleanup.sh <job.conf> — per-tag retention
│   └── status-api/app.py            # HTTP status server on :8484
├── host/
│   ├── nfs-auto-mount.sh            # Mounts/unmounts NFS (v1.2.0)
│   ├── nfs-unmount.sh               # Manual unconditional unmount
│   └── restic-status.sh             # CLI pass/fail history per job from ./logs/
├── backup/                          # Symlink → NFS mount (git-ignored)
└── logs/                            # Bind-mounted into container (git-ignored)
    └── status/<job>.json            # Per-job status read by the health endpoint
```

---

## 3. Prerequisites

- Docker + Docker Compose
- `nfs-common` installed on the host (`sudo apt install nfs-common`)
- NFS share accessible at `192.168.5.51:/mnt/PROD1/nfs_restic/<hostname>` with `chmod 777`
- `frontend` Docker network already exists on the host

---

## 4. Setup

```bash
# 1. NFS symlink
ln -s /mnt/homenas/nfs_restic/<hostname> ./backup

# 2. Config
cp .env.example .env                  # fill in RESTIC_PASSWORD + defaults
cp docker-compose.override.yml.example docker-compose.override.yml  # this host's data mounts
cp jobs/example.conf.example jobs/<name>.conf                       # define at least one job

# 3. NFS env (outside repo, permissions 600)
# ~/nfs-mount.env — see Configuration below

# 4. Root cron — NFS health check
*/5 * * * * /home/ecloaiza/devops/docker/restic/host/nfs-auto-mount.sh >/dev/null 2>&1

# 5. Mount NFS and start
sudo host/nfs-auto-mount.sh
docker compose pull && docker compose up -d   # pull the published image (recommended)
# — or build from source instead of pulling (for local development):
# docker compose up -d --build

# 6. Init repo (first time only)
docker compose exec restic restic init
```

See [INSTALL.md](INSTALL.md) for full step-by-step instructions.

---

## 5. Configuration

### Jobs (`jobs/<name>.conf`, host-specific)

Each backup job is one conf file — schedule, sources, and optional overrides:

```sh
JOB_NAME="docker-volumes"   # must equal filename stem; [A-Za-z0-9_-] only
JOB_CRON="0 13 * * *"       # 5-field cron (BusyBox crond — no @daily)
JOB_SOURCES="/data/docker-volumes /data/bind-volumes/devops/docker"
# Optional (fall back to .env defaults):
# JOB_KEEP_DAILY=7  JOB_KEEP_WEEKLY=4  JOB_KEEP_MONTHLY=6
# JOB_NTFY_SERVER=...  JOB_NTFY_TOPIC=...
# JOB_MAX_AGE_HOURS=25      # /health staleness threshold (weekly job → ~170)
```

**Adding a job:**
1. Copy `jobs/example.conf.example` to `jobs/<name>.conf` and edit it
2. Mount the source directory in `docker-compose.override.yml`: `- /host/path:/data/<name>:ro`
3. `docker compose up -d` — the entrypoint installs one crontab line per job

Snapshots are tagged with the job name in the shared repository; retention applies per tag, so jobs never touch each other's snapshots.

### `.env` (repo root, git-ignored)

```env
CONTAINER_HOSTNAME=<hostname>
RESTIC_REPOSITORY=./backup/
RESTIC_PASSWORD=<your-password>
NTFY_SERVER=https://ntfy.home.elikesbikes.com   # default, overridable per job
NTFY_TOPIC=backups
STATUS_PORT=8484
KEEP_DAILY=7      # default retention, overridable per job via JOB_KEEP_*
KEEP_WEEKLY=4
KEEP_MONTHLY=6
```

### `docker-compose.override.yml` (host-specific, git-ignored)

Holds this host's data-source mounts so `docker-compose.yml` stays identical across hosts. Convention: mount each directory read-only at `/data/<name>` and reference that path in `JOB_SOURCES`.

### `~/nfs-mount.env` (outside repo, chmod 600)

```env
NFS_MOUNTS="
192.168.5.51|/mnt/PROD1/nfs_restic/<hostname>|/mnt/homenas/nfs_restic/<hostname>|rw,hard,timeo=600,retrans=5,noatime
"
NFS_PORT=2049
NFS_CONNECT_TIMEOUT_SECONDS=2
UMOUNT_TIMEOUT_SECONDS=30
```

---

## 6. Common Commands

```bash
# Trigger a job manually
docker compose exec restic /app/scripts/backup.sh /app/jobs/docker-volumes.conf

# Check health (all jobs)
curl http://localhost:8484/health

# Show installed schedules
docker compose exec restic cat /etc/crontabs/root

# List snapshots (all / one job)
docker compose exec restic restic snapshots
docker compose exec restic restic snapshots --tag docker-volumes

# Restore latest snapshot of a job
docker compose exec restic restic restore latest --tag docker-volumes --target /restore

# Backup history (host-side, per job)
./host/restic-status.sh
./host/restic-status.sh -n 30 -f   # last 30 entries, failures only

# NFS logs
tail -f /var/log/nfs-auto-mount.log

# Manual cleanup for one job (apply retention policy and prune)
docker compose exec restic /app/scripts/cleanup.sh /app/jobs/docker-volumes.conf

# Cleanup dry-run — ALWAYS include --tag and --group-by host,tags so other
# jobs' snapshots are never deletion candidates
docker compose exec restic sh -c 'cd / && restic forget --tag docker-volumes \
  --group-by host,tags --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --dry-run'
```

---

## 7. Health Endpoint

`GET :8484/health` — returns `200` only if **every** job's last success is within that job's `JOB_MAX_AGE_HOURS` (default 25h), `503` otherwise. The body always lists per-job detail, so one Uptime Kuma monitor covers all jobs and the JSON says which job is unhealthy.

```json
{
  "healthy": true,
  "jobs": {
    "docker-volumes": {
      "status": "ok",
      "job": "docker-volumes",
      "last_success_time": "2026-06-10T17:21:15",
      "snapshot_id": "9de3ed6f",
      "files_processed": 32784,
      "data_added": "26.706 MiB",
      "duration": "0:02",
      "max_age_hours": 25,
      "age_hours": 1.2,
      "healthy": true
    }
  }
}
```

---

## 8. Security

- `.env` and `backup/` are git-ignored — never commit them
- `~/nfs-mount.env` should be `chmod 600`
- Rotate the repo password: `docker compose exec restic restic key passwd`

Author Cooper

<!-- pipeline test: 2026-06-14 -->
