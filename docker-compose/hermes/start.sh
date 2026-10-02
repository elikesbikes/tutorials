#!/usr/bin/env bash
# Start Hermes with secrets from Proton Pass. No credentials are written to disk.
# PAT: this host's own, sealed in the vTPM (handle 0x81010001). Every access is
# logged by Proton under the "endurance" token and, via syslog, in Graylog.
set -euo pipefail
cd "$(dirname "$0")"

PASS_CLI="$HOME/.local/bin/pass-cli"
VAULT="HOMELAB"
export PROTON_PASS_KEY_PROVIDER=fs
export PROTON_PASS_SESSION_DIR="$(mktemp -d /tmp/pass-agent-hermes.XXXXXX)"
trap '"$PASS_CLI" logout --force >/dev/null 2>&1 || true; rm -rf "$PROTON_PASS_SESSION_DIR"' EXIT

PROTON_PASS_PERSONAL_ACCESS_TOKEN="$(tpm2_unseal -c 0x81010001)" "$PASS_CLI" login >/dev/null

fetch() {   # fetch <VAR> <item title> <field> <required|optional>
  local val
  if val="$(PROTON_PASS_AGENT_REASON="Start Hermes agent on endurance: $1" \
      "$PASS_CLI" item view --vault-name "$VAULT" --item-title "$2" --field "$3" 2>/dev/null)" && [ -n "$val" ]; then
    export "$1=$val"
  elif [ "$4" = required ]; then
    echo "ERROR: Proton Pass item '$2' (field $3) not found in $VAULT" >&2; exit 1
  else
    export "$1="
  fi
}

fetch DISCORD_BOT_TOKEN     "hermes - DISCORD_BOT_TOKEN"     password optional
fetch DISCORD_ALLOWED_USERS "hermes - DISCORD_ALLOWED_USERS" note     optional

export HERMES_UID="$(id -u)" HERMES_GID="$(id -g)"
docker compose up -d "$@"
docker compose ps
