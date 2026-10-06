#!/usr/bin/env bash
# Start Hermes with secrets from Proton Pass. No credentials are written to disk.
# PAT: this host's own, sealed in the vTPM (handle 0x81010001). Every access is
# logged by Proton under the "endurance" token and, via syslog, in Graylog.
set -euo pipefail
cd "$(dirname "$0")"

# pp_load: this host's PAT (TPM first), one login at most, TPM-sealed cache so a restart within 10 min
# does not log in and a Proton rate limit (429 / 2028) does not stop the start. Leading ? = optional
# (exported empty when the item is missing). See ~/scripts/proton-pass/pass-secrets.sh.
source "$HOME/scripts/proton-pass/pass-secrets.sh"
pp_load hermes "Start Hermes agent" \
    "?DISCORD_BOT_TOKEN|hermes - DISCORD_BOT_TOKEN|API Key" \
    "API_SERVER_KEY|hermes - API_SERVER_KEY|password" \
    "?HASS_TOKEN|hermes - HASS_TOKEN|API Key" \
    "?HERMES_DIAG_SSH_KEY|hermes-diag|private_key"
# API_SERVER_KEY: key for Open WebUI -> Hermes API. DISCORD_BOT_TOKEN / HASS_TOKEN: Proton "API Key" items.
# HERMES_DIAG_SSH_KEY: restricted, read-only SSH key for hailmary diagnostics (generated 2026-10-02).

# Install the Hermes skills kept in this project (data/ itself is not in git).
for d in skills/*/; do n="$(basename "$d")"; mkdir -p "data/skills/devops/$n" && cp -f "$d"SKILL.md "data/skills/devops/$n/SKILL.md"; done

export HERMES_UID="$(id -u)" HERMES_GID="$(id -g)"
docker compose up -d "$@"
docker compose ps
