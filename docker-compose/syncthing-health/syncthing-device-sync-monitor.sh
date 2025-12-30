#!/bin/bash
# ------------------------------------------------------------
# syncthing-device-sync-monitor.sh
#
# Version: 1.1.0
#
# Purpose:
# Monitor a specific Syncthing folder + remote device.
# Exit with status 1 if the device is behind while connected
# longer than the configured threshold.
#
# Exit codes:
#   0 = OK / tracking / recovered / disconnected
#   1 = PROBLEM (behind too long while connected)
#   3 = Configuration / API error
# ------------------------------------------------------------

set -euo pipefail

VERSION="1.1.0"
SCRIPT_NAME="$(basename "$0")"

ENV_FILE="$HOME/.syncthing-health.env"

FOLDER_ID="eloaiza_Documents"
DEVICE_ID="UJPF4VF-IYRANQA-CKEL2GU-W3OJZAW-CKU2ACA-W6QCGJ2-M7PKYNI-3AIRAQQ"

MAX_BEHIND_MINUTES=30

LOG_FILE="/var/log/syncthing-device-sync-monitor.log"
STATE_DIR="$HOME/.local/state/syncthing"
STATE_FILE="$STATE_DIR/${FOLDER_ID}.${DEVICE_ID}.behind"

mkdir -p "$(dirname "$LOG_FILE")" "$STATE_DIR"
exec >>"$LOG_FILE" 2>&1

log() {
  echo "[$(date -Is)] [$SCRIPT_NAME v$VERSION] $*"
}

# ------------------------------------------------------------
# Load environment
# ------------------------------------------------------------

if [[ ! -f "$ENV_FILE" ]]; then
  log "ERROR: Env file missing: $ENV_FILE"
  exit 3
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

: "${SYNCTHING_URL:?missing}"
: "${SYNCTHING_API_KEY:?missing}"

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

api_get() {
  curl -fsS --max-time 10 \
    -H "X-API-Key: $SYNCTHING_API_KEY" \
    "$SYNCTHING_URL$1"
}

state_read() {
  [[ -f "$STATE_FILE" ]] || { echo "0 0"; return; }
  read -r a b <"$STATE_FILE"
  echo "${a:-0} ${b:-0}"
}

state_write() {
  printf "%s %s\n" "$1" "$2" >"$STATE_FILE"
}

state_clear() {
  rm -f "$STATE_FILE"
}

# ------------------------------------------------------------
# Main logic
# ------------------------------------------------------------

CONN_JSON="$(api_get /rest/system/connections || true)"
[[ -n "$CONN_JSON" ]] || exit 3

CONNECTED="$(echo "$CONN_JSON" | jq -r ".connections[\"$DEVICE_ID\"].connected // false")"

COMP_JSON="$(api_get "/rest/db/completion?folder=$FOLDER_ID&device=$DEVICE_ID" || true)"
[[ -n "$COMP_JSON" ]] || exit 3

NEED_ITEMS="$(echo "$COMP_JSON" | jq -r '.needItems // 0')"

NOW="$(date +%s)"
read -r SINCE ALERTED < <(state_read)

if [[ "$CONNECTED" != "true" ]]; then
  state_clear
  exit 0
fi

if [[ "$NEED_ITEMS" -eq 0 ]]; then
  state_clear
  exit 0
fi

if [[ "$SINCE" -eq 0 ]]; then
  state_write "$NOW" 0
  exit 0
fi

ELAPSED_MIN=$(( (NOW - SINCE) / 60 ))

if (( ELAPSED_MIN >= MAX_BEHIND_MINUTES )); then
  state_write "$SINCE" 1
  exit 1
fi

exit 0
