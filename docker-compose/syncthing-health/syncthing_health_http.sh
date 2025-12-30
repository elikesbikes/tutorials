#!/usr/bin/env bash
# syncthing_health_http.sh
#
# Service: syncthing-health
# Version: 1.5.0
#
# Description:
# HTTP router for Syncthing health checks used by Uptime Kuma.
# Supports multiple endpoints mapped to backend scripts.
#
# Endpoints:
#   /health      -> syncthing_health.sh
#   /device-lag  -> syncthing-device-sync-monitor.sh
#
# Exit code mapping:
#   0 -> HTTP 200
#   1 -> HTTP 503
#   * -> HTTP 500
#
# Changelog (running):
# - 1.5.0: Add /device-lag endpoint for device-specific sync lag monitoring
# - 1.4.0: Add persistent state volume for transition-based ntfy notifications
# - 1.2.4: Removed obsolete top-level 'version:' key (Compose v2 rule)
# - 1.2.3: Fix socat PATH issue by using absolute binary path
# - 1.2.2: Fix invalid HTTP responses by switching from nc to socat
# - 1.2.1: Converted changelog to cumulative format
# - 1.2.0: Added optional debug logging
# - 1.1.2: Added bash runtime dependency
# - 1.1.1: Fixed RO volume startup failure
# - 1.1.0: Added external frontend Docker network
#
set -euo pipefail

#######################################
# CONFIG
#######################################

SCRIPT_HEALTH="/bin/bash /app/syncthing_health.sh"
SCRIPT_DEVICE_LAG="/app/syncthing-device-sync-monitor.sh"

#######################################
# READ REQUEST LINE (FROM SOCAT)
#######################################

# Read only the first request line: "GET /path HTTP/1.1"
IFS=' ' read -r METHOD PATH _ || true

#######################################
# ROUTING
#######################################

case "$PATH" in
  "/"|"/health")
    TARGET="$SCRIPT_HEALTH"
    ;;
  "/device-lag")
    TARGET="$SCRIPT_DEVICE_LAG"
    ;;
  *)
    printf "HTTP/1.1 404 Not Found\r\n\r\nNot Found\n"
    exit 0
    ;;
esac

#######################################
# VALIDATION
#######################################

if [[ ! -x "$TARGET" ]]; then
  printf "HTTP/1.1 500 Internal Server Error\r\n\r\nScript not executable: %s\n" "$TARGET"
  exit 0
fi

#######################################
# EXECUTION
#######################################

if "$TARGET"; then
  printf "HTTP/1.1 200 OK\r\n\r\nOK\n"
  exit 0
fi

RC=$?

case "$RC" in
  1)
    printf "HTTP/1.1 503 Service Unavailable\r\n\r\nService unhealthy\n"
    ;;
  *)
    printf "HTTP/1.1 500 Internal Server Error\r\n\r\nService error\n"
    ;;
esac

exit 0
