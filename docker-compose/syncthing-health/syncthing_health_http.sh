#!/usr/bin/env bash
# ------------------------------------------------------------
# syncthing_health_http.sh
# Version: 1.3.1
#
# Description:
# HTTP wrapper that exposes syncthing_health.sh
# Emits RFC-compliant HTTP/1.1 responses (CRLF).
#
# Changelog:
# - 1.3.1: Fix HTTP framing (CRLF) for Uptime Kuma compatibility
# - 1.2.3: Use socat with absolute path
# - 1.2.2: Replace nc with socat
# - 1.2.1: Running changelog
# - 1.2.0: Debug logging
# ------------------------------------------------------------

set -euo pipefail

PORT=9123
DEBUG="${SYNCTHING_HEALTH_DEBUG:-0}"

handle_request() {
  if [[ "$DEBUG" == "1" ]]; then
    echo "[DEBUG $(date -Is)] HTTP request received" >&2
  fi

  if /app/syncthing_health.sh >/tmp/health.out 2>&1; then
    printf "HTTP/1.1 200 OK\r\n"
    printf "Content-Type: text/plain\r\n"
    printf "Connection: close\r\n"
    printf "\r\n"
    cat /tmp/health.out
  else
    printf "HTTP/1.1 500 Internal Server Error\r\n"
    printf "Content-Type: text/plain\r\n"
    printf "Connection: close\r\n"
    printf "\r\n"
    cat /tmp/health.out
  fi
}

export -f handle_request

/usr/bin/socat TCP-LISTEN:${PORT},reuseaddr,fork SYSTEM:'bash -c handle_request'
