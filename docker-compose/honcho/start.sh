#!/usr/bin/env bash
# Start Honcho with its database password from Proton Pass. No credentials are written to disk.
# PAT: this host's own, sealed in the vTPM (handle 0x81010001).
set -euo pipefail
cd "$(dirname "$0")"

# pp_load: this host's PAT (TPM first), one login at most, TPM-sealed cache so a restart within 10 min
# does not log in and a Proton rate limit (429 / 2028) does not stop the start.
# See ~/scripts/proton-pass/pass-secrets.sh.
source "$HOME/scripts/proton-pass/pass-secrets.sh"
pp_load honcho "Start Honcho (database password)" \
    "POSTGRES_PASSWORD|honcho - POSTGRES_PASSWORD|password"
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
