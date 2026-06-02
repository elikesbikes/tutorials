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
11. [Cron Jobs](#11-cron-jobs)
12. [Notifications](#12-notifications)
13. [Logs](#13-logs)
14. [Extending the Project](#14-extending-the-project)
15. [Security](#15-security)

---

## 1. Overview

This project runs [Restic](https://restic.net/) as a one-shot Docker container to back up Docker volumes and the user home directory to an NFS-backed repository on a local NAS. The container is not a daemon — it is invoked manually or via cron/systemd to run a single Restic command and exit.

Key features:

- Restic runs fully containerised via Docker Compose
- Repository lives on NFS (`192.168.5.51`) — no local disk dependency
- NFS mounts are managed automatically before/after each backup
- Stale/unreachable NFS mounts are detected and safely detached
- Push notifications via [ntfy](https://ntfy.sh/) on success or failure
- Structured daily log files under `/var/log/restic/`

---

## 2. Architecture

```
cron / systemd
      │
      ▼
restic-backup.sh          ← main entry point
  │
  ├─ nfs-auto-mount.sh    ← ensure NFS is mounted (pre-hook)
  │
  ├─ docker compose run --rm restic backup ...
  │       └─ restic/restic:latest container
  │               ├── /data/docker-volumes  (host: /var/lib/docker/volumes)
  │               ├── /data/bind-volumes    (host: /home/ecloaiza)
  │               └── /backup              (host: NFS mount → NAS)
  │
  └─ ntfy notification (success / failure)
```

`restic-prepost.sh` is an alternative wrapper for running arbitrary commands with NFS pre/post hooks. Use it for one-off runs or to wrap other tools that need the NFS mount available.

---

## 3. File Structure

```
restic/
├── docker-compose.yml      # Container definition, volume mounts
├── .env                    # Active Restic config (container paths + password) — git-ignored
├── .env.example            # Template for .env
├── restic.env.example      # Template for ~/restic.env (host-side config + secrets)
├── restic-backup.sh        # Main automated backup script
├── restic-prepost.sh       # Pre/post NFS hook wrapper for arbitrary commands
├── nfs-auto-mount.sh       # NFS health-check and mount/unmount manager (v1.1.2)
├── nfs-unmount.sh          # Explicit NFS unmount + nfs-client reset
└── backup/                 # Symlink → NFS mount (git-ignored)
```

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Defines the restic container, mounts, and entrypoint |
| `.env` | Container-side `RESTIC_REPOSITORY` and `RESTIC_PASSWORD` — loaded by docker-compose |
| `.env.example` | Template for `.env` |
| `restic.env.example` | Template for `~/restic.env` (host-side paths, NFS config, secrets) |
| `restic-backup.sh` | Full automation: NFS pre-hook → backup → ntfy notification |
| `restic-prepost.sh` | Wraps any command with NFS mount pre/post hooks |
| `nfs-auto-mount.sh` | Mounts NFS if reachable; force-unmounts stale mounts if not |
| `nfs-unmount.sh` | Unconditionally unmounts all NFS_MOUNTS entries |

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

Loaded by `docker-compose.yml` into the container. `RESTIC_REPOSITORY` uses `./backup/` — a relative path that resolves to the `backup` symlink in the repo directory, which points to the NFS mount. This is intentionally different from the host-side path in `~/restic.env`.

```env
RESTIC_REPOSITORY=./backup/
RESTIC_PASSWORD=<your-password>
```

Copy from the template: `cp .env.example .env`

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

| Host Path | Container Path | Notes |
|-----------|---------------|-------|
| `/var/lib/docker/volumes` | `/data/docker-volumes` | All Docker named volumes, read-only |
| `/home/ecloaiza` | `/data/bind-volumes` | User home directory, read-only |
| *(commented out)* `/srv` | `/data/srv` | Placeholder for additional bind mounts |

The Restic repository is mounted at `/backup` inside the container, mapped from the NFS mount on the host.

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

## 11. Cron Jobs

All cron entries run as **root** (required for NFS mount operations). Add them with `sudo crontab -e`.

### Backup job — daily at 02:00

```cron
0 2 * * * /home/ecloaiza/devops/docker/restic/restic-backup.sh >> /var/log/restic/cron.log 2>&1
```

### Prune job — weekly on Sunday at 03:00

Keeps a rolling retention window. Adjust counts to match your storage budget.

```cron
0 3 * * 0 docker compose -f /home/ecloaiza/devops/docker/restic/docker-compose.yml \
  run --rm restic forget --prune \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  >> /var/log/restic/prune.log 2>&1
```

### NFS health check — every 5 minutes (optional)

Keeps mounts fresh and clears stale ones without waiting for the next backup. Idempotent — safe to run frequently.

```cron
*/5 * * * * /home/ecloaiza/devops/docker/restic/nfs-auto-mount.sh >> /var/log/nfs-auto-mount.log 2>&1
```

### Full root crontab example

```cron
# Restic: daily backup at 02:00
0 2 * * * /home/ecloaiza/devops/docker/restic/restic-backup.sh >> /var/log/restic/cron.log 2>&1

# Restic: weekly prune Sunday 03:00
0 3 * * 0 docker compose -f /home/ecloaiza/devops/docker/restic/docker-compose.yml run --rm restic forget --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 6 >> /var/log/restic/prune.log 2>&1

# NFS: health check every 5 minutes
*/5 * * * * /home/ecloaiza/devops/docker/restic/nfs-auto-mount.sh >> /var/log/nfs-auto-mount.log 2>&1
```

### Create the log directory

```bash
sudo mkdir -p /var/log/restic
```

---

## 12. Notifications

Push notifications are sent to the ntfy server at `https://ntfy.home.elikesbikes.com` on the `backups` topic.

| Event | Message |
|-------|---------|
| Backup completed | `✅ [hostname] Restic backup completed successfully` |
| Any failure | `❌ [hostname] <error description>` |

---

## 13. Logs

| Log file | Written by |
|----------|-----------|
| `/var/log/restic/backup-YYYY-MM-DD.log` | `restic-backup.sh` |
| `/var/log/nfs-auto-mount.log` | `nfs-auto-mount.sh` |

---

## 14. Extending the Project

### Add more paths to back up

Add a read-only volume mount to `docker-compose.yml`:

```yaml
volumes:
  - /srv:/data/srv:ro
```

Then add the candidate path to `CANDIDATE_BIND_PATHS` in `restic-backup.sh`, or pass it explicitly in the `docker compose run` command.

### Add a retention policy to the automated script

Append a `restic forget --prune` step after the `restic backup` call in `restic-backup.sh`.

### Switch NFS export or server

Update `NFS_SERVER`, `NFS_EXPORT`, and `MOUNT_POINT` in `~/restic.env` and `~/.nfs-mount.env` (`NFS_MOUNTS`). The new target will be picked up on the next run.

---

## 15. Security

> **The `.env` file contains the Restic repository password in plaintext.**

- `.env` and `backup/` are in `.gitignore` — never commit them.
- `~/restic.env` and `~/nfs-mount.env` live outside the repo and should be readable only by root: `chmod 600 ~/restic.env ~/nfs-mount.env`.
- Rotate the Restic password with `restic key passwd` if the file is ever exposed.
- Consider Docker secrets or a secrets manager (Vault, Bitwarden CLI) for production hardening.
