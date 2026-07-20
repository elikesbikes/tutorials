#!/usr/bin/env bash
set -euo pipefail

#####################################
# backup.sh — runs INSIDE the container
#
# Usage: backup.sh /app/jobs/<name>.conf
#
# One invocation = one job. The conf file declares JOB_NAME, JOB_CRON,
# JOB_SOURCES and optional per-job overrides (see jobs/example.conf.example).
# Calls restic directly (no docker compose wrapper). NFS mounting is handled
# on the host; this script assumes /backup is already accessible.
#
# All jobs share one restic repository: snapshots are tagged with JOB_NAME,
# and jobs serialize via an exclusive lock on /app/logs/.repo.lock.
#####################################

# RESTIC_REPOSITORY is relative (./backup/). crond runs jobs from $HOME
# (/root), so anchor cwd at / where the /backup mount lives.
cd /

#####################################
# LOAD AND VALIDATE JOB CONFIG
#####################################
CONF="${1:?Usage: backup.sh /app/jobs/<name>.conf}"
[[ -r "$CONF" ]] || { echo "ERROR: job conf not readable: $CONF" >&2; exit 1; }

# shellcheck disable=SC1090  # conf path is dynamic by design
source "$CONF"

# Re-validate even though entrypoint.sh checked at startup — this script is
# also run manually, and the conf may have changed since the container started.
[[ "${JOB_NAME:-}" =~ ^[A-Za-z0-9_-]+$ ]] \
  || { echo "ERROR: $CONF: JOB_NAME='${JOB_NAME:-}' invalid (need [A-Za-z0-9_-]+)" >&2; exit 1; }
[[ -n "${JOB_SOURCES:-}" ]] \
  || { echo "ERROR: $CONF: JOB_SOURCES is empty" >&2; exit 1; }

# Per-job overrides fall back to .env defaults. Exported so cleanup.sh
# (invoked below) sees the resolved values.
export KEEP_DAILY="${JOB_KEEP_DAILY:-${KEEP_DAILY:-7}}"
export KEEP_WEEKLY="${JOB_KEEP_WEEKLY:-${KEEP_WEEKLY:-4}}"
export KEEP_MONTHLY="${JOB_KEEP_MONTHLY:-${KEEP_MONTHLY:-6}}"
NTFY_SERVER="${JOB_NTFY_SERVER:-${NTFY_SERVER:-}}"
NTFY_TOPIC="${JOB_NTFY_TOPIC:-${NTFY_TOPIC:-backups}}"
MAX_AGE_HOURS="${JOB_MAX_AGE_HOURS:-25}"

# restic --verbose level: 1 = summary + progress, 2 = log every file.
# Per-job JOB_VERBOSITY overrides the RESTIC_VERBOSITY default in .env.
VERBOSITY="${JOB_VERBOSITY:-${RESTIC_VERBOSITY:-1}}"

HOSTNAME="$(hostname -s)"
LOG_DIR="/app/logs"
LOG_FILE="$LOG_DIR/backup-${JOB_NAME}-$(date +%F).log"
STATUS_FILE="$LOG_DIR/status/${JOB_NAME}.json"
LOCK_FILE="$LOG_DIR/.repo.lock"

mkdir -p "$LOG_DIR/status"

notify() {
  local msg="$1"
  [[ -z "$NTFY_SERVER" ]] && return 0
  curl -fsS -X POST "$NTFY_SERVER/$NTFY_TOPIC" \
    -H "Title: Restic Backup ($HOSTNAME/$JOB_NAME)" \
    -H "Priority: 3" \
    -d "$msg" >/dev/null || true
}

# Preserve last_success_time from previous run on failure
read_last_success() {
  if [[ -f "$STATUS_FILE" ]]; then
    python3 -c "
import json, sys
try:
  d = json.load(open('$STATUS_FILE'))
  print(d.get('last_success_time', ''))
except:
  print('')
" 2>/dev/null || true
  fi
}

write_status() {
  local status="$1"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%S)"
  shift

  if [[ "$status" == "ok" ]]; then
    local snapshot="$1" files="$2" added="$3" duration="$4"
    python3 -c "
import json
d = {
  'status': 'ok',
  'job': '$JOB_NAME',
  'last_success_time': '$now',
  'snapshot_id': '$snapshot',
  'files_processed': $files,
  'data_added': '$added',
  'duration': '$duration',
  'hostname': '$HOSTNAME',
  'max_age_hours': $MAX_AGE_HOURS,
  'updated_at': '$now'
}
print(json.dumps(d, indent=2))
" > "$STATUS_FILE"
  else
    local error="$1"
    local last_success
    last_success="$(read_last_success)"
    python3 -c "
import json
d = {
  'status': 'fail',
  'job': '$JOB_NAME',
  'last_success_time': '$last_success' if '$last_success' else None,
  'error': '$error',
  'hostname': '$HOSTNAME',
  'max_age_hours': $MAX_AGE_HOURS,
  'updated_at': '$now'
}
print(json.dumps(d, indent=2))
" > "$STATUS_FILE"
  fi
}

fail() {
  local msg="$1"
  echo "ERROR: $msg" | tee -a "$LOG_FILE"
  notify "❌ [$HOSTNAME/$JOB_NAME] $msg"
  write_status "fail" "$msg"
  exit 1
}

#####################################
# VALIDATE ENVIRONMENT
#####################################
: "${RESTIC_REPOSITORY:?Missing RESTIC_REPOSITORY in env}"
: "${RESTIC_PASSWORD:?Missing RESTIC_PASSWORD in env}"

#####################################
# LOGGING
#####################################
echo "==================================================" | tee -a "$LOG_FILE"
echo "Restic backup started at $(date)"                   | tee -a "$LOG_FILE"
echo "Host: $HOSTNAME"                                    | tee -a "$LOG_FILE"
echo "Job: $JOB_NAME"                                     | tee -a "$LOG_FILE"
echo "Repository: $RESTIC_REPOSITORY"                     | tee -a "$LOG_FILE"
echo "==================================================" | tee -a "$LOG_FILE"

#####################################
# BUILD BACKUP PATH LIST
#####################################
read -ra BACKUP_PATHS <<< "$JOB_SOURCES"

# Optional space-separated exclude patterns (restic --exclude globs), e.g.
# live database/index data dirs that mutate mid-scan and produce spurious
# read errors (see graylog/opensearch_data in docker-volumes.conf).
EXCLUDE_ARGS=()
if [[ -n "${JOB_EXCLUDES:-}" ]]; then
  for pattern in $JOB_EXCLUDES; do
    EXCLUDE_ARGS+=(--exclude "$pattern")
  done
fi

# A missing source means a broken mount, not "nothing to back up" —
# fail loudly instead of silently backing up less than configured.
for path in "${BACKUP_PATHS[@]}"; do
  [[ -d "$path" ]] || fail "Source path missing: $path (broken mount in docker-compose.override.yml?)"
  echo "✔ Source: $path" | tee -a "$LOG_FILE"
done

#####################################
# ACQUIRE REPOSITORY LOCK
#
# Jobs queue (rather than skip) when another job holds the repo: a late
# backup is harmless, a skipped one is a protection gap. The timeout stops
# a wedged NFS mount from queueing jobs forever — on timeout the job fails
# loudly, which is what monitoring should see.
#####################################
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Waiting for repo lock (another job or cleanup running)..." | tee -a "$LOG_FILE"
  flock -w "${LOCK_TIMEOUT_SECONDS:-7200}" 9 \
    || fail "Could not acquire repo lock within ${LOCK_TIMEOUT_SECONDS:-7200}s"
fi

#####################################
# VERIFY REPOSITORY IS ACCESSIBLE
#####################################
[[ -d "$RESTIC_REPOSITORY" ]] || \
  fail "Repository path not accessible: $RESTIC_REPOSITORY (is NFS mounted on host?)"

#####################################
# ENSURE REPOSITORY EXISTS
#####################################
if restic --no-lock snapshots >/dev/null 2>&1; then
  echo "Restic repository exists" | tee -a "$LOG_FILE"
else
  restic init >>"$LOG_FILE" 2>&1 \
    || fail "Failed to initialize restic repository"
fi

#####################################
# RUN BACKUP
#####################################
echo "Running restic backup (tag: $JOB_NAME) for:" | tee -a "$LOG_FILE"
for p in "${BACKUP_PATHS[@]}"; do
  echo "  - $p" | tee -a "$LOG_FILE"
done

# Pipe through tee so verbose output is visible live (on the terminal for a
# manual run, in cron-<job>.log for a scheduled run) AND saved to the log file
# the result parser reads below. pipefail makes the pipeline fail if restic does.
# Capture restic's own exit code (PIPESTATUS[0]) — not tee's. `|| true` keeps
# `set -e` from aborting before we can inspect the code.
restic --no-lock "--verbose=$VERBOSITY" backup --tag "$JOB_NAME" "${EXCLUDE_ARGS[@]}" "${BACKUP_PATHS[@]}" 2>&1 \
  | tee -a "$LOG_FILE" || true
restic_rc=${PIPESTATUS[0]}

# restic exit codes: 0 = success; 3 = snapshot saved but some source files
# could not be read; anything else = real failure. Exit 3 happens routinely
# when backing up live data dirs (e.g. Graylog/OpenSearch deletes Lucene
# segment files mid-scan) — the snapshot is still valid, so treat it as a
# warning and proceed to parse results + cleanup.
if [[ "$restic_rc" -eq 3 ]]; then
  echo "WARNING: some source files could not be read during backup (restic exit 3); snapshot still saved" \
    | tee -a "$LOG_FILE"
elif [[ "$restic_rc" -ne 0 ]]; then
  fail "Restic backup command failed (exit $restic_rc)"
fi

#####################################
# PARSE RESULTS FROM LOG
# Use Python re — BusyBox grep does not support -P
#####################################
eval "$(python3 -c "
import re, sys

log = open(sys.argv[1]).read()

snap  = re.search(r'snapshot ([0-9a-f]+) saved', log)
proc  = re.search(r'processed (\d+) files', log)
added = re.search(r'Added to the repository: (\S+ \S+)', log)
dur   = re.search(r'processed \d+ files, \S+ \S+ in ([0-9]+:[0-9]+)', log)

print('snapshot=' + (snap.group(1)  if snap  else 'unknown'))
print('files='    + (proc.group(1)  if proc  else '0'))
print('added=\"'  + (added.group(1) if added else 'unknown') + '\"')
print('duration=' + (dur.group(1)   if dur   else 'unknown'))
" "$LOG_FILE")"

#####################################
# SUCCESS — TRIGGER CLEANUP
#####################################
write_status "ok" "${snapshot:-unknown}" "${files:-0}" "${added:-unknown}" "${duration:-unknown}"
notify "✅ [$HOSTNAME/$JOB_NAME] Backup completed — snapshot ${snapshot:-?} | ${files:-?} files | ${added:-?}"
echo "==================================================" | tee -a "$LOG_FILE"

# Run cleanup for THIS job's snapshots. We still hold the repo lock (fd 9 is
# inherited); RESTIC_LOCK_HELD tells cleanup.sh not to lock again.
# tee (not >>) so cleanup output also reaches our stdout → docker syslog driver.
if [[ -x /app/scripts/cleanup.sh ]]; then
  echo "Triggering cleanup for job $JOB_NAME..." | tee -a "$LOG_FILE"
  RESTIC_LOCK_HELD=1 /app/scripts/cleanup.sh "$CONF" 2>&1 | tee -a "$LOG_FILE"
fi
