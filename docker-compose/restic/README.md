# Restic Backup — Docker + NFS

Restic running in a persistent Docker container with container-managed cron, an HTTP health endpoint, and host-managed NFS mounting.

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
├── crond            → runs backup.sh on BACKUP_CRON schedule
│   └── backup.sh   → restic backup → logs/status.json → ntfy
└── status-api/app.py → GET :8484/health (200 ok / 503 stale)

Uptime Kuma → polls :8484/health every 5 min
```

**`./backup` symlink** points to the NFS mount point (git-ignored). The container never touches NFS directly — the host mounts it, the container reads it.

---

## 2. File Structure

```
restic/
├── Dockerfile              # Alpine + restic + python3 + crond
├── docker-compose.yml      # Single persistent service, frontend network
├── .env                    # Secrets + schedule (git-ignored)
├── .env.example
├── app/
│   ├── entrypoint.sh       # Installs cron, starts status API, runs crond
│   ├── scripts/backup.sh   # Runs inside container — calls restic directly
│   └── status-api/app.py   # HTTP status server on :8484
├── host/
│   ├── nfs-auto-mount.sh   # Mounts/unmounts NFS (v1.2.0)
│   ├── nfs-unmount.sh      # Manual unconditional unmount
│   └── restic-status.sh    # CLI pass/fail history from ./logs/
├── backup/                 # Symlink → NFS mount (git-ignored)
└── logs/                   # Bind-mounted into container (git-ignored)
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
cp .env.example .env  # fill in RESTIC_PASSWORD and BACKUP_CRON

# 3. NFS env (outside repo, permissions 600)
# ~/nfs-mount.env — see Configuration below

# 4. Root cron — NFS health check
*/5 * * * * /home/ecloaiza/devops/docker/restic/host/nfs-auto-mount.sh >/dev/null 2>&1

# 5. Mount NFS and start
sudo host/nfs-auto-mount.sh
docker compose up -d --build

# 6. Init repo (first time only)
docker compose exec restic restic init
```

See [INSTALL.md](INSTALL.md) for full step-by-step instructions.

---

## 5. Configuration

### `.env` (repo root, git-ignored)

```env
RESTIC_REPOSITORY=./backup/
RESTIC_PASSWORD=<your-password>
BACKUP_CRON=0 12 * * *
NTFY_SERVER=https://ntfy.home.elikesbikes.com
NTFY_TOPIC=backups
STATUS_PORT=8484
```

Change `BACKUP_CRON` and run `docker compose up -d` to apply.

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
# Trigger backup manually
docker compose exec restic /app/scripts/backup.sh

# Check health
curl http://localhost:8484/health

# List snapshots
docker compose exec restic restic snapshots

# Restore latest
docker compose exec restic restic restore latest --target /restore

# Prune old snapshots
docker compose exec restic restic forget --prune \
  --keep-daily 7 --keep-weekly 4 --keep-monthly 6

# Backup history (host-side)
./host/restic-status.sh
./host/restic-status.sh -n 30 -f   # last 30 days, failures only

# NFS logs
tail -f /var/log/nfs-auto-mount.log
```

---

## 7. Health Endpoint

`GET :8484/health` — returns `200` if last backup succeeded within 24h, `503` otherwise.

```json
{
  "healthy": true,
  "last_success_time": "2026-06-03T21:29:16",
  "snapshot_id": "34554c14",
  "files_processed": 8456,
  "data_added": "9.689 GiB",
  "duration": "2:38"
}
```

---

## 8. Security

- `.env` and `backup/` are git-ignored — never commit them
- `~/nfs-mount.env` should be `chmod 600`
- Rotate the repo password: `docker compose exec restic restic key passwd`
