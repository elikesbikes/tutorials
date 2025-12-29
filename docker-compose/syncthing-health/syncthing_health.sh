#!/usr/bin/env bash
# ------------------------------------------------------------
# syncthing_health.sh
# Version: 1.0.0
# ------------------------------------------------------------

set -euo pipefail

: "${SYNCTHING_URL:?SYNCTHING_URL not set}"
: "${SYNCTHING_API_KEY:?SYNCTHING_API_KEY not set}"

HEADER=(-H "X-API-Key: $SYNCTHING_API_KEY")

if ! curl -sf "${HEADER[@]}" "$SYNCTHING_URL/rest/system/status" >/dev/null; then
  echo "ERROR: Syncthing API unreachable"
  exit 1
fi

FOLDERS=$(curl -sf "${HEADER[@]}" "$SYNCTHING_URL/rest/config" \
  | jq -r '.folders[].id')

for folder in $FOLDERS; do
  state=$(curl -sf "${HEADER[@]}" \
    "$SYNCTHING_URL/rest/db/status?folder=$folder" \
    | jq -r '.state')

  if [[ "$state" == "error" ]]; then
    echo "ERROR: Folder in error state: $folder"
    exit 1
  fi
done

echo "OK: All folders healthy"
exit 0
