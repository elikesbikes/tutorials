#!/usr/bin/env bash
# syncthing-device-sync-monitor.sh
#
# Version: 1.1.0
#
# Purpose:
#   Monitor a specific Syncthing folder + remote device and alert (via ntfy)
#   if the device stays behind while connected for longer than a threshold.
#
# Exit Codes:
#   0 = OK / tracking / recovered / disconnected
#   1 = PROBLEM (behind too long while connected)
#   3 = Misconfiguration / API error
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

# Monitored target (explicit, frozen for now)
FOLDER_ID="eloaiza_Documents"
DEVICE_ID="UJPF4VF-IYRANQA-CKEL2GU-W3OJZAW-CKU2ACA-W6QCGJ2-M7PKYNI-3AIRAQQ"

# Threshold (minutes)
MAX_BEHIND_MINUTES=30

# Logging
LOG_FILE="/var/log/syncthing-device-sync-monitor.log"

# State tracking
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
  local title="$1"
  local body="$2"

  if ! ntfy_enabled; then
    return 0
  fi

  curl -fsS --max-time 10 \
    -X POST \
    -H "Title: $title" \
    -d "$body" \
    "${NTFY_URL%/}/$NTFY_TOPIC" >/dev/null || \
    log "WARN: Failed to send ntfy notification: $title"
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
  local epoch="0"
  local alerted="0"

  if [[ -f "$STATE_FILE" ]]; then
    epoch="$(sed -n '1p' "$STATE_FILE" 2>/dev/null || echo 0)"
    alerted="$(sed -n '2p' "$STATE_FILE" 2>/dev/null || echo 0)"
  fi

  [[ "$epoch" =~ ^[0-9]+$ ]] || epoch="0"
  [[ "$alerted" == "1" ]] || alerted="0"

  echo "$epoch $alerted"
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

# 1) Connection state
CONN_JSON="$(api_get /rest/system/connections || true)"
if [[ -z "$CONN_JSON" ]]; then
  log "ERROR: Unable to query system connections"
  exit 3
fi

CONNECTED="$(echo "$CONN_JSON" | jq -r ".connections[\"$DEVICE_ID\"].connected // false")"

# 2) Completion state
COMP_JSON="$(api_get "/rest/db/completion?folder=$FOLDER_ID&device=$DEVICE_ID" || true)"
if [[ -z "$COMP_JSON" ]]; then
  log "ERROR: Unable to query completion for folder=$FOLDER_ID device=$DEVICE_ID"
  exit 3
fi

NEED_ITEMS="$(echo "$COMP_JSON" | jq -r '.needItems // 0')"
NEED_BYTES="$(echo "$COMP_JSON" | jq -r '.needBytes // 0')"
COMPLETION="$(echo "$COMP_JSON" | jq -r '.completion // 0')"

NOW_EPOCH="$(date +%s)"

read -r BEHIND_SINCE ALERTED < <(state_read)

# Device not connected → clear state, optional recovery
if [[ "$CONNECTED" != "true" ]]; then
  if [[ "$ALERTED" == "1" ]]; then
    ntfy_post \
      "Syncthing device recovered (offline)" \
      "Device is no longer connected; alert cleared.

Folder: $FOLDER_ID
Device: $DEVICE_ID
Time: $(date -Is)"
  fi

  log "INFO: Device not connected; clearing state"
  state_clear
  exit 0
fi

# Fully in sync → clear state, optional recovery
if [[ "$NEED_ITEMS" -eq 0 ]]; then
  if [[ "$ALERTED" == "1" ]]; then
    ntfy_post \
      "Syncthing device recovered" \
      "Device is fully in sync again.

Folder: $FOLDER_ID
Device: $DEVICE_ID
Completion: ${COMPLETION}%
Time: $(date -Is)"
  fi

  log "OK: Device in sync; clearing state"
  state_clear
  exit 0
fi

# Behind + connected
if [[ ! -f "$STATE_FILE" || "$BEHIND_SINCE" -eq 0 ]]; then
  state_write "$NOW_EPOCH" "0"
  log "WARN: Device behind; tracking started (needItems=$NEED_ITEMS)"
  exit 0
fi

ELAPSED_MIN=$(((NOW_EPOCH - BEHIND_SINCE) / 60))

if (( ELAPSED_MIN >= MAX_BEHIND_MINUTES )); then
  if [[ "$ALERTED" != "1" ]]; then
    ntfy_post \
      "Syncthing device behind too long" \
      "Device is behind while connected past threshold.

Folder: $FOLDER_ID
Device: $DEVICE_ID
Behind: needItems=$NEED_ITEMS needBytes=$NEED_BYTES
Duration: ${ELAPSED_MIN}m (threshold=${MAX_BEHIND_MINUTES}m)
Started: $(date -d "@$BEHIND_SINCE" -Is)"

    state_write "$BEHIND_SINCE" "1"
  fi

  log "ERROR: Device behind too long (${ELAPSED_MIN}m)"
  exit 1
fi

log "INFO: Device still behind but under threshold (${ELAPSED_MIN}m)"
exit 0
#!/usr/bin/env bash
# syncthing-device-sync-monitor.sh
#
# Version: 1.1.0
#
# Purpose:
#   Monitor a specific Syncthing folder + remote device and alert (via ntfy)
#   if the device stays behind while connected for longer than a threshold.
#
# Exit Codes:
#   0 = OK / tracking / recovered / disconnected
#   1 = PROBLEM (behind too long while connected)
#   3 = Misconfiguration / API error
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

# Monitored target (explicit, frozen for now)
FOLDER_ID="eloaiza_Documents"
DEVICE_ID="UJPF4VF-IYRANQA-CKEL2GU-W3OJZAW-CKU2ACA-W6QCGJ2-M7PKYNI-3AIRAQQ"

# Threshold (minutes)
MAX_BEHIND_MINUTES=30

# Logging
LOG_FILE="/var/log/syncthing-device-sync-monitor.log"

# State tracking
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
  local title="$1"
  local body="$2"

  if ! ntfy_enabled; then
    return 0
  fi

  curl -fsS --max-time 10 \
    -X POST \
    -H "Title: $title" \
    -d "$body" \
    "${NTFY_URL%/}/$NTFY_TOPIC" >/dev/null || \
    log "WARN: Failed to send ntfy notification: $title"
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
  local epoch="0"
  local alerted="0"

  if [[ -f "$STATE_FILE" ]]; then
    epoch="$(sed -n '1p' "$STATE_FILE" 2>/dev/null || echo 0)"
    alerted="$(sed -n '2p' "$STATE_FILE" 2>/dev/null || echo 0)"
  fi

  [[ "$epoch" =~ ^[0-9]+$ ]] || epoch="0"
  [[ "$alerted" == "1" ]] || alerted="0"

  echo "$epoch $alerted"
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

# 1) Connection state
CONN_JSON="$(api_get /rest/system/connections || true)"
if [[ -z "$CONN_JSON" ]]; then
  log "ERROR: Unable to query system connections"
  exit 3
fi

CONNECTED="$(echo "$CONN_JSON" | jq -r ".connections[\"$DEVICE_ID\"].connected // false")"

# 2) Completion state
COMP_JSON="$(api_get "/rest/db/completion?folder=$FOLDER_ID&device=$DEVICE_ID" || true)"
if [[ -z "$COMP_JSON" ]]; then
  log "ERROR: Unable to query completion for folder=$FOLDER_ID device=$DEVICE_ID"
  exit 3
fi

NEED_ITEMS="$(echo "$COMP_JSON" | jq -r '.needItems // 0')"
NEED_BYTES="$(echo "$COMP_JSON" | jq -r '.needBytes // 0')"
COMPLETION="$(echo "$COMP_JSON" | jq -r '.completion // 0')"

NOW_EPOCH="$(date +%s)"

read -r BEHIND_SINCE ALERTED < <(state_read)

# Device not connected → clear state, optional recovery
if [[ "$CONNECTED" != "true" ]]; then
  if [[ "$ALERTED" == "1" ]]; then
    ntfy_post \
      "Syncthing device recovered (offline)" \
      "Device is no longer connected; alert cleared.

Folder: $FOLDER_ID
Device: $DEVICE_ID
Time: $(date -Is)"
  fi

  log "INFO: Device not connected; clearing state"
  state_clear
  exit 0
fi

# Fully in sync → clear state, optional recovery
if [[ "$NEED_ITEMS" -eq 0 ]]; then
  if [[ "$ALERTED" == "1" ]]; then
    ntfy_post \
      "Syncthing device recovered" \
      "Device is fully in sync again.

Folder: $FOLDER_ID
Device: $DEVICE_ID
Completion: ${COMPLETION}%
Time: $(date -Is)"
  fi

  log "OK: Device in sync; clearing state"
  state_clear
  exit 0
fi

# Behind + connected
if [[ ! -f "$STATE_FILE" || "$BEHIND_SINCE" -eq 0 ]]; then
  state_write "$NOW_EPOCH" "0"
  log "WARN: Device behind; tracking started (needItems=$NEED_ITEMS)"
  exit 0
fi

ELAPSED_MIN=$(((NOW_EPOCH - BEHIND_SINCE) / 60))

if (( ELAPSED_MIN >= MAX_BEHIND_MINUTES )); then
  if [[ "$ALERTED" != "1" ]]; then
    ntfy_post \
      "Syncthing device behind too long" \
      "Device is behind while connected past threshold.

Folder: $FOLDER_ID
Device: $DEVICE_ID
Behind: needItems=$NEED_ITEMS needBytes=$NEED_BYTES
Duration: ${ELAPSED_MIN}m (threshold=${MAX_BEHIND_MINUTES}m)
Started: $(date -d "@$BEHIND_SINCE" -Is)"

    state_write "$BEHIND_SINCE" "1"
  fi

  log "ERROR: Device behind too long (${ELAPSED_MIN}m)"
  exit 1
fi

log "INFO: Device still behind but under threshold (${ELAPSED_MIN}m)"
exit 0
