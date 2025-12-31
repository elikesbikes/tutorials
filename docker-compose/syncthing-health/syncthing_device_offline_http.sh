#!/bin/sh
# ------------------------------------------------------------
# syncthing_device_offline_http.sh
#
# Purpose:
# HTTP wrapper for syncthing-device-offline-monitor.sh,
# suitable for Uptime Kuma HTTP checks.
#
# Version: 1.0.0
#
# Changelog (running):
# - 1.0.0: Initial HTTP wrapper for offline monitor
# ------------------------------------------------------------

MONITOR="/app/syncthing-device-offline-monitor.sh"

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
