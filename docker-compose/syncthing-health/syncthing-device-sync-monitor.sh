#!/usr/bin/env bash
# ------------------------------------------------------------
# syncthing-device-sync-monitor.sh
#
# Purpose:
# Alert only when a connected Syncthing device remains behind
# (needItems > 0) for longer than a configurable threshold.
#
# Offline devices are explicitly ignored.
#
# Version: 1.2.1
# Status: ACTIVE
#
# Changelog (running):
# - 1.2.1: Make threshold env-configurable; ignore offline devices
# - 1.2.0: Initial duration-based lag detection
# ------------------------------------------------------------

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERSION="1.2.1"

ENV_FILE="$HOME/.syncthing-health.env"

LOG_DIR="/state/logs"
STATE_DIR="/state/state"
LOG_FILE="$LOG_DIR/syncthing-device-sync-monitor.log"

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

THRESHOLD_SECONDS="${SYNCTHING_SYNC_BEHIND_THRESHOLD_SECONDS:-86400}"

FOLDER_ID="eloaiza_Documents"
DEVICE_ID="UJPF4VF-IYRANQA-CKEL2GU-W3OJZAW-CKU2ACA-W6QCGJ2-M7PKYNI-3AIRAQQ"

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
NOW="$(date +%s)"

log "needItems=$NEED_ITEMS"

# Fully synced → reset immediately
if [[ "$NEED_ITEMS" -eq 0 ]]; then
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
