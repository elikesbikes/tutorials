#!/bin/sh
# Start the Garmin HTTP server in the background, then start n8n.
# The server is in the mounted volume so it's available at runtime.

GARMIN_SERVER="/home/node/garmin/garmin_server.py"

if [ -f "$GARMIN_SERVER" ]; then
  python3 "$GARMIN_SERVER" &
  echo "Garmin server started (PID $!)"
else
  echo "Warning: $GARMIN_SERVER not found, skipping Garmin server"
fi

exec n8n start
