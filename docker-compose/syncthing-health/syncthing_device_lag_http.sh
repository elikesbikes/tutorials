#!/bin/sh
# ------------------------------------------------------------
# syncthing_device_lag_http.sh
#
# Version: 1.1.0
#
# Purpose:
# HTTP wrapper for syncthing-device-sync-monitor.sh
# Used by Uptime Kuma.
# ------------------------------------------------------------

set -e

MONITOR="/app/syncthing-device-sync-monitor.sh"

# File must exist, but does NOT need +x
if [[ ! -f "$MONITOR" ]]; then
  printf "HTTP/1.1 500 Internal Server Error\r\n"
  printf "Content-Type: text/plain\r\n\r\n"
  printf "Monitor script missing\n"
  exit 0
fi

if /bin/bash "$MONITOR"; then
  printf "HTTP/1.1 200 OK\r\n"
  printf "Content-Type: text/plain\r\n\r\n"
  printf "OK\n"
  exit 0
fi

RC=$?

if [[ "$RC" -eq 1 ]]; then
  printf "HTTP/1.1 503 Service Unavailable\r\n"
  printf "Content-Type: text/plain\r\n\r\n"
  printf "Device behind too long\n"
else
  printf "HTTP/1.1 500 Internal Server Error\r\n"
  printf "Content-Type: text/plain\r\n\r\n"
  printf "Monitor error\n"
fi

exit 0
