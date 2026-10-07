#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Secrets from Proton Pass (HOMELAB vault) ---
# pp_load: this host's PAT (TPM first), one login at most, TPM-sealed cache so a restart within 10 min
# does not log in and a Proton rate limit (429 / 2028) does not stop the start. See the helper's header.
source "$HOME/scripts/proton-pass/pass-secrets.sh"
# The repository password differs per host (each host has its own restic repository): hailmary's lives in its own Proton item,
# every other host keeps the original one. Unknown hosts fall back to the original, as before.
case "$(hostname -s)" in
    hailmary) RESTIC_PASSWORD_ITEM="restic - RESTIC_PASSWORD - hailmary" ;;
    *)        RESTIC_PASSWORD_ITEM="restic - RESTIC_PASSWORD" ;;
esac
pp_load restic "Starting restic" \
    "RESTIC_PASSWORD|${RESTIC_PASSWORD_ITEM}|note"

# --- Load non-secret env vars from .env ---
while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    export "$key=$value"
done < "$SCRIPT_DIR/.env"

# --- Start the stack ---
docker compose -f "$SCRIPT_DIR/docker-compose.yml" -f "$SCRIPT_DIR/docker-compose.override.yml" up -d
