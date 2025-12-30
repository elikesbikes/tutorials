#!/usr/bin/env bash
# ------------------------------------------------------------
# syncthing-device-sync-monitor.sh
#
# Version: 1.1.0
#
# Purpose:
# Monitor a specific Syncthing folder + remote device and
# detect when the device remains behind while connected.
#
# Exit codes:
#   0 = OK / tracking / recovered
#   1 = PROBLEM (behind too long while connected)
#   3 = Configuration / API error
# ------------------------------------------------------------

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERSION="1.1.0"

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
  echo "[$(date -Is)] [$SCRIPT_NAME] $*"
}

# Load env
if [[ ! -f "$ENV_FILE" ]]; then
  log "ERROR: Env file missing: $ENV_FILE"
  exit 3
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

for v in SYNCTHING_URL SYNCTHING_API_KEY; do
  [[ -n "${!v:-}" ]] || { log "ERROR: Missing env var $v"; exit 3; }
done

api_get() {
  curl -fsS --max-time 10 \
    -H "X-API-Key: $SYNCTHING_API_KEY" \
    "$SYNCTHING_URL$1"
}

ntfy_post() {
  [[ "${NTFY_ENABLED:-0}" == "1" ]] || return 0
  curl -fsS --max-time 10 \
    -X POST \
    -H "Title: $1" \
    -d "$2" \
    "${NTFY_URL%/}/$NTFY_TOPIC" >/dev/null || true
}

read_state() {
  [[ -f "$STATE_FILE" ]] && sed -n '1,2p' "$STATE_FILE" || echo -e "0\n0"
}

write_state() {
  printf "%s\n%s\n" "$1" "$2" >"$STATE_FILE"
}

clear_state() {
  rm -f "$STATE_FILE"
}

NOW="$(date +%s)"
read -r BEHIND_SINCE ALERTED < <(read_state)

CONNECTED="$(api_get /rest/system/connections | jq -r ".connections[\"$DEVICE_ID\"].connected // false")"

COMP_JSON="$(api_get "/rest/db/completion?folder=$FOLDER_ID&device=$DEVICE_ID")"
NEED_ITEMS="$(jq -r '.needItems' <<<"$COMP_JSON")"

if [[ "$CONNECTED" != "true" ]]; then
  [[ "$ALERTED" == "1" ]] && ntfy_post "Syncthing recovered" "Device disconnected; alert cleared."
  clear_state
  exit 0
fi

if [[ "$NEED_ITEMS" -eq 0 ]]; then
  [[ "$ALERTED" == "1" ]] && ntfy_post "Syncthing recovered" "Device back in sync."
  clear_state
  exit 0
fi

if [[ "$BEHIND_SINCE" -eq 0 ]]; then
  write_state "$NOW" "0"
  log "Tracking started"
  exit 0
fi

ELAPSED_MIN=$(((NOW - BEHIND_SINCE) / 60))

if (( ELAPSED_MIN >= MAX_BEHIND_MINUTES )); then
  if [[ "$ALERTED" != "1" ]]; then
    ntfy_post "Syncthing device behind" "Device behind > ${MAX_BEHIND_MINUTES}m"
    write_state "$BEHIND_SINCE" "1"
  fi
  exit 1
fi

exit 0
