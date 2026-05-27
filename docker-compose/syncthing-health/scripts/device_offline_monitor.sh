#!/usr/bin/env bash
# ------------------------------------------------------------
# device_offline_monitor.sh
#
# Purpose:
# Alert only if a Syncthing device remains offline for longer
# than a configurable threshold.
#
# Uses /rest/system/connections (no timestamp parsing).
#
# Version: 1.4.1
# Status: ACTIVE
#
# Changelog (running):
# - 1.4.1: Renamed to device_offline_monitor.sh; moved to scripts/; update log file name
# - 1.4.0: Move DEVICE_ID to env var (SYNCTHING_DEVICE_ID); use SYNCTHING_OFFLINE_THRESHOLD_SECONDS
# - 1.3.0: Add thresholded offline detection using shared env var
# - 1.2.1: Immediate offline alerts
# ------------------------------------------------------------

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERSION="1.4.1"

ENV_FILE="$HOME/.syncthing-health.env"

LOG_DIR="/state/logs"
STATE_DIR="/state/state"
LOG_FILE="$LOG_DIR/device_offline_monitor.log"

STATE_FILE="$STATE_DIR/device_offline.state"
OFFLINE_SINCE_FILE="$STATE_DIR/device_offline_since"

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
    -H "Tags: syncthing,offline" \
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
      notify "🚨 Syncthing device offline" \
        "Device has been offline longer than the configured threshold."
      ;;
    UP)
      notify "✅ Syncthing device online" \
        "Device has reconnected to Syncthing."
      ;;
  esac
}

log "Starting offline monitor"

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

if [[ -z "${SYNCTHING_DEVICE_ID:-}" ]]; then
  log "ERROR: Missing SYNCTHING_DEVICE_ID"
  exit 1
fi

THRESHOLD_SECONDS="${SYNCTHING_OFFLINE_THRESHOLD_SECONDS:-86400}"

DEVICE_ID="$SYNCTHING_DEVICE_ID"

CONNECTED="$(
  curl -fsS \
    -H "X-API-Key: $SYNCTHING_API_KEY" \
    "$SYNCTHING_URL/rest/system/connections" \
  | jq -r --arg id "$DEVICE_ID" '.connections[$id].connected // false'
)"

NOW="$(date +%s)"
log "Connected=$CONNECTED"

# ----------------------------
# Device is offline
# ----------------------------
if [[ "$CONNECTED" != "true" ]]; then
  if [[ ! -f "$OFFLINE_SINCE_FILE" ]]; then
    echo "$NOW" >"$OFFLINE_SINCE_FILE"
    log "Device went offline at $NOW"
    exit 0
  fi

  OFFLINE_SINCE="$(cat "$OFFLINE_SINCE_FILE")"
  AGE="$(( NOW - OFFLINE_SINCE ))"

  log "Offline for ${AGE}s (threshold=${THRESHOLD_SECONDS}s)"

  if (( AGE >= THRESHOLD_SECONDS )); then
    transition DOWN
    exit 1
  fi

  exit 0
fi

# ----------------------------
# Device is online
# ----------------------------
rm -f "$OFFLINE_SINCE_FILE"
transition UP
exit 0
