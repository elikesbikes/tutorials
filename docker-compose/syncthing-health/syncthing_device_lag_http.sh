#!/usr/bin/env bash
# syncthing_device_lag_http.sh
#
# HTTP wrapper for syncthing-device-sync-monitor.sh
# Used by Uptime Kuma.
#

set -euo pipefail

MONITOR="/app/syncthing-device-sync-monitor.sh"

if [[ ! -x "$MONITOR" ]]; then
  printf "HTTP/1.1 500 Internal Server Error\r\n\r\nMonitor script not executable\n"
  exit 0
fi

if "$MONITOR"; then
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
