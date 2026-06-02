# Restic Backup — Docker + NFS Automation

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [File Structure](#3-file-structure)
4. [Prerequisites](#4-prerequisites)
5. [Configuration](#5-configuration)
6. [What Gets Backed Up](#6-what-gets-backed-up)
7. [NFS Mount Management](#7-nfs-mount-management)
8. [Running Backups](#8-running-backups)
9. [Automated Backup Script](#9-automated-backup-script)
10. [Pre/Post Hook Wrapper](#10-prepost-hook-wrapper)
11. [Cron Schedule](#11-cron-schedule)
12. [Notifications](#12-notifications)
13. [Logs and Status](#13-logs-and-status)
14. [Uptime Kuma](#14-uptime-kuma)
15. [Extending the Project](#15-extending-the-project)
16. [Security](#16-security)

---

## 1. Overview

This project runs [Restic](https://restic.net/) inside a single always-running Docker container that manages its own cron schedule, backup execution, and HTTP status endpoint. The repository lives on an NFS mount managed by the host.

Key features:

- Single container: crond + restic + HTTP status API, all on Alpine
- Backup schedule set via `BACKUP_CRON` in `.env` — no host cron entry needed
- Repository on NFS (`192.168.5.51`) — NFS mounting handled by the host
- Push notifications via [ntfy](https://ntfy.sh/) on success or failure
- HTTP endpoint on `:8484` for Uptime Kuma monitoring
- Daily log files and `status.json` written to `./logs/` in the project directory

---

## 2. Architecture

```
Host:
  nfs-auto-mount.sh  (host cron, every 5 min)
  └─ keeps /mnt/homenas/nfs_restic/nfs_ranger0 mounted

Container (restic — always running):
  ├─ crond              schedule from .env BACKUP_CRON (default: 13:00 daily)
  │    └─ scripts/backup.sh
  │         ├─ restic backup /data/docker-volumes /data/bind-volumes/...
  │         ├─ writes ./logs/backup-YYYY-MM-DD.log
  │         ├─ writes ./logs/status.json
  │         └─ curl ntfy on success/failure
  └─ python3 status-api/app.py
       reads  ./logs/status.json
       GET :8484/health → 200 if last success < 24h, else 503

Uptime Kuma → polls http://<host>:8484/health every 5 min
```

**NFS responsibility split:** The host's `nfs-auto-mount.sh` manages all mount operations. The container consumes the already-mounted path via the `./backup` symlink bind mount — no privileged mode needed.

---

## 3. File Structure

```
restic/
├── Dockerfile              # Custom image: Alpine + restic + python3 + crond
├── entrypoint.sh           # Container startup: installs cron, starts status API, runs crond
├── docker-compose.yml      # Single always-running service on FRONTEND network
├── .env                    # Active config (secrets + schedule) — git-ignored
├── .env.example            # Template for .env
├── restic.env.example      # Template for ~/restic.env (legacy host scripts)
├── scripts/
│   └── backup.sh           # Backup script that runs inside the container
├── status-api/
│   └── app.py              # HTTP status server (stdlib only, port 8484)
├── logs/                   # Daily logs + status.json — git-ignored, bind-mounted
├── restic-status.sh        # Host-side daily pass/fail summary (reads ./logs/)
├── nfs-auto-mount.sh       # NFS health-check and mount/unmount manager (v1.1.2)
├── nfs-unmount.sh          # Explicit NFS unmount + nfs-client reset
├── restic-backup.sh        # Legacy: host-side backup script (superseded by scripts/backup.sh)
├── restic-prepost.sh       # Legacy: NFS pre/post hook wrapper
└── backup/                 # Symlink → NFS mount (git-ignored)
```

| File | Purpose |
|------|---------|
| `Dockerfile` | Builds the container image |
| `entrypoint.sh` | Sets cron schedule from `BACKUP_CRON`, starts status API, runs crond |
| `docker-compose.yml` | Single persistent service, FRONTEND network, Graylog syslog |
| `.env` | `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `BACKUP_CRON`, `NTFY_*`, `STATUS_PORT` |
| `scripts/backup.sh` | Backup script running inside container — calls restic directly |
| `status-api/app.py` | HTTP server: 200 if last success < 24h, 503 otherwise |
| `restic-status.sh` | CLI summary table of all backup runs (reads `./logs/`) |
| `nfs-auto-mount.sh` | Mounts NFS if reachable; force-unmounts stale mounts if not |
| `nfs-unmount.sh` | Unconditionally unmounts all NFS_MOUNTS entries |
| `restic-backup.sh` | Legacy — host-side script, superseded by `scripts/backup.sh` |
| `restic-prepost.sh` | Legacy — NFS pre/post wrapper, no longer needed |

---

## 4. Prerequisites

- Docker Engine and Docker Compose v2
- `nfs-common` installed on the host (`apt install nfs-common`)
- `curl` for ntfy notifications
- Root/sudo for NFS mount operations
- NAS at `192.168.5.51` with NFS export `/mnt/PROD1/nfs_restic/nfs_ranger0`

---

## 5. Configuration

Two env files are in active use. Both contain secrets and are never committed.

### Overview of all env files

| File | Location | Loaded by | Purpose |
|------|----------|-----------|---------|
| `.env` | repo root (git-ignored) | `docker-compose.yml` | Container-side repo path and password |
| `~/restic.env` | home dir (outside repo) | `restic-backup.sh`, `restic-prepost.sh` | Host-side NFS paths, repo password, behaviour flags |
| `~/nfs-mount.env` | home dir (outside repo) | `nfs-auto-mount.sh`, `nfs-unmount.sh` | All NFS mounts on this host |

Template files in the repo (`restic.env.example`, `.env.example`) document the expected format for each.

---

### `.env` — repo root, git-ignored

Loaded by `docker-compose.yml` into the container. `RESTIC_REPOSITORY=./backup/` resolves to the `backup` symlink (→ NFS mount) via the bind mount.

```env
RESTIC_REPOSITORY=./backup/
RESTIC_PASSWORD=<your-password>

# Backup schedule (cron syntax — applied at container startup)
BACKUP_CRON=0 13 * * *

# ntfy push notifications (leave NTFY_SERVER empty to disable)
NTFY_SERVER=https://ntfy.home.elikesbikes.com
NTFY_TOPIC=backups

# HTTP status API port
STATUS_PORT=8484
```

Copy from the template: `cp .env.example .env`

**Changing the schedule:** Edit `BACKUP_CRON` then `docker compose up -d` to restart the container. The new schedule takes effect immediately.

---

### `~/restic.env` — outside repo, secrets file

Single source of truth for `restic-backup.sh` and `restic-prepost.sh`. Combines Restic credentials with NFS topology and behaviour flags.

```env
# ==================================================
# RESTIC CONFIGURATION
# ==================================================
RESTIC_REPOSITORY=/mnt/homenas/nfs_restic/nfs_ranger0/ranger0
RESTIC_PASSWORD=<your-password>

# ==================================================
# NFS CONFIGURATION (host-side)
# ==================================================
NFS_SERVER=192.168.5.51
NFS_EXPORT=/mnt/PROD1/nfs_restic/nfs_ranger0
MOUNT_POINT=/mnt/homenas/nfs_restic/nfs_ranger0

# ==================================================
# NFS REACHABILITY (used by scripts)
# ==================================================
PING_COUNT=2
PING_TIMEOUT=2

# ==================================================
# BEHAVIOUR FLAGS
# ==================================================
# Re-run NFS mount check after backup
RESTIC_POST_CHECK=true
# Unmount NFS after backup completes
RESTIC_UNMOUNT_AFTER=true
```

Copy from the template: `cp restic.env.example ~/restic.env`

Permissions: `chmod 600 ~/restic.env`

---

### `~/nfs-mount.env` — outside repo, NFS mount table

Defines all NFS mounts managed by `nfs-auto-mount.sh` and `nfs-unmount.sh`. Each entry is pipe-delimited: `server|export|mountpoint|mount-options`. The `NFS_MOUNTS` variable is a multi-line quoted string — one mount per line.

```env
# NAS connection
NAS_HOST=192.168.5.51

# NFS port / timeouts (used by TCP health check)
NFS_PORT=2049
NFS_CONNECT_TIMEOUT_SECONDS=2
UMOUNT_TIMEOUT_SECONDS=5

# All NFS mounts managed by nfs-auto-mount.sh
# Format: server|export|mountpoint|options
NFS_MOUNTS="
192.168.5.52|/mnt/PROD1/nfs_immich_server|/mnt/nfs_homeidrive/nfs_immich_server|rw,hard,timeo=600,retrans=5,noatime
192.168.5.52|/mnt/PROD1/syncthing|/mnt/nfs_homeidrive/syncthing|rw,hard,timeo=600,retrans=5,noatime
192.168.5.52|/mnt/PROD1/syncthing-ecloaiza|/mnt/nfs_homeidrive/syncthing-ecloaiza|rw,hard,timeo=600,retrans=5,noatime
192.168.5.52|/mnt/PROD1/Mac/photo_backup|/mnt/nfs_homeidrive/photo_backup|rw,hard,timeo=600,retrans=5,noatime
192.168.5.51|/mnt/PROD1/nfs_restic/nfs_ranger0|/mnt/homenas/nfs_restic/nfs_ranger0|rw,hard,timeo=600,retrans=5,noatime
192.168.5.51|/mnt/PROD1/nfs_immich_server|/mnt/homenas/nfs_immich_server|rw,hard,timeo=600,retrans=5,noatime
"
```

`nfs-auto-mount.sh` checks `~/.nfs-mount.env` first (hidden), then falls back to `~/nfs-mount.env`, then looks for `nfs-mount.env` next to the script itself. The active file on this host is `~/nfs-mount.env`.

Permissions: `chmod 600 ~/nfs-mount.env`

---

## 6. What Gets Backed Up

Backup path selection works in **two layers**. Both must agree for a path to actually be backed up.

### Layer 1 — `docker-compose.yml`: what the container can see

These volume mounts define the maximum possible scope. Restic cannot reach anything not listed here.

| Host Path | Container Path | Notes |
|-----------|---------------|-------|
| `/var/lib/docker/volumes` | `/data/docker-volumes` | All Docker named volumes, read-only |
| `/home/ecloaiza` | `/data/bind-volumes` | Entire home directory, read-only |
| *(commented out)* `/srv` | `/data/srv` | Placeholder for additional bind mounts |

The repository itself is mounted at `/backup` (the `backup` symlink → NFS mount).

### Layer 2 — `restic-backup.sh`: what actually gets passed to restic

The script builds the final list of paths passed to `restic backup` at runtime:

**Always included (hardcoded):**
```
/data/docker-volumes   ← all Docker named volumes
```

**Conditionally included (auto-detected):**

The script probes these four candidate paths inside the container and includes whichever ones exist:
```
/data/bind-volumes/docker
/data/bind-volumes/devops/docker
/data/bind-volumes/Devops/docker
/data/bind-volumes/DevOps/docker
```

These map back to subdirectories of `/home/ecloaiza` on the host. The script handles path casing variations (`devops` vs `Devops` vs `DevOps`) so it works regardless of how the directory was created.

### Effective backup scope

| What gets backed up | Host path | How selected |
|---------------------|-----------|-------------|
| All Docker named volumes | `/var/lib/docker/volumes` | Hardcoded in script |
| `~/devops/docker/` (or case variant) | `/home/ecloaiza/devops/docker` | Auto-detected at runtime |

> **Note:** `/home/ecloaiza` is fully mounted into the container, but only the `docker/` and `devops/docker/` subdirectories are probed by the script. The rest of the home directory is visible to the container but never passed to `restic backup`. To back up additional paths, add them to `CANDIDATE_BIND_PATHS` in `restic-backup.sh` — see [Section 14](#14-extending-the-project).

### To see what was actually backed up on any given run

```bash
# Check the runtime log for that day
grep -E "Including|Skipping" /var/log/restic/backup-YYYY-MM-DD.log

# Or list the latest snapshot contents
docker compose run --rm restic ls latest
```

---

## 7. NFS Mount Management

### `nfs-auto-mount.sh` (v1.1.2 — frozen/production)

Reads `NFS_MOUNTS` from the env file. For each entry:

- **NFS reachable (TCP/2049)**: mounts if not already mounted
- **NFS unreachable**: force-lazy-unmounts stale mounts to prevent hangs

Cron-safe and idempotent. Logs to `/var/log/nfs-auto-mount.log`.

```bash
# Manual run (must be root)
sudo /home/ecloaiza/devops/docker/restic/nfs-auto-mount.sh
```

### `nfs-unmount.sh`

Unconditionally unmounts all NFS_MOUNTS entries and restarts `nfs-client.target` to clear stale handles.

```bash
sudo /home/ecloaiza/devops/docker/restic/nfs-unmount.sh
```

---

## 8. Running Backups

All manual commands use `docker compose run --rm restic` as the prefix.

### Initialize the repository (first time only)

```bash
docker compose run --rm restic init
```

### Run a backup

```bash
# Back up Docker volumes only
docker compose run --rm restic backup /data/docker-volumes

# Back up home directory only
docker compose run --rm restic backup /data/bind-volumes

# Back up both in one snapshot
docker compose run --rm restic backup /data/docker-volumes /data/bind-volumes
```

### List snapshots

```bash
docker compose run --rm restic snapshots
```

### Restore a snapshot

```bash
# Restore latest snapshot
docker compose run --rm restic restore latest --target /restore

# Restore a specific snapshot by ID
docker compose run --rm restic restore <snapshot-id> --target /restore
```

### Verify repository integrity

```bash
docker compose run --rm restic check
```

### Prune old snapshots

```bash
docker compose run --rm restic forget --prune \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6
```

---

## 9. Automated Backup Script

`restic-backup.sh` is the main entry point for cron/systemd-scheduled backups.

**What it does:**

1. Validates dependencies (`nfs-auto-mount.sh`, `~/restic.env`)
2. Runs `nfs-auto-mount.sh` to ensure the NFS repository is mounted
3. Auto-detects the compose directory (handles case variations in path)
4. Probes candidate bind-mount paths inside the container to build the backup path list dynamically
5. Initialises the Restic repository if it doesn't exist yet
6. Runs `restic backup` with all detected paths
7. Sends an ntfy push notification on success or failure

**Usage:**

```bash
# Run manually (must be root for NFS mounts)
sudo /home/ecloaiza/devops/docker/restic/restic-backup.sh
```

**Cron example** (daily at 02:00):

```cron
0 2 * * * root /home/ecloaiza/devops/docker/restic/restic-backup.sh
```

---

## 10. Pre/Post Hook Wrapper

`restic-prepost.sh` wraps any command with NFS pre/post hooks. Use it for one-off or ad-hoc runs where you want NFS mount/unmount managed automatically.

```bash
# Syntax
sudo restic-prepost.sh <command> [args...]

# Examples
sudo /home/ecloaiza/devops/docker/restic/restic-prepost.sh \
  docker compose -f /home/ecloaiza/devops/docker/restic/docker-compose.yml \
  run --rm restic snapshots

sudo /home/ecloaiza/devops/docker/restic/restic-prepost.sh \
  restic -r /mnt/homenas/nfs_restic/nfs_ranger0 check
```

Set `RESTIC_UNMOUNT_AFTER=true` in `~/restic.env` to unmount after the command completes.

---

## 11. Cron Schedule

The backup cron runs **inside the container** — no host cron entry is needed for the backup itself. The schedule is set by `BACKUP_CRON` in `.env` and applied at container startup by `entrypoint.sh`.

Current schedule: **daily at 13:00** (`0 13 * * *`)

To change it, edit `.env` and restart:
```bash
# Edit .env: BACKUP_CRON=0 3 * * *
docker compose up -d
# Verify:
docker compose exec restic cat /etc/crontabs/root
```

### Host cron — NFS health check only

The only host cron entry needed is for NFS mount management:

```cron
# NFS: health check every 5 minutes (run as root)
*/5 * * * * /home/ecloaiza/devops/docker/restic/nfs-auto-mount.sh >> /var/log/nfs-auto-mount.log 2>&1
```

### Prune snapshots (manual or add to container cron)

```bash
docker compose exec restic restic forget --prune \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6
```

---

## 12. Notifications

Push notifications are sent to the ntfy server at `https://ntfy.home.elikesbikes.com` on the `backups` topic.

| Event | Message |
|-------|---------|
| Backup completed | `✅ [hostname] Restic backup completed successfully` |
| Any failure | `❌ [hostname] <error description>` |

---

## 13. Logs and Status

### Log files (in `./logs/`, bind-mounted into container)

| File | Written by | Contents |
|------|-----------|----------|
| `./logs/backup-YYYY-MM-DD.log` | `scripts/backup.sh` | Full run output per day |
| `./logs/status.json` | `scripts/backup.sh` | Latest run result (JSON) |
| `./logs/cron.log` | crond inside container | Cron execution output |
| `/var/log/nfs-auto-mount.log` | `nfs-auto-mount.sh` | NFS mount/unmount events |

### `status.json` format

Written after every run. The HTTP status API reads this file.

```json
{
  "status": "ok",
  "last_success_time": "2026-06-02T19:53:55",
  "snapshot_id": "832248dc",
  "files_processed": 9048,
  "data_added": "1.072 GiB",
  "duration": "0:34",
  "hostname": "restic",
  "updated_at": "2026-06-02T19:53:55"
}
```

On failure, `status` is `"fail"` and `last_success_time` is preserved from the previous run.

### `restic-status.sh` — CLI history summary

Prints a one-line-per-day pass/fail table across all log files.

```bash
./restic-status.sh           # all runs
./restic-status.sh -n 30     # last 30 days
./restic-status.sh -f        # failures only
./restic-status.sh -n 30 -f  # last 30 days, failures only
```

```
DATE          STATUS    SNAPSHOT    FILES         ADDED  TIME     NOTE
--------------------------------------------------------------------------------
2026-06-02    ✅ OK     832248dc     9048     1.072 GiB  0:34
2026-06-01    ✅ OK     b6a30b2e     9025     1.031 GiB  0:35
2026-05-07    ❌ FAIL   -               -             -  -        Stale file handle
--------------------------------------------------------------------------------
Total: 173 runs  |  ✅ 143 succeeded  |  ❌ 30 failed
```

---

## 14. Uptime Kuma

The container exposes a health endpoint on port `8484` for Uptime Kuma to poll.

### Endpoint

```
GET http://<host-ip>:8484/health
```

| Response | Meaning |
|----------|---------|
| `200 OK` + JSON | Last backup succeeded within 24 hours |
| `503 Service Unavailable` + JSON | Last success > 24h ago, or no backup has run yet |

### Uptime Kuma monitor setup

1. In Uptime Kuma → **Add New Monitor**
2. Type: **HTTP(s)**
3. URL: `http://<host-ip>:8484/health`
4. Heartbeat interval: **5 minutes**
5. Expected status code: **200**
6. Timeout: **10s**

Uptime Kuma will show **DOWN** whenever the container returns 503 — meaning restic hasn't completed a successful backup in more than 24 hours.

### Manual check

```bash
curl http://localhost:8484/health
```

---

## 15. Extending the Project

### Add more paths to back up

Add a read-only volume mount to `docker-compose.yml`:

```yaml
volumes:
  - /srv:/data/srv:ro
```

Then add the candidate path to `CANDIDATE_BIND_PATHS` in `app/scripts/backup.sh`. No rebuild needed — the script is bind-mounted.

### Add a retention policy

Add a `restic forget --prune` call at the end of `app/scripts/backup.sh` after the backup completes. No rebuild needed.

### Change the backup schedule

Edit `BACKUP_CRON` in `.env`, then `docker compose up -d`. The new schedule is applied at container startup.

### Switch NFS export or server

Update the `backup` symlink to point to the new NFS mount point. Update `~/nfs-mount.env` entries accordingly. Restart the container.

---

## 16. Security

> **The `.env` file contains the Restic repository password in plaintext.**

- `.env` and `backup/` are in `.gitignore` — never commit them.
- `~/restic.env` and `~/nfs-mount.env` live outside the repo and should be readable only by root: `chmod 600 ~/restic.env ~/nfs-mount.env`.
- Rotate the Restic password with `restic key passwd` if the file is ever exposed.
- Consider Docker secrets or a secrets manager (Vault, Bitwarden CLI) for production hardening.
