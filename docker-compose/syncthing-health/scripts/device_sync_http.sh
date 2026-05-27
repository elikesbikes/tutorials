#!/bin/sh
# ------------------------------------------------------------
# device_sync_http.sh
#
# Purpose:
# HTTP wrapper for device_sync_monitor.sh, suitable
# for Uptime Kuma HTTP checks.
#
# Version: 1.1.2
#
# Changelog (running):
# - 1.1.2: Renamed to device_sync_http.sh; moved to scripts/; update monitor path
# - 1.1.1: Force /bin/bash execution; align exit-code mapping
# - 1.1.0: Initial HTTP wrapper for device-lag monitor
# -----------------------------------------------------------

MONITOR="/app/device_sync_monitor.sh"

if [ ! -x "$MONITOR" ]; then
  printf "HTTP/1.1 500 Internal Server Error\r\n"
  printf "Content-Type: text/plain\r\n\r\n"
  printf "Monitor script not executable\n"
  exit 0
fi

if /bin/bash "$MONITOR"; then
  printf "HTTP/1.1 200 OK\r\n"
  printf "Content-Type: text/plain\r\n\r\n"
  printf "OK\n"
  exit 0
fi

printf "HTTP/1.1 500 Internal Server Error\r\n"
printf "Content-Type: text/plain\r\n\r\n"
printf "Monitor error\n"
exit 0
