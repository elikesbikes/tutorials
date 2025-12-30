#!/usr/bin/env bash
# syncthing_device_lag_http.sh
#
# Service: syncthing-health
# Script: syncthing_device_lag_http.sh
# Version: 1.1.1
#
# Description:
# Minimal HTTP responder invoked by socat. Runs the device lag monitor
# and returns HTTP status codes for Uptime Kuma.
#
# HTTP mapping:
#   - exit 0 -> 200 OK
#   - exit 1 -> 503 Service Unavailable
#   - other  -> 500 Internal Server Error
#
# Changelog (running):
# - 1.1.1: Fix executable check bug; always run monitor via /bin/bash
# - 1.1.0: Initial version
#
set -euo pipefail

MONITOR="/app/syncthing-device-sync-monitor.sh"
BASH_BIN="/bin/bash"

if [[ ! -x "$BASH_BIN" ]]; then
  printf "HTTP/1.1 500 Internal Server Error\r\n\r\nbash not found at %s\n" "$BASH_BIN"
  exit 0
fi

if [[ ! -f "$MONITOR" ]]; then
  printf "HTTP/1.1 500 Internal Server Error\r\n\r\nScript missing: %s\n" "$MONITOR"
  exit 0
fi

if "$BASH_BIN" "$MONITOR"; then
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
