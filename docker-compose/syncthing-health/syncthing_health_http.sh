#!/bin/sh
# ------------------------------------------------------------
# syncthing_health_http.sh
#
# Version: 1.5.1
#
# Description:
# HTTP endpoint wrapper for syncthing_health.sh
# Designed for Uptime Kuma via socat.
#
# Exit code mapping:
#   0 -> 200 OK
#   1 -> 503 Service Unavailable
#   * -> 500 Internal Server Error
# ------------------------------------------------------------

set -eu

HEALTH_SCRIPT="/app/syncthing_health.sh"

if /bin/bash "$HEALTH_SCRIPT"; then
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
    printf "Service unhealthy\n"
    ;;
  *)
    printf "HTTP/1.1 500 Internal Server Error\r\n"
    printf "Content-Type: text/plain\r\n\r\n"
    printf "Service error\n"
    ;;
esac

exit 0
