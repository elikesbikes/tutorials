#!/usr/bin/env bash
# Save a READ-ONLY snapshot of every host's real Traefik configuration into this repo,
# under infra-snapshots/traefik/<host>/.
#
# Purpose: history and backup of what each host really runs. Nothing is written to any
# host and no Traefik is restarted. Traefik is NOT deployed from git (the hosts differ:
# per-host allowlists, hailmary's extra mail ports). CI refuses to deploy "traefik".
#
# Run from tars:  scripts/snapshot-traefik.sh [host ...]      (default: tars endurance hailmary rocky)
# Then commit with gacp from the repo root.
#
# Only an allow-list of files is copied: compose file, start.sh, scripts/*.sh,
# .env.example, config/traefik.yaml, config/dynamic/*.yaml and config/dynamic-hosts/**.
# NEVER copied: .env, certs/, secrets/, acme.json, *.bak* files.
# After copying, the snapshot is scanned for secret-looking values; if anything matches,
# that host's snapshot is deleted and the script stops.
set -euo pipefail

HOSTS=("$@"); [ ${#HOSTS[@]} -gt 0 ] || HOSTS=(tars endurance hailmary rocky)
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO_ROOT/infra-snapshots/traefik"
REMOTE_DIR="devops/docker/traefik"      # relative to the home directory on each host

FILTERS=(
  --exclude='*.bak*'
  --include='docker-compose.yml' --include='docker-compose.override.yml' --include='start.sh' --include='.env.example' --include='.gitignore'
  --include='scripts/' --include='scripts/*.sh'
  --include='config/' --include='config/traefik.yaml'
  --include='config/dynamic/' --include='config/dynamic/*.yaml'
  --include='config/dynamic-hosts/' --include='config/dynamic-hosts/**'
  --include='configs/' --include='configs/traefik.yaml'
  --exclude='*'
)

# Flags (1) well-known secret formats and (2) a value of 16+ characters containing BOTH letters and digits
# assigned to a secret-looking key. Plain words, file paths and ${VAR} references do not match.
SECRET_RE='(\$apr1\$|\$2[aby]\$|-----BEGIN|glpat-|ghp_|pst_[0-9a-z]|AKIA[0-9A-Z]{8}|eyJ[A-Za-z0-9_-]{20,}|(password|passwd|secret|token|api[_-]?key)[A-Za-z_]*\s*[:=]\s*["'"'"']?(?=[A-Za-z0-9+/_.-]*\d)(?=[A-Za-z0-9+/_.-]*[A-Za-z])[A-Za-z0-9+/_.-]{16,})'

mkdir -p "$OUT"
for H in "${HOSTS[@]}"; do
  DEST="$OUT/$H"
  echo "==> $H"
  mkdir -p "$DEST"
  if [ "$H" = "tars" ]; then
    rsync -a --delete --prune-empty-dirs "${FILTERS[@]}" "$HOME/$REMOTE_DIR/" "$DEST/"
  else
    rsync -a --delete --prune-empty-dirs "${FILTERS[@]}" -e "ssh -o BatchMode=yes" "$H:$REMOTE_DIR/" "$DEST/"
  fi
  # secret scan (lines that merely mention a ${VARIABLE} are ignored)
  HITS="$(grep -rIiPn "$SECRET_RE" "$DEST" | grep -v -E '\$\{[A-Za-z_]+' || true)"
  if [ -n "$HITS" ]; then
    echo "ABORT: secret-looking content in the $H snapshot - deleting it:" >&2
    printf '%s\n' "$HITS" | sed -E 's/(.{0,90}).*/\1.../' >&2
    rm -rf "$DEST"
    exit 1
  fi
  echo "    $(find "$DEST" -type f | wc -l) files saved, secret scan clean"
done
echo "Done. Review with: git -C $REPO_ROOT status --short infra-snapshots"
