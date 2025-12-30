#!/usr/bin/env bash
# ------------------------------------------------------------
# syncthing-device-sync-monitor.sh
#
# Version: 1.1.0
#
# Description:
# Monitor a specific Syncthing folder and remote device.
# Detects when the device is behind while connected longer
# than a defined threshold. Sends ntfy alerts on transitions.
#
# Exit codes:
#   0 = OK / tracking / recovered
#   1 = Problem (behind too long while connected)
#   3 = Configuration or API error
# ------------------------------------------------------------

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERSION="1.1.0"

#######################################
# CONFIG
#######################################

ENV_FILE="$HOME/.syncthing-health.env"

FOLDER_ID="eloaiza_Documents"
DEVICE_ID="UJPF4VF-IYRANQA-CKEL2GU-W3OJZAW-CKU2ACA-W6QCGJ2-M7PKYNI-3AIRAQQ"

MAX_BEHIND_MINUTES=30

LOG_FILE="/var/log/syncthing-device-sync-monitor.log"

STATE_DIR="$HOME/.local/state/syncthing"
STATE_FILE="$STATE_DIR/${FOLDER_ID}.${DEVICE_ID}.behind"

#######################################
# SETUP
#######################################

mkdir -p "$(dirname "$LOG_FILE")" "$STATE_DIR"
exec >>"$LOG_FILE" 2>&1

log() {
  echo "[$(date -Is)] [$SCRIPT_NAME v$VERSION] $*"
}

#######################################
# LOAD ENV
#######################################

if [[ ! -f "$ENV_FILE" ]]; then
  log "ERROR: Missing env file: $ENV_FILE"
  exit 3
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

for var in SYNCTHING_URL SYNCTHING_API_KEY; do
  if [[ -z "${!var:-}" ]]; then
    log "ERROR: Missing env var: $var"
    exit 3
  fi
done

#######################################
# NTFY
#######################################

ntfy_enabled() {
  [[ "${NTFY_ENABLED:-0}" == "1" ]] &&
  [[ -n "${NTFY_URL:-}" ]] &&
  [[ -n "${NTFY_TOPIC:-}" ]]
}

ntfy_post() {
  local title="$1"
  local body="$2"

  ntfy_enabled || return 0

  curl -fsS --max-time 10 \
    -X POST \
    -H "Title: $title" \
    -d "$body" \
    "${NTFY_URL%/}/$NTFY_TOPIC" >/dev/null || \
    log "WARN: ntfy failed: $title"
}

#######################################
# HELPERS
#######################################

api_get() {
  curl -fsS --max-time 10 \
    -H "X-API-Key: $SYNCTHING_API_KEY" \
    "$SYNCTHING_URL$1"
}

state_read() {
  local since="0"
  local alerted="0"

  if [[ -f "$STATE_FILE" ]]; then
    since="$(sed -n '1p' "$STATE_FILE")"
    alerted="$(sed -n '2p' "$STATE_FILE")"
  fi

  [[ "$since" =~ ^[0-9]+$ ]] || since="0"
  [[ "$alerted" == "1" ]] || alerted="0"

  echo "$since $alerted"
}

state_write() {
  printf "%s\n%s\n" "$1" "$2" >"$STATE_FILE"
}

state_clear() {
  rm -f "$STATE_FILE"
}

#######################################
# MAIN
#######################################

log "Starting monitor run"

CONN_JSON="$(api_get /rest/system/connections || true)"
[[ -n "$CONN_JSON" ]] || exit 3

CONNECTED="$(jq -r ".connections[\"$DEVICE_ID\"].connected // false" <<<"$CONN_JSON")"

COMP_JSON="$(api_get "/rest/db/completion?folder=$FOLDER_ID&device=$DEVICE_ID" || true)"
[[ -n "$COMP_JSON" ]] || exit 3

NEED_ITEMS="$(jq -r '.needItems // 0' <<<"$COMP_JSON")"
COMPLETION="$(jq -r '.completion // 0' <<<"$COMP_JSON")"

NOW="$(date +%s)"
read -r BEHIND_SINCE ALERTED < <(state_read)

if [[ "$CONNECTED" != "true" ]]; then
  [[ "$ALERTED" == "1" ]] && ntfy_post "Syncthing recovered (offline)" "Device disconnected."
  state_clear
  exit 0
fi

if [[ "$NEED_ITEMS" -eq 0 ]]; then
  [[ "$ALERTED" == "1" ]] && ntfy_post "Syncthing recovered" "Device back in sync."
  state_clear
  exit 0
fi

if [[ "$BEHIND_SINCE" -eq 0 ]]; then
  state_write "$NOW" "0"
  log "Behind detected; tracking started"
  exit 0
fi

ELAPSED_MIN=$(( (NOW - BEHIND_SINCE) / 60 ))

if (( ELAPSED_MIN >= MAX_BEHIND_MINUTES )); then
  if [[ "$ALERTED" != "1" ]]; then
    ntfy_post \
      "Syncthing device behind too long" \
      "Folder: $FOLDER_ID
Device: $DEVICE_ID
Behind: $NEED_ITEMS items
Duration: ${ELAPSED_MIN}m"
    state_write "$BEHIND_SINCE" "1"
  fi
  exit 1
fi

log "Still behind (${ELAPSED_MIN}m < ${MAX_BEHIND_MINUTES}m)"
exit 0
