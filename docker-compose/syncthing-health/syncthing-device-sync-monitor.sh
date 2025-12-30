#!/usr/bin/env bash
# syncthing-device-sync-monitor.sh
#
# Purpose:
#   Monitor a specific Syncthing folder + remote device and alert (via ntfy)
#   if the device stays behind while connected for longer than a threshold.
#
# Version: 1.1.0
#
# Behavior (high level):
#   - Uses Syncthing API:
#       /rest/db/completion?folder=...&device=...
#       /rest/system/connections
#   - Only "counts time" when device is CONNECTED.
#   - Sends ntfy notifications on state transitions:
#       * Problem: when "behind+connected" persists past threshold (first time only)
#       * Recovery: when it returns to in-sync or disconnects (only if a Problem was sent)
#
# Notes:
#   - Reuses ~/.syncthing-health.env for SYNCTHING_* and NTFY_* settings
#   - Logs to /var/log (assumes root/cron usage; logrotate external)
#
# Exit Codes:
#   0 = OK / tracking / recovered / disconnected (non-actionable)
#   1 = PROBLEM (behind too long while connected)
#   3 = Misconfiguration / API errors
#
set -euo pipefail

#######################################
# CONFIG / CONSTANTS
#######################################

SCRIPT_NAME="$(basename "$0")"
VERSION="1.1.0"

ENV_FILE="$HOME/.syncthing-health.env"

# Required env vars
REQUIRED_VARS=(
  SYNCTHING_URL
  SYNCTHING_API_KEY
)

# Monitor target (explicit for now; can be env-driven later if you want)
FOLDER_ID="eloaiza_Documents"
DEVICE_ID="UJPF4VF-IYRANQA-CKEL2GU-W3OJZAW-CKU2ACA-W6QCGJ2-M7PKYNI-3AIRAQQ"

# Threshold (minutes). Only counts time while device is connected.
MAX_BEHIND_MINUTES=30

# Logging (canonical)
LOG_FILE="/var/log/syncthing-device-sync-monitor.log"

# State storage
STATE_DIR="$HOME/.local/state/syncthing"
STATE_FILE="$STATE_DIR/${FOLDER_ID}.${DEVICE_ID}.behind"

#######################################
# LOGGING
#######################################

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$STATE_DIR"

exec >>"$LOG_FILE" 2>&1

log() {
  echo "[$(date -Is)] [$SCRIPT_NAME] $*"
}

banner() {
  log "=================================================="
  log "Starting at: $(date -Is)"
  log "Version: $VERSION"
  log "Folder: $FOLDER_ID"
  log "Device: $DEVICE_ID"
  log "Threshold: ${MAX_BEHIND_MINUTES}m (counts only while connected)"
  log "State: $STATE_FILE"
  log "Log: $LOG_FILE"
  log "=================================================="
}

#######################################
# LOAD ENV
#######################################

if [[ ! -f "$ENV_FILE" ]]; then
  log "ERROR: Env file not found: $ENV_FILE"
  exit 3
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

for v in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!v:-}" ]]; then
    log "ERROR: Required env var missing: $v"
    exit 3
  fi
done

#######################################
# NTFY (optional)
#######################################

ntfy_enabled() {
  [[ "${NTFY_ENABLED:-0}" == "1" ]] && [[ -n "${NTFY_URL:-}" ]] && [[ -n "${NTFY_TOPIC:-}" ]]
}

ntfy_post() {
  # Args:
  #   $1 = title (short)
  #   $2 = body  (multi-line ok)
  local title="$1"
  local body="$2"

  if ! ntfy_enabled; then
    return 0
  fi

  # Minimal, compatible POST (no auth, per your setup)
  # Use short timeouts so cron doesn't hang.
  if curl -fsS \
      --max-time 10 \
      -X POST \
      -H "Title: $title" \
      -d "$body" \
      "${NTFY_URL%/}/$NTFY_TOPIC" >/dev/null; then
    log "INFO: ntfy sent: $title"
  else
    log "WARN: ntfy failed to send: $title"
  fi
}

#######################################
# HELPERS
#######################################

api_get() {
  # Arg: path (must start with /rest/...)
  curl -fsS --max-time 10 \
    -H "X-API-Key: $SYNCTHING_API_KEY" \
    "$SYNCTHING_URL$1"
}

state_read() {
  # State file format (two lines):
  #   line1: behind_since_epoch
  #   line2: alerted_flag (0|1)
  #
  # Outputs: "epoch flagged"
  local epoch="0"
  local flagged="0"

  if [[ -f "$STATE_FILE" ]]; then
    epoch="$(sed -n '1p' "$STATE_FILE" 2>/dev/null || echo "0")"
    flagged="$(sed -n '2p' "$STATE_FILE" 2>/dev/null || echo "0")"
  fi

  # sanitize
  if [[ ! "$epoch" =~ ^[0-9]+$ ]]; then epoch="0"; fi
  if [[ "$flagged" != "1" ]]; then flagged="0"; fi

  echo "$epoch $flagged"
}

state_write() {
  # Args: epoch flagged
  local epoch="$1"
  local flagged="$2"
  printf "%s\n%s\n" "$epoch" "$flagged" >"$STATE_FILE"
}

state_clear() {
  rm -f "$STATE_FILE"
}

#######################################
# MAIN
#######################################

banner

# 1) Connection state (explicit truth)
CONN_JSON="$(api_get /rest/system/connections || true)"
if [[ -z "${CONN_JSON:-}" ]]; then
  log "ERROR: Failed to query /rest/system/connections"
  exit 3
fi

CONNECTED="$(echo "$CONN_JSON" | jq -r ".connections[\"$DEVICE_ID\"].connected // false" 2>/dev/null || echo "false")"

# 2) Completion state (folder+device)
COMP_JSON="$(api_get "/rest/db/completion?folder=$FOLDER_ID&device=$DEVICE_ID" || true)"
if [[ -z "${COMP_JSON:-}" ]]; then
  log "ERROR: Failed to query /rest/db/completion for folder=$FOLDER_ID device=$DEVICE_ID"
  exit 3
fi

NEED_ITEMS="$(echo "$COMP_JSON" | jq -r '.needItems // 0' 2>/dev/null || echo "0")"
NEED_BYTES="$(echo "$COMP_JSON" | jq -r '.needBytes // 0' 2>/dev/null || echo "0")"
COMPLETION="$(echo "$COMP_JSON" | jq -r '.completion // 0' 2>/dev/null || echo "0")"

if [[ ! "$NEED_ITEMS" =~ ^[0-9]+$ ]]; then NEED_ITEMS="0"; fi
if [[ ! "$NEED_BYTES" =~ ^[0-9]+$ ]]; then NEED_BYTES="0"; fi

NOW_EPOCH="$(date +%s)"

read -r BEHIND_SINCE_EPOCH ALERTED_FLAG < <(state_read)

# If not connected: not actionable; if we had an active alert, send recovery.
if [[ "$CONNECTED" != "true" ]]; then
  if [[ -f "$STATE_FILE" ]] && [[ "$ALERTED_FLAG" == "1" ]]; then
    ntfy_post \
      "Syncthing device recovered (disconnected)" \
      "Device is no longer connected; alert condition cleared.

Folder: $FOLDER_ID
Device: $DEVICE_ID
Last known: completion=${COMPLETION}%, needItems=${NEED_ITEMS}, needBytes=${NEED_BYTES}
Time: $(date -Is)"
  fi

  log "INFO: Device not connected. Clearing state (if any). connected=$CONNECTED"
  state_clear
  exit 0
fi

# If in sync: clear state; notify recovery only if previously alerted.
if [[ "$NEED_ITEMS" -eq 0 ]]; then
  if [[ -f "$STATE_FILE" ]] && [[ "$ALERTED_FLAG" == "1" ]]; then
    ntfy_post \
      "Syncthing device recovered" \
      "Device is fully in sync again.

Folder: $FOLDER_ID
Device: $DEVICE_ID
Completion: ${COMPLETION}%
Time: $(date -Is)"
  fi

  log "OK: In sync. completion=${COMPLETION}% needItems=$NEED_ITEMS needBytes=$NEED_BYTES. Clearing state."
  state_clear
  exit 0
fi

# Behind + connected:
# Start tracking if first seen.
if [[ ! -f "$STATE_FILE" ]] || [[ "$BEHIND_SINCE_EPOCH" -eq 0 ]]; then
  state_write "$NOW_EPOCH" "0"
  log "WARN: Device behind while connected. Tracking started. completion=${COMPLETION}% needItems=$NEED_ITEMS needBytes=$NEED_BYTES"
  exit 0
fi

# Compute elapsed
ELAPSED_SEC=$((NOW_EPOCH - BEHIND_SINCE_EPOCH))
ELAPSED_MIN=$((ELAPSED_SEC / 60))

# If threshold crossed and not alerted yet, send problem + mark alerted.
if (( ELAPSED_MIN >= MAX_BEHIND_MINUTES )); then
  if [[ "$ALERTED_FLAG" != "1" ]]; then
    ntfy_post \
      "Syncthing device behind too long" \
      "Remote device is behind while connected past threshold.

Folder: $FOLDER_ID
Device: $DEVICE_ID
Completion: ${COMPLETION}%
Behind: needItems=${NEED_ITEMS}, needBytes=${NEED_BYTES}
Duration: ${ELAPSED_MIN} minutes (threshold=${MAX_BEHIND_MINUTES}m)
Started: $(date -d "@$BEHIND_SINCE_EPOCH" -Is)
Now: $(date -Is)"

    state_write "$BEHIND_SINCE_EPOCH" "1"
    log "ERROR: Threshold reached. Alert sent. elapsed=${ELAPSED_MIN}m completion=${COMPLETION}% needItems=$NEED_ITEMS needBytes=$NEED_BYTES"
  else
    log "ERROR: Threshold reached (already alerted). elapsed=${ELAPSED_MIN}m completion=${COMPLETION}% needItems=$NEED_ITEMS needBytes=$NEED_BYTES"
  fi

  exit 1
fi

# Still behind but under threshold; no notification.
log "INFO: Still behind but under threshold. elapsed=${ELAPSED_MIN}m/<${MAX_BEHIND_MINUTES}m completion=${COMPLETION}% needItems=$NEED_ITEMS needBytes=$NEED_BYTES"
exit 0
