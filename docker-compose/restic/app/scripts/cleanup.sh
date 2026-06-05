#!/usr/bin/env bash
set -euo pipefail

# Cleanup old snapshots based on retention policy
# Run weekly or monthly to prune old backups

cd /

LOG_DIR="/app/logs"
LOG_FILE="$LOG_DIR/cleanup-$(date +%F).log"

mkdir -p "$LOG_DIR"

# Use defaults if env vars not set
KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-6}"

echo "==================================================" | tee -a "$LOG_FILE"
echo "Restic cleanup started at $(date)"                | tee -a "$LOG_FILE"
echo "Retention policy: $KEEP_DAILY daily, $KEEP_WEEKLY weekly, $KEEP_MONTHLY monthly" | tee -a "$LOG_FILE"
echo "==================================================" | tee -a "$LOG_FILE"

# Run forget with pruning (--no-lock doesn't work with --prune, uses file locking instead)
restic forget \
  --keep-daily "$KEEP_DAILY" \
  --keep-weekly "$KEEP_WEEKLY" \
  --keep-monthly "$KEEP_MONTHLY" \
  --prune >>"$LOG_FILE" 2>&1 \
  || (echo "Cleanup failed" | tee -a "$LOG_FILE"; exit 1)

echo "==================================================" | tee -a "$LOG_FILE"
echo "Cleanup completed successfully"                   | tee -a "$LOG_FILE"
echo "==================================================" | tee -a "$LOG_FILE"
