#!/usr/bin/env bash
# Future Nextcloud upgrades on docker-prod-1 (192.168.5.24).
#
# The NFS server (192.168.5.51) has root_squash enabled.
# All file sync must run as www-data (UID 33), not root.
#
# Usage:
#   ./upgrade.sh                  # upgrade to nextcloud:latest
#   ./upgrade.sh nextcloud:35     # upgrade to a specific tag
set -euo pipefail

TARGET_IMAGE="${1:-nextcloud:latest}"
COMPOSE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${COMPOSE_DIR}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[$(date '+%H:%M:%S')] $*${NC}"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] $*${NC}"; }
die()  { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $*${NC}" >&2; exit 1; }

current=$(docker exec nextcloud_app php occ config:system:get version 2>/dev/null || echo "unknown")
log "Current version: ${current} → target image: ${TARGET_IMAGE}"

# ── Step 1: Pull new image ────────────────────────────────────────────────────
log "Step 1/5 — Pulling ${TARGET_IMAGE}"
sed -i "s|image: nextcloud:.*|image: ${TARGET_IMAGE}|" docker-compose.yml
docker compose pull app

# ── Step 2: Recreate container with new image ─────────────────────────────────
log "Step 2/5 — Recreating nextcloud_app"
docker compose up -d app

# ── Step 3: Sync files from image to NFS (as www-data to bypass root_squash) ──
log "Step 3/5 — Syncing NC files to NFS (runs as www-data, may take 2-5 min)"
docker exec -u www-data nextcloud_app rsync -rlD --delete \
  --exclude=/config \
  --exclude=/data \
  --exclude=/custom_apps \
  /usr/src/nextcloud/ /var/www/html/

new_ver=$(docker exec nextcloud_app grep 'OC_VersionString' /var/www/html/version.php | grep -o "'[^']*'" | tr -d "'")
log "  Files synced — version.php now at ${new_ver}"

# ── Step 4: Run upgrade ───────────────────────────────────────────────────────
log "Step 4/5 — Running occ upgrade"
# Clear maintenance mode if a previous run left it on
if docker exec nextcloud_app php occ maintenance:mode --output=json 2>/dev/null | grep -q '"maintenance":true'; then
    warn "  Clearing stale maintenance mode"
    docker exec nextcloud_app php occ maintenance:mode --off
fi

docker exec nextcloud_app php occ upgrade --no-interaction
docker exec nextcloud_app php occ maintenance:repair --no-interaction || true

# ── Step 5: Bring back online ─────────────────────────────────────────────────
log "Step 5/5 — Enabling apps and going live"
docker exec nextcloud_app php occ app:update --all || true
docker exec nextcloud_app php occ maintenance:mode --off

final=$(docker exec nextcloud_app php occ config:system:get version 2>/dev/null)
log "Done! Nextcloud is now at ${final}"
echo -e "${YELLOW}Verify: https://nextcloud.home.elikesbikes.com${NC}"
