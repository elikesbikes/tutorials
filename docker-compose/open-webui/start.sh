#!/usr/bin/env bash
# Start Open WebUI with its secrets from Proton Pass. No credentials are written to disk.
# PAT: this host's own, sealed in the vTPM (handle 0x81010001).
set -euo pipefail
cd "$(dirname "$0")"

# pp_load: this host's PAT (TPM first), one login at most, TPM-sealed cache so a restart within 10 min
# does not log in and a Proton rate limit (429 / 2028) does not stop the start.
# See ~/scripts/proton-pass/pass-secrets.sh.
source "$HOME/scripts/proton-pass/pass-secrets.sh"
pp_load open-webui "Start Open WebUI" \
    "OPENAI_API_KEY|hermes - API_SERVER_KEY|password" \
    "WEBUI_SECRET_KEY|open-webui - WEBUI_SECRET_KEY|password" \
    "OAUTH_CLIENT_SECRET|open-webui - OIDC_CLIENT_SECRET|password"
# OPENAI_API_KEY must equal the Hermes API server key; for OAUTH_CLIENT_SECRET the Authelia side stores its hash.

mkdir -p data
docker compose up -d "$@"
docker compose ps
