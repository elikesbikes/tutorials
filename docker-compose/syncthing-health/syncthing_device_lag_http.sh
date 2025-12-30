#!/bin/sh
# ------------------------------------------------------------
# syncthing_device_lag_http.sh
#
# Version: 1.1.0
#
# Purpose:
# HTTP wrapper for syncthing-device-sync-monitor.sh
# for Uptime Kuma.
# ------------------------------------------------------------

set -eu

MONITOR="/app/syncthing-device-sync-monitor.sh"

# Always run via bash — never rely on shebang
/bin/bash "$MONITOR"
RC=$?

case "$RC" in
  0)
    printf "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK"
    ;;
  1)
    printf "HTTP/1.1 503 Service Unavailable\r\nContent-Length: 18\r\n\r\nDevice behind too long"
    ;;
  *)
    printf "HTTP/1.1 500 Internal Server Error\r\nContent-Length: 13\r\n\r\nMonitor error"
    ;;
esac

exit 0
