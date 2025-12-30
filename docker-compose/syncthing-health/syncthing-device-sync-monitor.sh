#!/usr/bin/env bash
# ------------------------------------------------------------
# syncthing-device-sync-monitor.sh
#
# Version: 1.1.2
#
# Description:
# Monitor a specific Syncthing folder + remote device and report
# unhealthy state when the device is connected but behind.
#
# Exit codes:
#   0 = OK
#   1 = Monitor failure / unhealthy
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
