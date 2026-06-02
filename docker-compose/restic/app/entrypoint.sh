#!/bin/sh
set -e

mkdir -p /app/logs

# Install cron job using schedule from env (default: daily at 02:00)
echo "${BACKUP_CRON:-0 2 * * *} /app/scripts/backup.sh >> /app/logs/cron.log 2>&1" \
  > /etc/crontabs/root

echo "[entrypoint] Backup cron schedule: ${BACKUP_CRON:-0 2 * * *}"
echo "[entrypoint] Starting HTTP status server on :${STATUS_PORT:-8484}"

# Start HTTP status server in background
python3 /app/status-api/app.py &

echo "[entrypoint] Starting crond"
exec crond -f -l 8
