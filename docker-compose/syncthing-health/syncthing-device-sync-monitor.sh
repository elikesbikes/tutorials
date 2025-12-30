#!/bin/bash
# ------------------------------------------------------------
# syncthing-device-sync-monitor.sh
#
# Version: 1.1.0
#
# Description:
# Monitor a specific Syncthing folder + remote device and detect
# when the device remains behind while connected for longer than
# a defined threshold. Designed for Uptime Kuma + ntfy.
#
# Exit Codes:
#   0 = OK / tracking / recovered / disconnected
#   1 = PROBLEM (behind too long while connected)
#   3 = Misconfiguration / API error
# ------------------------------------------------------------

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERSION="1.1.0"

ENV_FILE="$HOME/.syncthing-health.env"

# Target (frozen)
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

# ---- Load env ------------------------------------------------

if [[ ! -f "$ENV_FILE" ]]; then
  log "ERROR: Env file not found: $ENV_FILE"
  exit 3
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

: "${SYNCTHING_URL:?Missing SYNCTHING_URL}"
: "${SYNCTHING_API_KEY:?Missing SYNCTHING_API_KEY}"

# ---- ntfy ----------------------------------------------------

ntfy_enabled() {
  [[ "${NTFY_ENABLED:-0}" == "1" ]] && [[ -n "${NTFY_URL:-}" ]] && [[ -n "${NTFY_TOPIC:-}" ]]
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
    log "WARN: ntfy send failed: $title"
}

# ---- helpers -------------------------------------------------

api_get() {
  curl -fsS --max-time 10 \
    -H "X-API-Key: $SYNCTHING_API_KEY" \
    "$SYNCTHING_URL$1"
}

state_read() {
  [[ -f "$STATE_FILE" ]] || { echo "0 0"; return; }
  read -r a b <"$STATE_FILE" || echo "0 0"
}

state_write() {
  printf "%s %s\n" "$1" "$2" >"$STATE_FILE"
}

state_clear() {
  rm -f "$STATE_FILE"
}

# ---- main ----------------------------------------------------

CONN_JSON="$(api_get /rest/system/connections || true)"
[[ -n "$CONN_JSON" ]] || exit 3

CONNECTED="$(echo "$CONN_JSON" | jq -r ".connections[\"$DEVICE_ID\"].connected // false")"

COMP_JSON="$(api_get "/rest/db/completion?folder=$FOLDER_ID&device=$DEVICE_ID" || true)"
[[ -n "$COMP_JSON" ]] || exit 3

NEED_ITEMS="$(echo "$COMP_JSON" | jq -r '.needItems // 0')"
NEED_BYTES="$(echo "$COMP_JSON" | jq -r '.needBytes // 0')"

NOW="$(date +%s)"
read -r BEHIND_SINCE ALERTED < <(state_read)

if [[ "$CONNECTED" != "true" ]]; then
  [[ "$ALERTED" == "1" ]] && ntfy_post \
    "Syncthing device recovered (offline)" \
    "Device disconnected, alert cleared."
  state_clear
  exit 0
fi

if [[ "$NEED_ITEMS" -eq 0 ]]; then
  [[ "$ALERTED" == "1" ]] && ntfy_post \
    "Syncthing device recovered" \
    "Device fully in sync again."
  state_clear
  exit 0
fi

if [[ "$BEHIND_SINCE" -eq 0 ]]; then
  state_write "$NOW" 0
  exit 0
fi

ELAPSED_MIN=$(( (NOW - BEHIND_SINCE) / 60 ))

if (( ELAPSED_MIN >= MAX_BEHIND_MINUTES )); then
  if [[ "$ALERTED" != "1" ]]; then
    ntfy_post \
      "Syncthing device behind too long" \
      "Folder: $FOLDER_ID
Device: $DEVICE_ID
Behind: items=$NEED_ITEMS bytes=$NEED_BYTES
Duration: ${ELAPSED_MIN}m"
    state_write "$BEHIND_SINCE" 1
  fi
  exit 1
fi

exit 0
