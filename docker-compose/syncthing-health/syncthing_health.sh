#!/usr/bin/env bash
# ------------------------------------------------------------
# syncthing_health.sh
# Version: 1.4.0
#
# Description:
# Evaluates Syncthing folder health via REST API.
# Paused folders are treated as UNHEALTHY (DOWN).
#
# Optional ntfy notifications (state-change only):
#   NTFY_ENABLED=1
#   NTFY_URL=https://ntfy.home.elikesbikes.com
#   NTFY_TOPIC=syncthing
#   NTFY_NOTIFY_ON_STARTUP=0
#
# State is persisted in /state to avoid duplicate alerts across restarts.
#
# Changelog (running):
# - 1.4.0: Add ntfy notifications on UP/DOWN transitions + persistent state; fix loop exit behavior
# - 1.3.0: Treat paused folders as unhealthy (mark DOWN)
# - 1.2.1: Converted changelog to cumulative (running) format
# - 1.2.0: Added optional debug logging (runtime toggle)
# - 1.0.0: Initial implementation
# ------------------------------------------------------------

set -euo pipefail

: "${SYNCTHING_URL:?SYNCTHING_URL not set}"
: "${SYNCTHING_API_KEY:?SYNCTHING_API_KEY not set}"

DEBUG="${SYNCTHING_HEALTH_DEBUG:-0}"

NTFY_ENABLED="${NTFY_ENABLED:-0}"
NTFY_URL="${NTFY_URL:-}"
NTFY_TOPIC="${NTFY_TOPIC:-}"
NTFY_NOTIFY_ON_STARTUP="${NTFY_NOTIFY_ON_STARTUP:-0}"

STATE_DIR="/state"
LAST_STATUS_FILE="${STATE_DIR}/last_status"
LAST_REASON_FILE="${STATE_DIR}/last_reason"
LAST_CHANGE_FILE="${STATE_DIR}/last_change"

log() {
  if [[ "$DEBUG" == "1" ]]; then
    echo "[DEBUG $(date -Is)] $*"
  fi
}

header_args=(-H "X-API-Key: $SYNCTHING_API_KEY")

ensure_state_dir() {
  mkdir -p "$STATE_DIR" 2>/dev/null || true
}

read_last_state() {
  local last_status="UNKNOWN"
  local last_reason=""
  local last_change=""

  if [[ -f "$LAST_STATUS_FILE" ]]; then
    last_status="$(cat "$LAST_STATUS_FILE" 2>/dev/null || echo UNKNOWN)"
  fi
  if [[ -f "$LAST_REASON_FILE" ]]; then
    last_reason="$(cat "$LAST_REASON_FILE" 2>/dev/null || true)"
  fi
  if [[ -f "$LAST_CHANGE_FILE" ]]; then
    last_change="$(cat "$LAST_CHANGE_FILE" 2>/dev/null || true)"
  fi

  echo "$last_status" "$last_change" "$last_reason"
}

write_state() {
  local new_status="$1"
  local new_change="$2"
  local new_reason="$3"

  printf "%s" "$new_status" >"$LAST_STATUS_FILE"
  printf "%s" "$new_reason" >"$LAST_REASON_FILE"
  printf "%s" "$new_change" >"$LAST_CHANGE_FILE"
}

seconds_since_iso() {
  # Best-effort duration calculation; if it fails, return empty.
  local iso="$1"
  if [[ -z "$iso" ]]; then
    echo ""
    return 0
  fi
  # date -d exists in Alpine busybox? Not reliably. Use bash-only fallback: skip duration if unsupported.
  # We keep it best-effort by not failing health logic.
  echo ""
}

ntfy_post() {
  local title="$1"
  local body="$2"
  local tags="$3"
  local priority="$4"

  if [[ "$NTFY_ENABLED" != "1" ]]; then
    return 0
  fi
  if [[ -z "$NTFY_URL" || -z "$NTFY_TOPIC" ]]; then
    log "NTFY enabled but NTFY_URL/NTFY_TOPIC not set; skipping notify"
    return 0
  fi

  # Ensure no trailing slash duplication
  local base="${NTFY_URL%/}"
  local endpoint="${base}/${NTFY_TOPIC}"

  # Send notification (do not fail health check if ntfy is down)
  curl -sS -m 8 \
    -H "Title: ${title}" \
    -H "Tags: ${tags}" \
    -H "Priority: ${priority}" \
    -d "${body}" \
    "$endpoint" >/dev/null 2>&1 || true
}

maybe_notify_transition() {
  local current_status="$1"   # UP/DOWN
  local current_reason="$2"   # human reason
  local now_iso="$3"

  ensure_state_dir

  read -r last_status last_change last_reason < <(read_last_state)

  # First run: initialize state; optionally notify
  if [[ "$last_status" == "UNKNOWN" ]]; then
    write_state "$current_status" "$now_iso" "$current_reason"
    if [[ "$NTFY_NOTIFY_ON_STARTUP" == "1" ]]; then
      if [[ "$current_status" == "DOWN" ]]; then
        ntfy_post "Syncthing DOWN (startup)" \
          "Time: ${now_iso}\nReason: ${current_reason}" \
          "syncthing,rotating_light" "4"
      else
        ntfy_post "Syncthing UP (startup)" \
          "Time: ${now_iso}\nStatus: healthy" \
          "syncthing,white_check_mark" "2"
      fi
    fi
    return 0
  fi

  # No change -> no notify
  if [[ "$current_status" == "$last_status" ]]; then
    return 0
  fi

  # Transition -> notify and persist
  if [[ "$current_status" == "DOWN" ]]; then
    ntfy_post "Syncthing DOWN" \
      "Time: ${now_iso}\nReason: ${current_reason}\nPrevious: ${last_status}" \
      "syncthing,rotating_light" "4"
  else
    ntfy_post "Syncthing UP" \
      "Time: ${now_iso}\nStatus: healthy\nRecovered from: ${last_reason:-unknown}" \
      "syncthing,white_check_mark" "2"
  fi

  write_state "$current_status" "$now_iso" "$current_reason"
}

# ---------------------------
# Health evaluation begins
# ---------------------------
now="$(date -Is)"
log "Starting health check"

# Reachability/auth check
http_code="$(curl -sS -o /tmp/syncthing_status.json -w "%{http_code}" -m 8 "${header_args[@]}" \
  "$SYNCTHING_URL/rest/system/status" || true)"

if [[ "$http_code" != "200" ]]; then
  reason="Syncthing API not OK (HTTP ${http_code})"
  log "$reason"
  maybe_notify_transition "DOWN" "$reason" "$now"
  echo "ERROR: ${reason}"
  exit 1
fi

# Fetch config once (paused flag lives here)
config_json="$(curl -sS -m 8 "${header_args[@]}" "$SYNCTHING_URL/rest/config" || true)"
if [[ -z "$config_json" ]]; then
  reason="Syncthing config fetch failed"
  log "$reason"
  maybe_notif_
