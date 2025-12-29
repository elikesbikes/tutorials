#!/usr/bin/env bash
# ------------------------------------------------------------
# syncthing_health_http.sh
# Version: 1.0.0
# ------------------------------------------------------------

set -euo pipefail

PORT=9123

while true; do
  {
    if /app/syncthing_health.sh >/tmp/health.out 2>&1; then
      echo -e "HTTP/1.1 200 OK\r\n\r\n$(cat /tmp/health.out)"
    else
      echo -e "HTTP/1.1 500 Internal Server Error\r\n\r\n$(cat /tmp/health.out)"
    fi
  } | nc -l -p "$PORT" -q 1
done
