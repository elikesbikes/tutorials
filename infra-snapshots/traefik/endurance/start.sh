#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS_CLI="$HOME/.local/bin/pass-cli"
PAT_FILE="$HOME/.secrets/proton-pass-pat"
TPM_HANDLE="0x81010001"
SESSION_DIR="/tmp/pass-agent-traefik"
VAULT="HOMELAB"

export PROTON_PASS_KEY_PROVIDER=fs
export PROTON_PASS_SESSION_DIR="$SESSION_DIR"
mkdir -p "$SESSION_DIR"

# This host's own PAT: TPM-sealed first (preferred), plaintext file only as a last resort.
get_pat() {
    if command -v tpm2_unseal &>/dev/null && tpm2_unseal -c "$TPM_HANDLE" 2>/dev/null; then
        return
    fi
    if [[ -f "$PAT_FILE" ]]; then
        cat "$PAT_FILE"
        return
    fi
    echo "No PAT source available (TPM $TPM_HANDLE or $PAT_FILE)" >&2
    exit 1
}

# --- Authenticate with PAT ---
if ! "$PASS_CLI" info &>/dev/null; then
    PROTON_PASS_PERSONAL_ACCESS_TOKEN="$(get_pat)" "$PASS_CLI" login
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
