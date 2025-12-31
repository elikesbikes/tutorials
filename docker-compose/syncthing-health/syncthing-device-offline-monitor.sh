#!/usr/bin/env bash
# ------------------------------------------------------------
# syncthing-device-offline-monitor.sh
#
# Purpose:
# Report DOWN if a specific Syncthing device is not currently
# connected. Uses /rest/system/connections (no time parsing).
# Emits exit codes for Uptime Kuma and sends ntfy notifications
# on state transitions.
#
# Version: 1.2.1
# Status: FROZEN
#
# Changelog (running):
# - 1.2.1: Add ntfy notifications on offline/online transitions
# - 1.2.0: Switch to /rest/system/connections (remove timestamps)
# - 1.1.0: Timestamp-based logic (deprecated)
# ------------------------------------------------------------

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERSION="1.2.1"

ENV_FILE="$HOME/.syncthing-health.env"

LOG_DIR="/state/logs"
STATE_DIR="/state/state"
LOG_FILE="$LOG_DIR/syncthing-device-offline-monitor.log"
STATE_FILE="$STATE_DIR/device_offline.state"

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
      log "STATE CHANGE: UP → DOWN"
      notify "🚨 Syncthing device offline" \
        "The monitored device is no longer connected to Syncthing."
      ;;
    UP)
      log "STATE CHANGE: DOWN → UP"
      notify "✅ Syncthing device online" \
        "The monitored device has reconnected to Syncthing."
      ;;
  esac
}

log "Starting offline monitor"

if [[ ! -f "$ENV_FILE" ]]; then
  log "ERROR: Missing env file: $ENV_FILE"
  transition DOWN
  exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

if [[ -z "${SYNCTHING_URL:-}" || -z "${SYNCTHING_API_KEY:-}" ]]; then
  log "ERROR: Missing required SYNCTHING_* variables"
  transition DOWN
  exit 1
fi

DEVICE_ID="UJPF4VF-IYRANQA-CKEL2GU-W3OJZAW-CKU2ACA-W6QCGJ2-M7PKYNI-3AIRAQQ"

CONNECTED="$(
  curl -fsS \
    -H "X-API-Key: $SYNCTHING_API_KEY" \
    "$SYNCTHING_URL/rest/system/connections" \
  | jq -r --arg id "$DEVICE_ID" '.connections[$id].connected // false'
)"

log "Connected=$CONNECTED"

if [[ "$CONNECTED" != "true" ]]; then
  transition DOWN
  exit 1
fi

transition UP
exit 0
