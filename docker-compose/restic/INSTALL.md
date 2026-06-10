# Installation Guide

Step-by-step setup for a fresh host. For reference documentation see [README.md](README.md).

---

## 1. Host Prerequisites

```bash
sudo apt install -y nfs-common docker.io
# Docker Compose v2 (if not already present)
sudo apt install -y docker-compose-plugin
```

Verify the `FRONTEND` Docker network exists (shared across homelab containers):

```bash
docker network ls | grep frontend
# If missing:
docker network create frontend
```

---

## 2. Get the Project

```bash
cd /home/ecloaiza/devops/docker
git clone <repo-url> restic   # or copy the project directory
cd restic
```

---

## 3. Configure `.env`

```bash
cp .env.example .env
```

Edit `.env` with your host-specific values:

```env
CONTAINER_HOSTNAME=<your-hostname>    # e.g., tars, ranger0, gargantua
RESTIC_REPOSITORY=./backup/          # do not change — resolves to /backup in container
RESTIC_PASSWORD=<your-strong-password>

NTFY_SERVER=https://ntfy.your-domain.com   # default, overridable per job; empty disables
NTFY_TOPIC=backups

STATUS_PORT=8484

KEEP_DAILY=7                          # default retention, overridable per job
KEEP_WEEKLY=4
KEEP_MONTHLY=6
```

Note: backup schedules do NOT live in `.env` — they live in per-job config files (next step).

---

## 3b. Define Backup Jobs

Each backup job is one file in `jobs/`, declaring its own schedule and source paths:

```bash
cp jobs/example.conf.example jobs/docker-volumes.conf
# edit JOB_NAME (= filename stem), JOB_CRON (5-field), JOB_SOURCES
```

Then declare this host's data-source mounts (host paths → `/data/<name>` container paths referenced by `JOB_SOURCES`):

```bash
cp docker-compose.override.yml.example docker-compose.override.yml
# edit the volumes list for this host
```

Both files are host-specific and git-ignored — they are never synced between hosts.

---

## 4. NFS Configuration

Ensure `~/nfs-mount.env` exists with the restic NFS entry (using your hostname):

```env
NAS_HOST=192.168.5.51
NFS_PORT=2049
NFS_CONNECT_TIMEOUT_SECONDS=2
UMOUNT_TIMEOUT_SECONDS=30

NFS_MOUNTS="
192.168.5.51|/mnt/PROD1/nfs_restic/nfs_<hostname>|/mnt/homenas/nfs_restic/nfs_<hostname>|rw,hard,timeo=600,retrans=5,noatime
"
```

Example for `tars`:
```env
NFS_MOUNTS="
192.168.5.51|/mnt/PROD1/nfs_restic/nfs_tars|/mnt/homenas/nfs_restic/nfs_tars|rw,hard,timeo=600,retrans=5,noatime
"
```

```bash
chmod 600 ~/nfs-mount.env
```

---

## 5. Initialize Project

The init script creates the correct hostname-specific symlink automatically:

```bash
./scripts/init.sh
```

This will:
- Create `backup/` symlink → `/mnt/homenas/nfs_restic/nfs_<hostname>`
- Validate the symlink points to the correct location
- Create the `logs/` directory

Then mount the NFS share:

```bash
sudo /home/ecloaiza/devops/docker/restic/host/nfs-auto-mount.sh
# Verify:
ls backup/    # should show: config  data  index  keys  locks  snapshots
```

---

## 6. Host Cron — NFS Health Check

Add to root's crontab (`sudo crontab -e`):

```cron
*/5 * * * * /home/ecloaiza/devops/docker/restic/host/nfs-auto-mount.sh >> /var/log/nfs-auto-mount.log 2>&1
```

This keeps the NFS mount alive independently of the container.

---

## 7. Build and Start the Container

```bash
docker compose up -d --build
```

The container is configured with `restart: unless-stopped`, so it will automatically restart when Docker starts at boot.

Verify it started and the cron schedule is correct:

```bash
docker compose ps
docker compose exec restic cat /etc/crontabs/root
# Expected: one line per job conf, e.g.
# 0 13 * * * /app/scripts/backup.sh /app/jobs/docker-volumes.conf >> /app/logs/cron-docker-volumes.log 2>&1
```

Invalid job confs are skipped with a `[entrypoint] WARN:` line in `docker compose logs restic` — the container still starts with the remaining jobs.

---

## 8. Initialize the Repository (first time only)

Skip this step if the repository already exists in `backup/`.

```bash
docker compose exec restic restic init
```

---

## 9. Verify

**Run a job manually:**

```bash
docker compose exec restic /app/scripts/backup.sh /app/jobs/docker-volumes.conf
```

**Check the result:**

```bash
cat logs/status/docker-volumes.json
# Expected: "status": "ok", snapshot_id populated

curl http://localhost:8484/health
# Expected: HTTP 200, body has a "jobs" map with every job healthy

docker compose exec restic restic snapshots --tag docker-volumes
# Expected: the snapshot just created, tagged with the job name
```

**Check backup history:**

```bash
./host/restic-status.sh
```

---

## 10. Uptime Kuma (optional)

Add an HTTP monitor to track backup health:

- **URL**: `http://<host-ip>:8484/health`
- **Method**: GET
- **Interval**: 5 minutes
- **Expected status**: 200
- **Down condition**: 503 (no successful backup in the last 24 hours)

The endpoint is live as soon as the container starts — no additional configuration needed.

---

## 11. Migrating an Existing Single-Job Host (pre-multi-job)

For hosts already running the old `BACKUP_CRON` single-job setup. Each host has its own repository (`nfs_restic/nfs_<hostname>`), so hosts migrate independently — a mistake on one cannot affect another's backups.

1. **Sync the generic code** from the source-of-truth host. Never overwrite the host-specific files: `.env`, `jobs/`, `docker-compose.override.yml`, the `backup` symlink, `logs/`.

2. **Rebuild** (the image gained the util-linux `flock` package):
   ```bash
   docker compose build
   ```

3. **Create this host's job confs and override** (steps 3 and 3b above). For a like-for-like migration, one job replicating the old behavior is enough.

4. **Restart and verify** (steps 7 and 9 above).

   Safety net: if the new code starts with `BACKUP_CRON` still set and no job confs, the entrypoint generates a legacy `docker-volumes` job from it and warns — a half-migrated host keeps backing up.

5. **Adopt the old untagged snapshots** into the job so retention keeps applying to them (otherwise they are never pruned and sit in the repo forever):
   ```bash
   # Dry-check: should list exactly the old snapshots
   docker compose exec restic restic snapshots --tag ''

   # Adopt them (NOTE: snapshot IDs change — metadata rewrite, data intact)
   docker compose exec restic restic tag --add docker-volumes --tag ''

   # Verify: no untagged snapshots remain
   docker compose exec restic restic snapshots --tag ''
   ```

6. **Remove `BACKUP_CRON` from `.env`** and `docker compose up -d --force-recreate`. Startup logs should show the job installed from `jobs/` with no deprecation warning.
