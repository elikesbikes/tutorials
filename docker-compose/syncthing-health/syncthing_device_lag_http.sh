#!/bin/sh
# ------------------------------------------------------------
# syncthing_device_lag_http.sh
#
# Version: 1.1.0
#
# Description:
# HTTP wrapper for syncthing-device-sync-monitor.sh
# Maps exit codes to HTTP responses for Uptime Kuma.
# ------------------------------------------------------------

MONITOR="/app/syncthing-device-sync-monitor.sh"
BASH="/bin/bash"

# Validate runtime
if [ ! -x "$BASH" ]; then
  printf "HTTP/1.1 500 Internal Server Error\r\n\r\nbash not available\n"
  exit 0
fi

if [ ! -f "$MONITOR" ]; then
  printf "HTTP/1.1 500 Internal Server Error\r\n\r\nMonitor script missing\n"
  exit 0
fi

# Execute monitor explicitly with bash
$BASH "$MONITOR"
RC=$?

if [ "$RC" -eq 0 ]; then
  printf "HTTP/1.1 200 OK\r\n\r\nOK\n"
  exit 0
fi

if [ "$RC" -eq 1 ]; then
  printf "HTTP/1.1 503 Service Unavailable\r\n\r\nDevice behind too long\n"
  exit 0
fi

printf "HTTP/1.1 500 Internal Server Error\r\n\r\nMonitor error\n"
exit 0
