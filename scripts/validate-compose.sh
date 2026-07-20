#!/usr/bin/env bash
set -euo pipefail

# Sanity-checks a docker-compose project's YAML before a deploy pipeline
# proceeds to preflight/deploy. Usage: validate-compose.sh <path-to-project>
#
# Missing entirely until 2026-07-20 (validate:compose in .gitlab-ci.yml
# referenced this file but it was never committed) — every pipeline run
# failed at the validate stage regardless of project, blocking all deploys.

PROJECT_DIR="${1:?Usage: validate-compose.sh <project-dir>}"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "ERROR: project directory not found: $PROJECT_DIR" >&2
  exit 1
fi

COMPOSE_FILE=""
for candidate in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  if [ -f "$PROJECT_DIR/$candidate" ]; then
    COMPOSE_FILE="$PROJECT_DIR/$candidate"
    break
  fi
done

if [ -z "$COMPOSE_FILE" ]; then
  echo "ERROR: no docker-compose.yml (or .yaml/compose.yml) found in $PROJECT_DIR" >&2
  exit 1
fi

echo "Validating $COMPOSE_FILE..."
# --no-interpolate: CI checkouts never have the project's .env (git-ignored,
# host-local secrets) or docker-compose.override.yml, so full `config`
# resolution fails on missing env vars/env_file. This only checks YAML
# structure, which is all a pre-deploy sanity check needs.
docker compose -f "$COMPOSE_FILE" config --no-interpolate >/dev/null
echo "✓ $COMPOSE_FILE is valid"
