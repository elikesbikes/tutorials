# Restic Backup — Docker Project

## 1. Overview

This project runs [Restic](https://restic.net/) as a one-shot Docker container to back up Docker volumes and the user home directory. The container is not a daemon — it is invoked manually (or via cron/systemd) to run a single Restic command and then exit.

The current setup stores the repository locally at `./backup/`. A separate env file (`restic-backup.env`) captures the NFS configuration for migrating the repository to a remote NAS.

---

## 2. File Structure

```
restic/
├── docker-compose.yml     # Container definition and volume mounts
├── .env                   # Active Restic config (repo path + password)
├── restic-backup.env      # NFS remote repository config (future use)
└── backup/                # Local Restic repository (created after init)
```

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Defines the restic container, mounts, and entrypoint |
| `.env` | Sets `RESTIC_REPOSITORY` and `RESTIC_PASSWORD` for the active repo |
| `restic-backup.env` | NFS server/export/mount details for switching to remote storage |

---

## 3. What Gets Backed Up

| Source Path (host) | Mount Inside Container | Notes |
|--------------------|------------------------|-------|
| `/var/lib/docker/volumes` | `/data/docker-volumes` | All Docker named volumes, read-only |
| `/home/ecloaiza` | `/data/bind-volumes` | User home directory, read-only |
| *(commented out)* `/srv` | `/data/srv` | Placeholder for future bind mounts |

The Restic repository itself is mounted at `/backup` (mapped from `./backup/` on the host).

---

## 4. Running Backup Commands

All commands use `docker compose run --rm restic` as the prefix. The container exits after each command.

### Initialize the repository (first time only)

```bash
docker compose run --rm restic init
```

### Run a backup

```bash
# Back up Docker volumes
docker compose run --rm restic backup /data/docker-volumes

# Back up home directory
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
# Restore latest snapshot to a target directory
docker compose run --rm restic restore latest --target /restore

# Restore a specific snapshot by ID
docker compose run --rm restic restore <snapshot-id> --target /restore
```

### Verify repository integrity

```bash
docker compose run --rm restic check
```

### Prune old snapshots (example: keep last 7 daily, 4 weekly, 6 monthly)

```bash
docker compose run --rm restic forget --prune \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6
```

---

## 5. NFS Remote Repository (Future)

`restic-backup.env` contains the configuration for mounting the Restic repository from a NAS over NFS instead of storing it locally:

| Variable | Value |
|----------|-------|
| `NFS_SERVER` | `192.168.5.51` |
| `NFS_EXPORT` | `/mnt/PROD1/nfs_restic/nfs_ranger0` |
| `MOUNT_POINT` | `/mnt/homenas/nfs_restic/nfs_ranger0` |
| `SYMLINK_NAME` | `backup` |

To switch to NFS storage:
1. Mount the NFS export on the host at `MOUNT_POINT`.
2. Create a symlink: `ln -s $MOUNT_POINT backup` (or update `RESTIC_REPOSITORY` in `.env` to point to the mount).
3. Initialize the repository on the NFS path with `restic init`.

---

## 6. Extending the Project

### Add more paths to back up

Edit `docker-compose.yml` and add a new read-only volume mount:

```yaml
volumes:
  - /srv:/data/srv:ro
```

Then include `/data/srv` in the `restic backup` command.

### Add a second container for scheduled backups

Consider pairing this with a cron-based container (e.g., `ofelia`, `supercronic`, or a host-level systemd timer) that calls the same `docker compose run` commands on a schedule.

---

## 7. Security Warning

> **The `.env` file contains the Restic repository password in plaintext.**

This is a security risk if the file is committed to version control or shared. Recommended mitigations:

- Add `.env` to `.gitignore` immediately.
- Consider using Docker secrets, a secrets manager (Vault, Bitwarden CLI), or environment variable injection at runtime instead of a plaintext file.
- Rotate the password with `restic key passwd` after securing the secret.

---

## 8. Prerequisites

- Docker and Docker Compose installed on the host.
- The `./backup/` directory (or NFS mount) must be writable by the Docker daemon.
- NFS client utilities (`nfs-common`) if using the NFS backend.
