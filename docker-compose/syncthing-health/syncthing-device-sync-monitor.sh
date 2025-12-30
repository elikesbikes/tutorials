#!/usr/bin/env bash
# ------------------------------------------------------------
# syncthing-device-sync-monitor.sh
#
# Purpose:
# Monitor a specific Syncthing folder + remote device and detect
# when the device remains behind. Emits exit codes for Uptime Kuma
# and sends ntfy notifications on state transitions.
#
# Version: 1.2.0
#
# Changelog (running):
# - 1.2.0: Add stateful ntfy notifications (DOWN/RECOVERY), no spam
# - 1.1.1: Fix env file resolution inside container; log to /state/logs
# - 1.1.0: Initial production version with state tracking
# ------------------------------------------------------------

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERSION="1.2.0"

ENV_FILE="$HOME/.syncthing-health.env"

LOG_DIR="/state/logs"
STATE_DIR="/state/state"
LOG_FILE="$LOG_DIR/syncthing-device-sync-monitor.log"
STATE_FILE="$STATE_DIR/device_sync.state"

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
    -H "Tags: syncthing" \
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
      notify "🚨 Syncthing device behind" \
        "Device is out of sync (needItems=$NEED_ITEMS)"
      ;;
    UP)
      notify "✅ Syncthing device recovered" \
        "Device is fully back in sync"
      ;;
  esac
}

log "Starting monitor"

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

FOLDER_ID="eloaiza_Documents"
DEVICE_ID="UJPF4VF-IYRANQA-CKEL2GU-W3OJZAW-CKU2ACA-W6QCGJ2-M7PKYNI-3AIRAQQ"

COMPLETION_JSON="$(
  curl -fsS \
    -H "X-API-Key: $SYNCTHING_API_KEY" \
    "$SYNCTHING_URL/rest/db/completion?folder=$FOLDER_ID&device=$DEVICE_ID" \
    || true
)"

if [[ -z "$COMPLETION_JSON" ]]; then
  log "ERROR: Failed to query completion API"
  transition DOWN
  exit 1
fi

NEED_ITEMS="$(echo "$COMPLETION_JSON" | jq -r '.needItems // 0')"

if [[ "$NEED_ITEMS" -gt 0 ]]; then
  log "WARN: Device behind (needItems=$NEED_ITEMS)"
  transition DOWN
  exit 1
fi

log "OK: Device fully in sync"
transition UP
exit 0
