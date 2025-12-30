#!/bin/sh
# ------------------------------------------------------------
# syncthing_device_lag_http.sh
#
# Version: 1.1.0
#
# Description:
# HTTP wrapper for syncthing-device-sync-monitor.sh.
# Used by Uptime Kuma.
#
# Exit code mapping:
#   monitor exit 0 -> HTTP 200
#   monitor exit 1 -> HTTP 503
#   anything else  -> HTTP 500
# ------------------------------------------------------------

set -eu

SCRIPT_NAME="$(basename "$0")"
VERSION="1.1.0"

MONITOR_SCRIPT="/app/syncthing-device-sync-monitor.sh"

# Validate target script exists and is executable
if [ ! -f "$MONITOR_SCRIPT" ]; then
  printf "HTTP/1.1 500 Internal Server Error\r\n\r\nMissing script: %s\n" "$MONITOR_SCRIPT"
  exit 0
fi

if [ ! -x "$MONITOR_SCRIPT" ]; then
  printf "HTTP/1.1 500 Internal Server Error\r\n\r\nScript not executable: %s\n" "$MONITOR_SCRIPT"
  exit 0
fi

# Execute explicitly with bash (never rely on shebang)
if /bin/bash "$MONITOR_SCRIPT"; then
  printf "HTTP/1.1 200 OK\r\n\r\nOK\n"
  exit 0
fi

RC=$?

case "$RC" in
  1)
    printf "HTTP/1.1 503 Service Unavailable\r\n\r\nDevice behind too long\n"
    ;;
  *)
    printf "HTTP/1.1 500 Internal Server Error\r\n\r\nMonitor error\n"
    ;;
esac

exit 0
