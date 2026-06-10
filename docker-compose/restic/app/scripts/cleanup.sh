#!/usr/bin/env bash
set -euo pipefail

#####################################
# cleanup.sh — prune old snapshots for ONE job
#
# Usage: cleanup.sh /app/jobs/<name>.conf
#
# Normally invoked by backup.sh after a successful backup (with the repo
# lock already held). Can also be run manually:
#   docker compose exec restic /app/scripts/cleanup.sh /app/jobs/docker-volumes.conf
#
# INVARIANTS — do not weaken these (shared repo, multiple jobs):
#   * forget MUST carry --tag "$JOB_NAME": it limits deletion candidates to
#     this job's snapshots. Other jobs' snapshots and untagged legacy
#     snapshots are untouchable.
#   * --group-by host,tags (NOT the default host,paths): if JOB_SOURCES ever
#     changes, path-grouping would orphan the old group and keep its last
#     N daily/weekly/monthly snapshots forever.
#####################################

cd /

CONF="${1:?Usage: cleanup.sh /app/jobs/<name>.conf}"
[[ -r "$CONF" ]] || { echo "ERROR: job conf not readable: $CONF" >&2; exit 1; }

# shellcheck disable=SC1090  # conf path is dynamic by design
source "$CONF"

[[ "${JOB_NAME:-}" =~ ^[A-Za-z0-9_-]+$ ]] \
  || { echo "ERROR: $CONF: JOB_NAME='${JOB_NAME:-}' invalid (need [A-Za-z0-9_-]+)" >&2; exit 1; }

# Same fallback chain as backup.sh (per-job override → .env default → hardcoded)
KEEP_DAILY="${JOB_KEEP_DAILY:-${KEEP_DAILY:-7}}"
KEEP_WEEKLY="${JOB_KEEP_WEEKLY:-${KEEP_WEEKLY:-4}}"
KEEP_MONTHLY="${JOB_KEEP_MONTHLY:-${KEEP_MONTHLY:-6}}"

LOG_DIR="/app/logs"
LOG_FILE="$LOG_DIR/cleanup-${JOB_NAME}-$(date +%F).log"
LOCK_FILE="$LOG_DIR/.repo.lock"

mkdir -p "$LOG_DIR"

# When backup.sh calls us it already holds the repo lock on fd 9 (inherited)
# and sets RESTIC_LOCK_HELD=1. On manual runs we must take it ourselves —
# prune rewrites repo data and must never overlap a running backup.
if [[ -z "${RESTIC_LOCK_HELD:-}" ]]; then
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    echo "Waiting for repo lock (another job running)..." | tee -a "$LOG_FILE"
    flock -w "${LOCK_TIMEOUT_SECONDS:-7200}" 9 \
      || { echo "ERROR: could not acquire repo lock" | tee -a "$LOG_FILE"; exit 1; }
  fi
fi

echo "==================================================" | tee -a "$LOG_FILE"
echo "Restic cleanup started at $(date)"                  | tee -a "$LOG_FILE"
echo "Job: $JOB_NAME"                                     | tee -a "$LOG_FILE"
echo "Retention policy: $KEEP_DAILY daily, $KEEP_WEEKLY weekly, $KEEP_MONTHLY monthly" | tee -a "$LOG_FILE"
echo "==================================================" | tee -a "$LOG_FILE"

# --no-lock doesn't work with --prune; restic uses its own repo locking,
# and our flock above serializes against other jobs in this container.
restic forget \
  --tag "$JOB_NAME" \
  --group-by host,tags \
  --keep-daily "$KEEP_DAILY" \
  --keep-weekly "$KEEP_WEEKLY" \
  --keep-monthly "$KEEP_MONTHLY" \
  --prune >>"$LOG_FILE" 2>&1 \
  || { echo "Cleanup failed" | tee -a "$LOG_FILE"; exit 1; }

echo "==================================================" | tee -a "$LOG_FILE"
echo "Cleanup completed successfully"                     | tee -a "$LOG_FILE"
echo "==================================================" | tee -a "$LOG_FILE"
