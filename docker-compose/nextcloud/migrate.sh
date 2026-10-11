#!/usr/bin/env bash
# Migrate Nextcloud from 192.168.5.20 to docker-prod-1 (192.168.5.24)
# Data is already on shared NFS — this script is a near-zero-copy cutover.
#
# Run this from docker-prod-1 as ecloaiza (with sudo rights).
# Prerequisites: NFS entry added to /etc/fstab (see README or fstab.snippet).
set -euo pipefail

SOURCE_HOST="ecloaiza@192.168.5.20"
SOURCE_COMPOSE_DIR="/home/ecloaiza/docker/nextcloud"
NFS_SERVER="192.168.5.51"
NFS_EXPORT="/mnt/PROD1/nfs_nextcloud"
NFS_MOUNT="/mnt_nfs/nfs_nextcloud"
COMPOSE_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC_COLOR='\033[0m'
log()  { echo -e "${GREEN}[$(date '+%H:%M:%S')] $*${NC_COLOR}"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] $*${NC_COLOR}"; }
die()  { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $*${NC_COLOR}" >&2; exit 1; }

# ── Step 1: Mount NFS ────────────────────────────────────────────────────────
log "Step 1/7 — Mounting NFS on destination"
sudo mkdir -p "${NFS_MOUNT}"
if mountpoint -q "${NFS_MOUNT}"; then
    warn "  NFS already mounted at ${NFS_MOUNT}"
else
    sudo mount -t nfs "${NFS_SERVER}:${NFS_EXPORT}" "${NFS_MOUNT}"
    log "  Mounted ${NFS_SERVER}:${NFS_EXPORT} → ${NFS_MOUNT}"
fi
ls "${NFS_MOUNT}" || die "NFS mount is empty or inaccessible"

# ── Step 2: Verify source is reachable ──────────────────────────────────────
log "Step 2/7 — Verifying source host ${SOURCE_HOST}"
ssh -o ConnectTimeout=5 "${SOURCE_HOST}" "echo '  Source OK'" || die "Cannot reach ${SOURCE_HOST}"

# ── Step 3: Enable maintenance mode on source ────────────────────────────────
log "Step 3/7 — Enabling maintenance mode on source"
ssh "${SOURCE_HOST}" "sudo docker exec nextcloud_app php occ maintenance:mode --on"
log "  Maintenance mode ON"

# ── Step 4: Stop source containers ──────────────────────────────────────────
log "Step 4/7 — Stopping source containers"
ssh "${SOURCE_HOST}" "cd ${SOURCE_COMPOSE_DIR} && sudo docker compose down"
log "  Source containers stopped"

# Brief pause to let MariaDB flush and release the data dir
sleep 5

# ── Step 5: Start destination containers ────────────────────────────────────
log "Step 5/7 — Starting destination containers"
cd "${COMPOSE_DIR}"
docker compose up -d
log "  Waiting 20s for MariaDB to initialise..."
sleep 20

# Confirm containers are up
docker compose ps

# ── Step 6: Post-start config fixups ────────────────────────────────────────
log "Step 6/7 — Updating Nextcloud config for new host"

# Point CLI URL at the public domain (was http://192.168.5.20:8087)
docker exec nextcloud_app php occ config:system:set overwrite.cli.url \
    --value="https://nextcloud.home.elikesbikes.com"

# Add the new host IP to trusted domains (keep old entries intact)
docker exec nextcloud_app php occ config:system:set trusted_domains 3 \
    --value="192.168.5.24"

# Run upgrade in case the image picked up a minor update
docker exec nextcloud_app php occ upgrade --no-interaction || true

# Fix file permissions / oc_jobs if needed
docker exec nextcloud_app php occ maintenance:repair --no-interaction || true

# ── Step 7: Disable maintenance mode ────────────────────────────────────────
log "Step 7/7 — Disabling maintenance mode"
docker exec nextcloud_app php occ maintenance:mode --off
log "  Maintenance mode OFF"

echo ""
log "Migration complete!"
echo -e "${YELLOW}Next steps:${NC_COLOR}"
echo "  1. Open https://nextcloud.home.elikesbikes.com and verify login"
echo "  2. In Nginx Proxy Manager, update the proxy host for nextcloud.home.elikesbikes.com"
echo "     Forward to: 192.168.5.24:8087"
echo "  3. Once verified, add NFS mount to /etc/fstab on this host (see fstab.snippet)"
echo "  4. Remove or keep the old stack on 192.168.5.20 (restart: no is already set)"
