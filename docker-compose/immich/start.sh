#!/usr/bin/env bash
# Start immich with its database password from Proton Pass (HOMELAB vault, item "immich - <KEY> - <host>").
# The password used to live in .env. Always start the project through this script: a plain `docker compose up -d` that has to
# recreate a container renders the password as an empty string and the application can no longer reach its database.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# pp_load: this host's PAT (TPM first), one login at most, TPM-sealed cache so a restart within 10 min does not log in and a
# Proton rate limit (429 / 2028) does not stop the start. See the helper's header.
source "$HOME/scripts/proton-pass/pass-secrets.sh"
HOST="$(hostname -s)"
pp_load immich "Starting immich" \
    "DB_PASSWORD|immich - DB_PASSWORD - ${HOST}|note"

# `cd`, not `-f docker-compose.yml`: naming the file drops docker-compose.override.yml (hailmary restic mounts, 2026-10-06).
cd "$SCRIPT_DIR"
docker compose up -d
