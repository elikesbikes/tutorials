#!/usr/bin/env bash
# Start Open WebUI with its secrets from Proton Pass. No credentials are written to disk.
# PAT: this host's own, sealed in the vTPM (handle 0x81010001).
set -euo pipefail
cd "$(dirname "$0")"

PASS_CLI="$HOME/.local/bin/pass-cli"
VAULT="HOMELAB"
export PROTON_PASS_KEY_PROVIDER=fs
export PROTON_PASS_SESSION_DIR="$(mktemp -d /tmp/pass-agent-open-webui.XXXXXX)"
trap '"$PASS_CLI" logout --force >/dev/null 2>&1 || true; rm -rf "$PROTON_PASS_SESSION_DIR"' EXIT

PROTON_PASS_PERSONAL_ACCESS_TOKEN="$(tpm2_unseal -c 0x81010001)" "$PASS_CLI" login >/dev/null

fetch() {   # fetch <VAR> <item title>   (login items, field "password"; all required)
  local val
  val="$(PROTON_PASS_AGENT_REASON="Start Open WebUI on endurance: $1" \
      "$PASS_CLI" item view --vault-name "$VAULT" --item-title "$2" --field password 2>/dev/null)" && [ -n "$val" ] \
    || { echo "ERROR: Proton Pass item '$2' (field password) not found in $VAULT" >&2; exit 1; }
  export "$1=$val"
}
fetch OPENAI_API_KEY      "hermes - API_SERVER_KEY"          # must equal the Hermes API server key
fetch WEBUI_SECRET_KEY    "open-webui - WEBUI_SECRET_KEY"
fetch OAUTH_CLIENT_SECRET "open-webui - OIDC_CLIENT_SECRET"  # the Authelia side stores its hash

mkdir -p data
docker compose up -d "$@"
docker compose ps
