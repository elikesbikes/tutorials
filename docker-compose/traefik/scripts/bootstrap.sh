#!/usr/bin/env bash
#
# Traefik one-time host bootstrap.
# Idempotent: re-running only fills in whatever is missing, then starts the stack.
#
# Usage:  cd <project-dir> && ./scripts/bootstrap.sh
#
set -euo pipefail

# Resolve project root (parent of this script's dir) and work from there.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[warn] %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m[error] %s\033[0m\n' "$*" >&2; exit 1; }

# 1. frontend network ---------------------------------------------------------
say "Checking 'frontend' docker network"
if ! docker network inspect frontend >/dev/null 2>&1; then
  warn "'frontend' network missing — creating it"
  docker network create frontend
else
  echo "ok"
fi

# 2. socket-proxy -------------------------------------------------------------
say "Checking socket-proxy (Traefik's docker provider needs it)"
if ! docker ps --filter name=socket-proxy --filter status=running --format '{{.Names}}' | grep -q socket-proxy; then
  warn "socket-proxy is not running. Traefik will log provider errors until it is up."
else
  echo "ok"
fi

# 3. ports 80/443 -------------------------------------------------------------
say "Checking ports 80/443 are free"
if ss -tlnH 2>/dev/null | grep -qE ':80\s|:443\s'; then
  warn "Something is already listening on :80 or :443 — Traefik may fail to bind."
else
  echo "ok"
fi

# 4. .env ---------------------------------------------------------------------
say "Checking .env"
if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example."
  read -rp "Cloudflare DNS API token: " CF_TOKEN
  read -rp "Dashboard hostname (e.g. proxy-$(hostname -s).home.elikesbikes.com): " DASH_HOST
  sed -i "s|^CF_DNS_API_TOKEN=.*|CF_DNS_API_TOKEN=${CF_TOKEN}|" .env
  sed -i "s|^TRAEFIK_DASHBOARD_HOST=.*|TRAEFIK_DASHBOARD_HOST=${DASH_HOST}|" .env
  echo ".env written."
else
  echo "ok (.env exists — leaving it untouched)"
fi

# Load PUID/PGID for ownership steps below.
# shellcheck disable=SC1091
set -a; source .env; set +a
PUID="${PUID:-1000}"; PGID="${PGID:-1000}"

# 5. dashboard htpasswd -------------------------------------------------------
say "Checking secrets/dashboard.htpasswd"
mkdir -p secrets
if [[ ! -f secrets/dashboard.htpasswd ]]; then
  command -v htpasswd >/dev/null 2>&1 || die "htpasswd not found (install apache2-utils)."
  read -rp "Dashboard username [admin]: " DASH_USER
  DASH_USER="${DASH_USER:-admin}"
  read -rsp "Dashboard password (shared across hosts): " DASH_PASS; echo
  htpasswd -nbB "${DASH_USER}" "${DASH_PASS}" > secrets/dashboard.htpasswd
  chmod 600 secrets/dashboard.htpasswd
  echo "secrets/dashboard.htpasswd created."
else
  echo "ok (already present)"
fi

# 6. acme.json ----------------------------------------------------------------
say "Ensuring certs/acme.json exists with strict perms"
mkdir -p certs
touch certs/acme.json
chmod 600 certs/acme.json
# Best-effort ownership (needs privileges if current user differs).
chown "${PUID}:${PGID}" certs/acme.json secrets/dashboard.htpasswd 2>/dev/null \
  || warn "Could not chown to ${PUID}:${PGID} (run with sudo if Traefik can't write acme.json)."
echo "ok"

# 7. up -----------------------------------------------------------------------
say "Validating compose config"
docker compose config >/dev/null
say "Starting Traefik"
docker compose up -d

say "Done. Tail logs with:  docker logs -f traefik"
echo "Dashboard: https://${TRAEFIK_DASHBOARD_HOST:-<set TRAEFIK_DASHBOARD_HOST>}"
echo "Reminder: ensure a DNS A record points that hostname to this host."
