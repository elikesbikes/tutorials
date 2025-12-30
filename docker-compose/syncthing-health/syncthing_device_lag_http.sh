#!/bin/sh
# ------------------------------------------------------------
# syncthing_device_lag_http.sh
#
# Version: 1.1.0
#
# Description:
# HTTP endpoint wrapper for syncthing-device-sync-monitor.sh
# Designed for Uptime Kuma via socat.
#
# Exit code mapping:
#   0 -> 200 OK
#   1 -> 503 Service Unavailable
#   * -> 500 Internal Server Error
# ------------------------------------------------------------

set -eu

MONITOR="/app/syncthing-device-sync-monitor.sh"

# Run monitor via explicit interpreter (never rely on shebangs)
if /bin/bash "$MONITOR"; then
  printf "HTTP/1.1 200 OK\r\n"
  printf "Content-Type: text/plain\r\n\r\n"
  printf "OK\n"
  exit 0
fi

RC=$?

case "$RC" in
  1)
    printf "HTTP/1.1 503 Service Unavailable\r\n"
    printf "Content-Type: text/plain\r\n\r\n"
    printf "Device behind too long\n"
    ;;
  *)
    printf "HTTP/1.1 500 Internal Server Error\r\n"
    printf "Content-Type: text/plain\r\n\r\n"
    printf "Monitor error\n"
    ;;
esac

exit 0
