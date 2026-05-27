#!/bin/sh
# ------------------------------------------------------------
# device_offline_http.sh
#
# Purpose:
# HTTP wrapper for device_offline_monitor.sh,
# suitable for Uptime Kuma HTTP checks.
#
# Version: 1.0.1
#
# Changelog (running):
# - 1.0.1: Renamed to device_offline_http.sh; moved to scripts/; update monitor path
# - 1.0.0: Initial HTTP wrapper for offline monitor
# ------------------------------------------------------------

MONITOR="/app/device_offline_monitor.sh"

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
printf "Device offline\n"
exit 0
