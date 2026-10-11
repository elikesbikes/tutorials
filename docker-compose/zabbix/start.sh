#!/usr/bin/env bash
# Start Zabbix with its MySQL passwords from Proton Pass (HOMELAB vault, items "zabbix - <KEY> - <host>").
# The passwords used to live in .env; docker-compose.yml interpolates ${MYSQL_PASSWORD} / ${MYSQL_ROOT_PASSWORD}, and a variable
# exported here takes precedence over .env for that interpolation, so the compose file needs no change.
# Always start the project through this script: a plain `docker compose up -d` that has to recreate a container renders the
# password as an empty string, and the server/web containers then cannot reach the database.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# pp_load: this host's PAT (TPM first), one login at most, TPM-sealed cache so a restart within 10 min does not log in and a
# Proton rate limit (429 / 2028) does not stop the start. See the helper's header.
source "$HOME/scripts/proton-pass/pass-secrets.sh"
HOST="$(hostname -s)"
pp_load zabbix "Starting zabbix" \
    "MYSQL_PASSWORD|zabbix - MYSQL_PASSWORD - ${HOST}|note" \
    "MYSQL_ROOT_PASSWORD|zabbix - MYSQL_ROOT_PASSWORD - ${HOST}|note"

# `cd`, not `-f docker-compose.yml`: naming the file drops docker-compose.override.yml (hailmary restic mounts, 2026-10-06).
cd "$SCRIPT_DIR"
docker compose up -d
