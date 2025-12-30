#!/usr/bin/env bash
# syncthing_health_http.sh
#
# Service: syncthing-health
# Script: syncthing_health_http.sh
# Version: 1.6.1
#
# Description:
# Minimal HTTP responder invoked by socat. Runs the main Syncthing health check
# and returns HTTP status codes for Uptime Kuma.
#
# HTTP mapping:
#   - exit 0 -> 200 OK
#   - exit 1 -> 503 Service Unavailable
#   - other  -> 500 Internal Server Error
#
# Changelog (running):
# - 1.6.1: Fix executable check bug; always run health script via /bin/bash
# - 1.5.0: (deprecated attempt) path routing (removed)
# - 1.4.0: Persistent state for transition-based ntfy notifications (handled by health script)
#
set -euo pipefail

HEALTH_SCRIPT="/app/syncthing_health.sh"
BASH_BIN="/bin/bash"

# Validate interpreter + target script (file existence is what matters; we run via bash)
if [[ ! -x "$BASH_BIN" ]]; then
  printf "HTTP/1.1 500 Internal Server Error\r\n\r\nbash not found at %s\n" "$BASH_BIN"
  exit 0
fi

if [[ ! -f "$HEALTH_SCRIPT" ]]; then
  printf "HTTP/1.1 500 Internal Server Error\r\n\r\nScript missing: %s\n" "$HEALTH_SCRIPT"
  exit 0
fi

# Execute health script via bash to avoid /usr/bin/env issues inside Alpine
if "$BASH_BIN" "$HEALTH_SCRIPT"; then
  printf "HTTP/1.1 200 OK\r\n\r\nOK\n"
  exit 0
fi

RC=$?

case "$RC" in
  1)
    printf "HTTP/1.1 503 Service Unavailable\r\n\r\nUnhealthy\n"
    ;;
  *)
    printf "HTTP/1.1 500 Internal Server Error\r\n\r\nService error\n"
    ;;
esac

exit 0
