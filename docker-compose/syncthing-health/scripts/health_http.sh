#!/bin/bash
# ------------------------------------------------------------
# health_http.sh
#
# Service: syncthing-health
# Script: health_http.sh
# Version: 1.6.1
#
# Description:
# HTTP wrapper for /app/health.sh used by Uptime Kuma.
# Ensures strict HTTP/1.1 responses and prevents backend output
# from corrupting the HTTP response stream.
#
# Exit-code mapping (backend -> HTTP):
#   0 -> 200 OK
#   1 -> 503 Service Unavailable
#   * -> 500 Internal Server Error
#
# Logging:
#   /state/logs/health_http.log
#   /state/logs/health_backend.log
#
# Changelog (running):
# - 1.6.1: Renamed to health_http.sh; moved to scripts/; update backend path and log names
# - 1.6.0: Fix executable-check bug; force /bin/bash backend execution;
#         always emit valid HTTP/1.1 headers; isolate backend stdout/stderr
#         to /state logs to prevent HTTP/0.9 + empty reply issues.
# ------------------------------------------------------------

set -euo pipefail

VERSION="1.6.1"

STATE_DIR="/state"
LOG_DIR="$STATE_DIR/logs"
WRAP_LOG="$LOG_DIR/health_http.log"
BACKEND_LOG="$LOG_DIR/health_backend.log"

BACKEND_SCRIPT="/app/health.sh"

mkdir -p "$LOG_DIR"

log() {
  echo "[$(date -Is)] [health_http] v$VERSION $*" >>"$WRAP_LOG"
}

http_reply() {
  local code="$1" reason="$2" body="$3"
  local len
  len="$(printf '%s' "$body" | wc -c | tr -d ' ')"

  # IMPORTANT: Only write HTTP response to stdout.
  printf "HTTP/1.1 %s %s\r\n" "$code" "$reason"
  printf "Content-Type: text/plain\r\n"
  printf "Content-Length: %s\r\n" "$len"
  printf "Connection: close\r\n"
  printf "\r\n"
  printf "%s" "$body"
}

# Validate runtime prerequisites
if [[ ! -x /bin/bash ]]; then
  log "ERROR: /bin/bash not present or not executable"
  http_reply 500 "Internal Server Error" "bash missing\n"
  exit 0
fi

if [[ ! -f "$BACKEND_SCRIPT" ]]; then
  log "ERROR: Backend script missing: $BACKEND_SCRIPT"
  http_reply 500 "Internal Server Error" "backend script missing\n"
  exit 0
fi

# Run backend, capture all output to backend log (never to HTTP socket)
set +e
/bin/bash "$BACKEND_SCRIPT" >>"$BACKEND_LOG" 2>&1
RC=$?
set -e

log "Backend exit code: $RC"

case "$RC" in
  0)
    http_reply 200 "OK" "OK\n"
    ;;
  1)
    http_reply 503 "Service Unavailable" "Service unhealthy\n"
    ;;
  *)
    http_reply 500 "Internal Server Error" "Service error\n"
    ;;
esac

exit 0
