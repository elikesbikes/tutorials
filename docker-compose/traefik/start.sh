#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS_CLI="$HOME/.local/bin/pass-cli"
PAT_FILE="$HOME/.secrets/proton-pass-pat"
SESSION_DIR="/tmp/pass-agent-traefik"
VAULT="HOMELAB"

export PROTON_PASS_SESSION_DIR="$SESSION_DIR"

# --- Authenticate with PAT ---
if ! "$PASS_CLI" info &>/dev/null; then
    PROTON_PASS_PERSONAL_ACCESS_TOKEN="$(cat "$PAT_FILE")" "$PASS_CLI" login
fi

# --- Fetch secrets from Proton Pass ---
fetch_secret() {
    local title="$1" field="$2" reason="$3"
    PROTON_PASS_AGENT_REASON="$reason" "$PASS_CLI" item view \
        --vault-name "$VAULT" --item-title "$title" --field "$field"
}

export CF_DNS_API_TOKEN
CF_DNS_API_TOKEN="$(fetch_secret "traefik - CF_DNS_API_TOKEN" "note" \
    "Starting Traefik — Cloudflare DNS API token for ACME DNS-01")"

# --- Load non-secret env vars from .env ---
while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    export "$key=$value"
done < "$SCRIPT_DIR/.env"

# --- Start the stack ---
docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d
