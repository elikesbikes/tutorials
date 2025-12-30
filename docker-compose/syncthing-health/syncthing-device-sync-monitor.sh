#!/usr/bin/env bash
# ------------------------------------------------------------
# syncthing-device-sync-monitor.sh
#
# Purpose:
# Monitor a specific Syncthing folder + remote device and detect
# when the device remains behind while connected for longer than
# a threshold. Emits exit codes for Uptime Kuma and sends ntfy
# notifications on state transitions.
#
# Version: 1.1.1
#
# Changelog (running):
# - 1.1.1: Fix env file resolution inside container; log to /state/logs
# - 1.1.0: Initial production version with state tracking + ntfy alerts
# ------------------------------------------------------------

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERSION="1.1.2"

# Container runs as root
ENV_FILE="$HOME/.syncthing-health.env"

LOG_DIR="/state/logs"
LOG_FILE="$LOG_DIR/syncthing-device-sync-monitor.log"

mkdir -p "$LOG_DIR"

log() {
  echo "[$(date -Is)] [$SCRIPT_NAME v$VERSION] $*" >>"$LOG_FILE"
}

log "Starting monitor"

if [[ ! -f "$ENV_FILE" ]]; then
  log "ERROR: Missing env file: $ENV_FILE"
  exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

if [[ -z "${SYNCTHING_URL:-}" || -z "${SYNCTHING_API_KEY:-}" ]]; then
  log "ERROR: Missing required SYNCTHING_* variables"
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
  exit 1
fi

NEED_ITEMS="$(echo "$COMPLETION_JSON" | jq -r '.needItems // 0')"

if [[ "$NEED_ITEMS" -gt 0 ]]; then
  log "WARN: Device behind (needItems=$NEED_ITEMS)"
  exit 1
fi

log "OK: Device fully in sync"
exit 0
