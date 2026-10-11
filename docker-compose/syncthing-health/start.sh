#!/usr/bin/env bash
# Start syncthing-health with its API key from Proton Pass (HOMELAB vault, item "syncthing-health - SYNCTHING_API_KEY").
# The key used to live in .env; compose now passes it in by name (docker-compose.yml: environment: - SYNCTHING_API_KEY).
# Always start the project through this script: a plain `docker compose up -d` recreates the container WITHOUT the key,
# and the monitors then fail at their "SYNCTHING_API_KEY not set" check.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# pp_load: this host's PAT (TPM first), one login at most, TPM-sealed cache so a restart within 10 min does not log in
# and a Proton rate limit (429 / 2028) does not stop the start. See the helper's header.
source "$HOME/scripts/proton-pass/pass-secrets.sh"
pp_load syncthing-health "Starting syncthing-health" \
    "SYNCTHING_API_KEY|syncthing-health - SYNCTHING_API_KEY|note"

# `cd`, not `-f docker-compose.yml`: naming the file drops docker-compose.override.yml (hailmary restic mounts, 2026-10-06).
cd "$SCRIPT_DIR"
docker compose up -d
