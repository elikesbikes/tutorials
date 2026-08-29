#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS_CLI="$HOME/.local/bin/pass-cli"
PAT_FILE="$HOME/.secrets/proton-pass-pat"
SESSION_DIR="/tmp/pass-agent-authelia"
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

export AUTHELIA_JWT_SECRET
AUTHELIA_JWT_SECRET="$(fetch_secret "authelia - JWT_SECRET" "note" \
    "Starting Authelia — JWT secret for identity validation")"

export AUTHELIA_SESSION_SECRET
AUTHELIA_SESSION_SECRET="$(fetch_secret "authelia - SESSION_SECRET" "note" \
    "Starting Authelia — session cookie encryption")"

export AUTHELIA_STORAGE_ENCRYPTION_KEY
AUTHELIA_STORAGE_ENCRYPTION_KEY="$(fetch_secret "authelia - STORAGE_ENCRYPTION_KEY" "note" \
    "Starting Authelia — storage encryption key")"

export AUTHELIA_SMTP_PASSWORD
AUTHELIA_SMTP_PASSWORD="$(fetch_secret "authelia - SMTP_PASSWORD" "note" \
    "Starting Authelia — SMTP password for notifications")"

# --- Load non-secret env vars from .env ---
while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    export "$key=$value"
done < "$SCRIPT_DIR/.env"

# --- Start the stack ---
docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d
