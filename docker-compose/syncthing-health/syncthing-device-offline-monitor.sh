#!/usr/bin/env bash
# ------------------------------------------------------------
# syncthing-device-offline-monitor.sh
#
# Purpose:
# Report DOWN if the device is not currently connected to
# Syncthing. Uses system/connections instead of timestamps.
#
# Version: 1.2.0
#
# Changelog (running):
# - 1.2.0: Use /rest/system/connections; remove time parsing entirely
# - 1.1.0: Timestamp-based logic (deprecated)
# ------------------------------------------------------------

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERSION="1.2.0"

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
  [[ "${NTFY_ENABLED:-0}" != "1" ]] && return 0
  curl -fsS \
    -H "Title: $1" \
    -H "Tags: syncthing,offline" \
    -d "$2" \
    "$NTFY_URL/$NTFY_TOPIC" >/dev/null || true
}

read_state() { [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" || echo UNKNOWN; }
write_state() { echo "$1" >"$STATE_FILE"; }

transition() {
  local new="$1" old
  old="$(read_state)"
  [[ "$old" == "$new" ]] && return
  write_state "$new"
  [[ "$new" == "DOWN" ]] && notify "🚨 Device offline" "Device disconnected"
  [[ "$new" == "UP"   ]] && notify "✅ Device online"  "Device reconnected"
}

source "$ENV_FILE"

DEVICE_ID="UJPF4VF-IYRANQA-CKEL2GU-W3OJZAW-CKU2ACA-W6QCGJ2-M7PKYNI-3AIRAQQ"

CONNECTED="$(
  curl -fsS -H "X-API-Key: $SYNCTHING_API_KEY" \
    "$SYNCTHING_URL/rest/system/connections" |
  jq -r --arg id "$DEVICE_ID" '.connections[$id].connected // false'
)"

log "Connected=$CONNECTED"

if [[ "$CONNECTED" != "true" ]]; then
  transition DOWN
  exit 1
fi

transition UP
exit 0
