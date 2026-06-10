#!/usr/bin/env bash
set -euo pipefail

#####################################
# init.sh — Initialize restic project
#
# Creates/validates the backup symlink based on CONTAINER_HOSTNAME
# Ensures hostname-specific NFS mount point is correctly linked
#####################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Load .env
if [[ ! -f .env ]]; then
  echo "ERROR: .env not found"
  echo "Copy .env.example and fill in your values:"
  echo "  cp .env.example .env"
  exit 1
fi

# Extract CONTAINER_HOSTNAME from .env (avoid sourcing to prevent shell expansions)
CONTAINER_HOSTNAME=$(grep '^CONTAINER_HOSTNAME=' .env | cut -d= -f2 | tr -d '"' | tr -d "'")

if [[ -z "$CONTAINER_HOSTNAME" ]]; then
  echo "ERROR: CONTAINER_HOSTNAME not set in .env"
  exit 1
fi

BACKUP_LINK="./backup"
NFS_MOUNT_POINT="/mnt/homenas/nfs_restic/nfs_${CONTAINER_HOSTNAME}"

echo "=========================================="
echo "Restic initialization"
echo "=========================================="
echo "Hostname:           $CONTAINER_HOSTNAME"
echo "NFS mount point:    $NFS_MOUNT_POINT"
echo "Backup symlink:     $BACKUP_LINK"
echo "=========================================="

#####################################
# Validate NFS mount point exists
#####################################
if [[ ! -d "$NFS_MOUNT_POINT" ]]; then
  echo "WARNING: NFS mount point not found: $NFS_MOUNT_POINT"
  echo ""
  echo "This is expected if:"
  echo "  - NAS is currently down"
  echo "  - nfs-auto-mount.sh hasn't run yet (waits 5 min)"
  echo ""
  echo "The mount point will be created automatically when:"
  echo "  1. NAS comes back online"
  echo "  2. nfs-auto-mount.sh runs on the next 5-min interval"
  echo ""
  echo "For now, we'll create the symlink anyway."
  echo ""
fi

#####################################
# Create or fix backup symlink
#####################################
if [[ -L "$BACKUP_LINK" ]]; then
  # Symlink exists — check if it points to the right place
  existing=$(readlink "$BACKUP_LINK")
  if [[ "$existing" == "$NFS_MOUNT_POINT" ]]; then
    echo "✓ Symlink is correct"
  else
    echo "⚠ Symlink points to wrong target:"
    echo "  Current:  $existing"
    echo "  Expected: $NFS_MOUNT_POINT"
    echo ""
    echo "Fixing symlink..."
    rm "$BACKUP_LINK"
    ln -s "$NFS_MOUNT_POINT" "$BACKUP_LINK"
    echo "✓ Symlink fixed"
  fi
elif [[ -e "$BACKUP_LINK" ]]; then
  # File/directory exists but is not a symlink
  echo "ERROR: $BACKUP_LINK exists but is not a symlink"
  echo "Remove it and re-run: rm -rf ./backup && ./scripts/init.sh"
  exit 1
elif [[ -d "$BACKUP_LINK" ]]; then
  # Directory exists but isn't showing up as a symlink (stale NFS mount)
  echo "WARNING: $BACKUP_LINK is a directory (stale NFS mount?)"
  echo "Attempting to remove it..."
  if rm -rf "$BACKUP_LINK"; then
    ln -s "$NFS_MOUNT_POINT" "$BACKUP_LINK"
    echo "✓ Symlink created"
  else
    echo "ERROR: Failed to remove $BACKUP_LINK"
    echo "Try: sudo rm -rf ./backup"
    exit 1
  fi
else
  # Symlink doesn't exist — create it
  ln -s "$NFS_MOUNT_POINT" "$BACKUP_LINK"
  echo "✓ Symlink created: $BACKUP_LINK → $NFS_MOUNT_POINT"
fi

#####################################
# Create logs directory
#####################################
if [[ ! -d ./logs ]]; then
  mkdir -p ./logs
  echo "✓ Created logs directory"
else
  echo "✓ Logs directory exists"
fi

echo "=========================================="
echo "✅ Initialization complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Ensure NFS mount is available:"
echo "     sudo /home/ecloaiza/devops/docker/restic/host/nfs-auto-mount.sh"
echo ""
echo "  2. Start the container:"
echo "     docker compose up -d --build"
echo ""
echo "  3. Initialize restic (first time only):"
echo "     docker compose exec restic restic init"
echo ""
