#!/usr/bin/env bash
set -euo pipefail

# Deploy restic project to remote hosts
# Usage: ./scripts/deploy.sh <host> <path>
# Example: ./scripts/deploy.sh user@endurances /home/ecloaiza/devops/docker/restic

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <host> <target-path>"
  echo "Example: $0 user@endurances /home/ecloaiza/devops/docker/restic"
  exit 1
fi

HOST="$1"
TARGET_PATH="$2"

echo "Deploying restic to $HOST:$TARGET_PATH"
echo "=================================================="

# Files to deploy (preserves .env and backup symlink on remote)
SYNC_EXCLUDE=(
  "--exclude=.git"
  "--exclude=.env"
  "--exclude=backup"
  "--exclude=logs"
  "--exclude=data"
  "--exclude=config"
  "--exclude=.DS_Store"
  "--exclude=*.local.json"
)

# Create target directory if it doesn't exist
ssh "$HOST" "mkdir -p $TARGET_PATH" || {
  echo "ERROR: Failed to access $HOST:$TARGET_PATH"
  exit 1
}

# Sync files (preserves existing .env and backup symlink)
echo "Syncing files..."
rsync -avz \
  "${SYNC_EXCLUDE[@]}" \
  --delete \
  ./ "$HOST:$TARGET_PATH/" || {
  echo "ERROR: Rsync failed"
  exit 1
}

# Verify .env exists on remote (copy .env.example if .env missing)
echo "Verifying configuration..."
ssh "$HOST" "
  if [[ ! -f $TARGET_PATH/.env ]]; then
    echo 'WARNING: .env not found on remote'
    echo 'Copying .env.example as template'
    cp $TARGET_PATH/.env.example $TARGET_PATH/.env
    echo 'EDIT THIS FILE WITH YOUR HOST-SPECIFIC VALUES:'
    echo '  - RESTIC_PASSWORD'
    echo '  - CONTAINER_HOSTNAME'
    echo '  - BACKUP_CRON (optional)'
  fi
"

# Verify backup symlink exists
echo "Verifying backup symlink..."
ssh "$HOST" "
  if [[ ! -L $TARGET_PATH/backup ]]; then
    echo 'WARNING: backup symlink not found'
    echo 'Create it with: ln -s /path/to/nfs/mount $TARGET_PATH/backup'
  fi
"

echo "=================================================="
echo "✅ Deployment complete!"
echo ""
echo "Next steps on $HOST:"
echo "  1. Edit .env with host-specific values"
echo "  2. Create backup symlink: ln -s /path/to/nfs/mount $TARGET_PATH/backup"
echo "  3. Rebuild & restart container: cd $TARGET_PATH && docker compose up -d --build"
