#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS_CLI="$HOME/.local/bin/pass-cli"
PAT_FILE="$HOME/.secrets/proton-pass-pat"
SESSION_DIR="/tmp/pass-agent-graylog"
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

export GRAYLOG_PASSWORD_SECRET
GRAYLOG_PASSWORD_SECRET="$(fetch_secret "Graylog - GRAYLOG_PASSWORD_SECRET" "note" \
    "Starting Graylog — encryption key for stored credentials")"

export GRAYLOG_ROOT_PASSWORD_SHA2
GRAYLOG_ROOT_PASSWORD_SHA2="$(fetch_secret "Graylog - GRAYLOG_ROOT_PASSWORD_SHA2" "note" \
    "Starting Graylog — admin password hash")"

# --- Load non-secret env vars from .env ---
set -a
while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    export "$key=$value"
done < "$SCRIPT_DIR/.env"
set +a

# --- Start the stack ---
docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d
