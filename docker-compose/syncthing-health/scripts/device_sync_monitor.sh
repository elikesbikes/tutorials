#!/usr/bin/env bash
# ------------------------------------------------------------
# device_sync_monitor.sh
#
# Purpose:
# Alert only when a connected Syncthing device remains behind
# (needItems > 0) for longer than a configurable threshold.
#
# Offline devices are explicitly ignored.
#
# Version: 1.3.1
# Status: ACTIVE
#
# Changelog (running):
# - 1.3.2: Treat needItems>0 with needBytes below SYNCTHING_SYNC_PHANTOM_BYTES as synced
# - 1.3.1: Renamed to device_sync_monitor.sh; moved to scripts/; update log file name
# - 1.3.0: Move DEVICE_ID and FOLDER_ID to env vars (SYNCTHING_DEVICE_ID, SYNCTHING_FOLDER_ID)
# - 1.2.1: Make threshold env-configurable; ignore offline devices
# - 1.2.0: Initial duration-based lag detection
# ------------------------------------------------------------

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERSION="1.3.2"

ENV_FILE="$HOME/.syncthing-health.env"

LOG_DIR="/state/logs"
STATE_DIR="/state/state"
LOG_FILE="$LOG_DIR/device_sync_monitor.log"

STATE_FILE="$STATE_DIR/device_sync.state"
BEHIND_SINCE_FILE="$STATE_DIR/device_sync_behind_since"

mkdir -p "$LOG_DIR" "$STATE_DIR"

log() {
  echo "[$(date -Is)] [$SCRIPT_NAME v$VERSION] $*" >>"$LOG_FILE"
}

notify() {
  local title="$1"
  local message="$2"

  [[ "${NTFY_ENABLED:-0}" != "1" ]] && return 0
  [[ -z "${NTFY_URL:-}" || -z "${NTFY_TOPIC:-}" ]] && return 0

  curl -fsS \
    -H "Title: $title" \
    -H "Tags: syncthing,sync" \
    -d "$message" \
    "$NTFY_URL/$NTFY_TOPIC" >/dev/null || true
}

read_state() {
  [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" || echo "UNKNOWN"
}

write_state() {
  echo "$1" >"$STATE_FILE"
}

transition() {
  local new="$1"
  local old
  old="$(read_state)"

  [[ "$old" == "$new" ]] && return 0
  write_state "$new"

  case "$new" in
    DOWN)
      notify "⚠️ Syncthing device behind" \
        "Device has been out of sync longer than the configured threshold."
      ;;
    UP)
      notify "✅ Syncthing device back in sync" \
        "Device is fully synchronized again."
      ;;
  esac
}

# ----------------------------
# Startup
# ----------------------------

log "Starting sync monitor"

if [[ ! -f "$ENV_FILE" ]]; then
  log "ERROR: Missing env file"
  exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

if [[ -z "${SYNCTHING_URL:-}" || -z "${SYNCTHING_API_KEY:-}" ]]; then
  log "ERROR: Missing SYNCTHING config"
  exit 1
fi

if [[ -z "${SYNCTHING_DEVICE_ID:-}" || -z "${SYNCTHING_FOLDER_ID:-}" ]]; then
  log "ERROR: Missing SYNCTHING_DEVICE_ID or SYNCTHING_FOLDER_ID"
  exit 1
fi

THRESHOLD_SECONDS="${SYNCTHING_SYNC_BEHIND_THRESHOLD_SECONDS:-86400}"
PHANTOM_BYTES="${SYNCTHING_SYNC_PHANTOM_BYTES:-1024}"

FOLDER_ID="$SYNCTHING_FOLDER_ID"
DEVICE_ID="$SYNCTHING_DEVICE_ID"

# ----------------------------
# Ignore offline devices
# ----------------------------

CONNECTED="$(
  curl -fsS \
    -H "X-API-Key: $SYNCTHING_API_KEY" \
    "$SYNCTHING_URL/rest/system/connections" \
  | jq -r --arg id "$DEVICE_ID" '.connections[$id].connected // false'
)"

log "Connected=$CONNECTED"

if [[ "$CONNECTED" != "true" ]]; then
  log "Device offline — sync monitor skipping"
  exit 0
fi

# ----------------------------
# Check sync status
# ----------------------------

COMPLETION_JSON="$(
  curl -fsS \
    -H "X-API-Key: $SYNCTHING_API_KEY" \
    "$SYNCTHING_URL/rest/db/completion?folder=$FOLDER_ID&device=$DEVICE_ID"
)"

NEED_ITEMS="$(echo "$COMPLETION_JSON" | jq -r '.needItems // 0')"
NEED_BYTES="$(echo "$COMPLETION_JSON" | jq -r '.needBytes // 0')"
NOW="$(date +%s)"

log "needItems=$NEED_ITEMS needBytes=$NEED_BYTES"

# Fully synced, or only a phantom (sub-threshold bytes) → reset immediately
if [[ "$NEED_ITEMS" -eq 0 ]] || (( NEED_BYTES < PHANTOM_BYTES )); then
  [[ "$NEED_ITEMS" -gt 0 ]] && log "Phantom detected (${NEED_BYTES}B < ${PHANTOM_BYTES}B threshold) — treating as synced"
  rm -f "$BEHIND_SINCE_FILE"
  transition UP
  exit 0
fi

# First detection of lag
if [[ ! -f "$BEHIND_SINCE_FILE" ]]; then
  echo "$NOW" >"$BEHIND_SINCE_FILE"
  log "Device fell behind at $NOW"
  exit 0
fi

BEHIND_SINCE="$(cat "$BEHIND_SINCE_FILE")"
AGE="$(( NOW - BEHIND_SINCE ))"

log "Behind for ${AGE}s (threshold=${THRESHOLD_SECONDS}s)"

if (( AGE >= THRESHOLD_SECONDS )); then
  transition DOWN
  exit 1
fi

# Still within grace period
exit 0
