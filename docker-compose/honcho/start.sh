#!/usr/bin/env bash
# Start Honcho with its database password from Proton Pass. No credentials are written to disk.
# PAT: this host's own, sealed in the vTPM (handle 0x81010001).
set -euo pipefail
cd "$(dirname "$0")"

PASS_CLI="$HOME/.local/bin/pass-cli"
VAULT="HOMELAB"
export PROTON_PASS_KEY_PROVIDER=fs
export PROTON_PASS_SESSION_DIR="$(mktemp -d /tmp/pass-agent-honcho.XXXXXX)"
trap '"$PASS_CLI" logout --force >/dev/null 2>&1 || true; rm -rf "$PROTON_PASS_SESSION_DIR"' EXIT

PROTON_PASS_PERSONAL_ACCESS_TOKEN="$(tpm2_unseal -c 0x81010001)" "$PASS_CLI" login >/dev/null

POSTGRES_PASSWORD="$(PROTON_PASS_AGENT_REASON="Start Honcho on endurance: database password" \
  "$PASS_CLI" item view --vault-name "$VAULT" --item-title "honcho - POSTGRES_PASSWORD" --field password 2>/dev/null)" \
  || { echo "ERROR: Proton Pass item 'honcho - POSTGRES_PASSWORD' not found in $VAULT" >&2; exit 1; }
[ -n "$POSTGRES_PASSWORD" ] || { echo "ERROR: empty database password" >&2; exit 1; }
export POSTGRES_PASSWORD
# The password may contain URL-reserved characters, so encode it for the connection URI.
export DB_CONNECTION_URI="postgresql+psycopg://postgres:$(python3 -c 'import sys,urllib.parse as u; print(u.quote(sys.argv[1], safe=""))' "$POSTGRES_PASSWORD")@honcho-db:5432/postgres"

mkdir -p data/postgres data/redis
docker compose up -d --wait honcho-db honcho-redis "$@"

# First-run schema: migrations create vector(1536) columns; resize them to EMBEDDING_VECTOR_DIMENSIONS (768, nomic-embed-text).
# Both steps are idempotent, so running them on every start is safe.
RUN=(docker compose run --rm --no-deps -T --entrypoint /app/.venv/bin/python honcho-api)
"${RUN[@]}" scripts/provision_db.py
"${RUN[@]}" scripts/configure_embeddings.py --yes

docker compose up -d "$@"
docker compose ps
