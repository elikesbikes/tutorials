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

BACKUP_CRON=0 13 * * *               # daily at 13:00; change to your preferred time

NTFY_SERVER=https://ntfy.your-domain.com   # leave empty to disable notifications
NTFY_TOPIC=backups

STATUS_PORT=8484
```

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
# Expected: 0 13 * * * /app/scripts/backup.sh >> /app/logs/cron.log 2>&1
```

---

## 8. Initialize the Repository (first time only)

Skip this step if the repository already exists in `backup/`.

```bash
docker compose exec restic restic init
```

---

## 9. Verify

**Run a backup manually:**

```bash
docker compose exec restic /app/scripts/backup.sh
```

**Check the result:**

```bash
cat logs/status.json
# Expected: "status": "ok", snapshot_id populated

curl http://localhost:8484/health
# Expected: HTTP 200 with JSON body
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
