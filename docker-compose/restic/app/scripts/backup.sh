#!/usr/bin/env bash
set -euo pipefail

#####################################
# backup.sh — runs INSIDE the container
#
# Calls restic directly (no docker compose wrapper).
# NFS mounting is handled on the host; this script
# assumes /backup is already accessible.
#####################################

# RESTIC_REPOSITORY is relative (./backup/). crond runs jobs from $HOME
# (/root), so anchor cwd at / where the /backup mount lives.
cd /

NTFY_SERVER="${NTFY_SERVER:-}"
NTFY_TOPIC="${NTFY_TOPIC:-backups}"
HOSTNAME="$(hostname -s)"
STATUS_FILE="/app/logs/status.json"
LOG_DIR="/app/logs"
LOG_FILE="$LOG_DIR/backup-$(date +%F).log"

mkdir -p "$LOG_DIR"

notify() {
  local msg="$1"
  [[ -z "$NTFY_SERVER" ]] && return 0
  curl -fsS -X POST "$NTFY_SERVER/$NTFY_TOPIC" \
    -H "Title: Restic Backup ($HOSTNAME)" \
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
  'last_success_time': '$now',
  'snapshot_id': '$snapshot',
  'files_processed': $files,
  'data_added': '$added',
  'duration': '$duration',
  'hostname': '$HOSTNAME',
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
  'last_success_time': '$last_success' if '$last_success' else None,
  'error': '$error',
  'hostname': '$HOSTNAME',
  'updated_at': '$now'
}
print(json.dumps(d, indent=2))
" > "$STATUS_FILE"
  fi
}

fail() {
  local msg="$1"
  echo "ERROR: $msg" | tee -a "$LOG_FILE"
  notify "❌ [$HOSTNAME] $msg"
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
echo "Repository: $RESTIC_REPOSITORY"                     | tee -a "$LOG_FILE"
echo "==================================================" | tee -a "$LOG_FILE"

#####################################
# VERIFY REPOSITORY IS ACCESSIBLE
#####################################
[[ -d "$RESTIC_REPOSITORY" ]] || \
  fail "Repository path not accessible: $RESTIC_REPOSITORY (is NFS mounted on host?)"

#####################################
# BUILD BACKUP PATH LIST
#####################################
BACKUP_PATHS=("/data/docker-volumes")

CANDIDATE_BIND_PATHS=(
  "/data/bind-volumes/docker"
  "/data/bind-volumes/devops/docker"
  "/data/bind-volumes/Devops/docker"
  "/data/bind-volumes/DevOps/docker"
)

echo "Detecting bind-mount paths..." | tee -a "$LOG_FILE"
for path in "${CANDIDATE_BIND_PATHS[@]}"; do
  if [[ -d "$path" ]]; then
    BACKUP_PATHS+=("$path")
    echo "✔ Including $path" | tee -a "$LOG_FILE"
  else
    echo "✘ Skipping $path (not present)" | tee -a "$LOG_FILE"
  fi
done

#####################################
# ENSURE REPOSITORY EXISTS
#####################################
if restic snapshots >/dev/null 2>&1; then
  echo "Restic repository exists" | tee -a "$LOG_FILE"
else
  restic init >>"$LOG_FILE" 2>&1 \
    || fail "Failed to initialize restic repository"
fi

#####################################
# RUN BACKUP
#####################################
echo "Running restic backup for:" | tee -a "$LOG_FILE"
for p in "${BACKUP_PATHS[@]}"; do
  echo "  - $p" | tee -a "$LOG_FILE"
done

restic backup "${BACKUP_PATHS[@]}" >>"$LOG_FILE" 2>&1 \
  || fail "Restic backup command failed"

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
# SUCCESS
#####################################
write_status "ok" "${snapshot:-unknown}" "${files:-0}" "${added:-unknown}" "${duration:-unknown}"
notify "✅ [$HOSTNAME] Backup completed — snapshot ${snapshot:-?} | ${files:-?} files | ${added:-?}"
echo "==================================================" | tee -a "$LOG_FILE"
