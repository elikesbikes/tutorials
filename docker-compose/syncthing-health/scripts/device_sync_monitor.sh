#!/usr/bin/env bash
# ------------------------------------------------------------
# device_sync_monitor.sh
#
# Purpose:
# Alert only when a connected Syncthing device remains behind
# (needItems > 0) in ANY folder it shares with the NAS for
# longer than a configurable threshold.
#
# Offline devices are explicitly ignored.
#
# Folders: SYNCTHING_FOLDER_IDS (space-separated) if set, otherwise
# every unpaused folder the NAS shares with SYNCTHING_DEVICE_ID
# (discovered on each run, so new folders are covered automatically).
#
# Output: one line per folder on stdout (the HTTP wrapper returns it
# as the response body); exit 0 = in sync, 1 = behind past threshold.
#
# Version: 1.4.0
# Status: ACTIVE
#
# Changelog (running):
# - 1.4.0: Check every folder shared with the device (was: only SYNCTHING_FOLDER_ID); per-folder
#          behind-since state; report device/folder/items/sample paths in the body and ntfy message
# - 1.3.2: Treat needItems>0 with needBytes below SYNCTHING_SYNC_PHANTOM_BYTES as synced
# - 1.3.1: Renamed to device_sync_monitor.sh; moved to scripts/; update log file name
# - 1.3.0: Move DEVICE_ID and FOLDER_ID to env vars (SYNCTHING_DEVICE_ID, SYNCTHING_FOLDER_ID)
# - 1.2.1: Make threshold env-configurable; ignore offline devices
# - 1.2.0: Initial duration-based lag detection
# ------------------------------------------------------------

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERSION="1.4.0"

ENV_FILE="$HOME/.syncthing-health.env"

LOG_DIR="/state/logs"
STATE_DIR="/state/state"
LOG_FILE="$LOG_DIR/device_sync_monitor.log"

STATE_FILE="$STATE_DIR/device_sync.state"
# One file per folder: device_sync_behind_since.<folder id>
BEHIND_SINCE_PREFIX="$STATE_DIR/device_sync_behind_since"

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
  local detail="$2"
  local old
  old="$(read_state)"

  [[ "$old" == "$new" ]] && return 0
  write_state "$new"

  case "$new" in
    DOWN)
      notify "⚠️ Syncthing device behind" \
        "Out of sync longer than the configured threshold:
$detail"
      ;;
    UP)
      notify "✅ Syncthing device back in sync" \
        "All shared folders are fully synchronized again.
$detail"
      ;;
  esac
}

api() {
  curl -fsS -H "X-API-Key: $SYNCTHING_API_KEY" "$SYNCTHING_URL$1"
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

if [[ -z "${SYNCTHING_DEVICE_ID:-}" ]]; then
  log "ERROR: Missing SYNCTHING_DEVICE_ID"
  exit 1
fi

THRESHOLD_SECONDS="${SYNCTHING_SYNC_BEHIND_THRESHOLD_SECONDS:-86400}"
PHANTOM_BYTES="${SYNCTHING_SYNC_PHANTOM_BYTES:-1024}"

DEVICE_ID="$SYNCTHING_DEVICE_ID"

CONNECTED="$(api /rest/system/connections | jq -r --arg id "$DEVICE_ID" '.connections[$id].connected // false')"

log "Connected=$CONNECTED"

DEVICE_NAME="$(api "/rest/config/devices/$DEVICE_ID" | jq -r '.name // empty')"
DEVICE_NAME="${DEVICE_NAME:-${DEVICE_ID:0:7}}"

if [[ "$CONNECTED" != "true" ]]; then
  log "Device offline — sync monitor skipping"
  echo "OK $DEVICE_NAME offline - not checked (see /offline)"
  exit 0
fi

if [[ -n "${SYNCTHING_FOLDER_IDS:-}" ]]; then
  read -r -a FOLDERS <<<"$SYNCTHING_FOLDER_IDS"
else
  mapfile -t FOLDERS < <(
    api /rest/config/folders \
    | jq -r --arg id "$DEVICE_ID" '.[] | select(.paused | not) | select(any(.devices[]; .deviceID == $id)) | .id'
  )
fi

if [[ "${#FOLDERS[@]}" -eq 0 ]]; then
  log "ERROR: no folders shared with $DEVICE_NAME"
  echo "ERROR no folders shared with $DEVICE_NAME"
  exit 1
fi

NOW="$(date +%s)"
REPORT=()
BEHIND_REPORT=()
DOWN=0

for FOLDER_ID in "${FOLDERS[@]}"; do
  BEHIND_SINCE_FILE="$BEHIND_SINCE_PREFIX.$FOLDER_ID"

  COMPLETION_JSON="$(api "/rest/db/completion?folder=$FOLDER_ID&device=$DEVICE_ID")"
  NEED_ITEMS="$(echo "$COMPLETION_JSON" | jq -r '.needItems // 0')"
  NEED_BYTES="$(echo "$COMPLETION_JSON" | jq -r '.needBytes // 0')"

  log "folder=$FOLDER_ID needItems=$NEED_ITEMS needBytes=$NEED_BYTES"

  # Fully synced, or only a phantom (sub-threshold bytes) → reset immediately
  if [[ "$NEED_ITEMS" -eq 0 ]] || (( NEED_BYTES < PHANTOM_BYTES )); then
    [[ "$NEED_ITEMS" -gt 0 ]] && log "folder=$FOLDER_ID phantom (${NEED_BYTES}B < ${PHANTOM_BYTES}B threshold) — treating as synced"
    rm -f "$BEHIND_SINCE_FILE"
    REPORT+=("OK $DEVICE_NAME/$FOLDER_ID in sync")
    continue
  fi

  if [[ ! -f "$BEHIND_SINCE_FILE" ]]; then
    echo "$NOW" >"$BEHIND_SINCE_FILE"
    log "folder=$FOLDER_ID fell behind at $NOW"
  fi

  AGE="$(( NOW - $(cat "$BEHIND_SINCE_FILE") ))"
  SAMPLE="$(api "/rest/db/remoteneed?folder=$FOLDER_ID&device=$DEVICE_ID&perpage=3" \
    | jq -r '[.files[]?.name] | join(", ")')"
  LINE="$DEVICE_NAME/$FOLDER_ID needs $NEED_ITEMS items (${NEED_BYTES} B) for $(( AGE / 3600 ))h: ${SAMPLE:-?}"

  log "folder=$FOLDER_ID behind for ${AGE}s (threshold=${THRESHOLD_SECONDS}s)"

  if (( AGE >= THRESHOLD_SECONDS )); then
    DOWN=1
    REPORT+=("BEHIND $LINE")
    BEHIND_REPORT+=("$LINE")
  else
    REPORT+=("OK (behind, under threshold) $LINE")
  fi
done

printf '%s\n' "${REPORT[@]}"

if (( DOWN )); then
  transition DOWN "$(printf '%s\n' "${BEHIND_REPORT[@]}")"
  exit 1
fi

transition UP "$(printf '%s\n' "${REPORT[@]}")"
exit 0
