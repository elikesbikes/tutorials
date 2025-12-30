#!/bin/sh
# ------------------------------------------------------------
# syncthing_device_lag_http.sh
#
# Version: 1.1.2
#
# Description:
# HTTP wrapper for syncthing-device-sync-monitor.sh
# Maps exit codes to HTTP responses for Uptime Kuma.
# ------------------------------------------------------------

MONITOR="/app/syncthing-device-sync-monitor.sh"

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
