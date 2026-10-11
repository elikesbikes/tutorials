#!/usr/bin/env bash
# Start Traefik on hailmary with the Cloudflare DNS-01 token from Proton Pass (HOMELAB vault, item "traefik - CF_DNS_API_TOKEN").
# The token used to live in .env; docker-compose.yml interpolates ${CF_DNS_API_TOKEN}, and a variable exported here takes
# precedence over .env, so the compose file needs no change.
#
# Host-local on purpose: Traefik is never deployed from git (the hosts differ). Do NOT use `-f docker-compose.yml` below:
# hailmary has docker-compose.override.yml (extra entry points / published ports), and naming the file drops it.
# A plain `docker compose up -d` that has to recreate Traefik renders the token empty, and certificate renewal then fails.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# pp_load: this host's PAT (TPM first), one login at most, TPM-sealed cache so a restart within 10 min does not log in and a
# Proton rate limit (429 / 2028) does not stop the start - a Traefik that cannot start takes every web service down.
source "$HOME/scripts/proton-pass/pass-secrets.sh"
pp_load traefik "Starting Traefik (Cloudflare DNS-01 token)" \
    "CF_DNS_API_TOKEN|traefik - CF_DNS_API_TOKEN|note"

cd "$SCRIPT_DIR"
docker compose up -d
