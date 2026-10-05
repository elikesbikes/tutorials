#!/usr/bin/env bash
# Plan / apply the desired Traefik files (infra/traefik) to ONE host. Run from tars.
#
#   sync-traefik.sh <host>            PLAN: show what would change (diff), write nothing
#   sync-traefik.sh <host> --apply    APPLY: back up every file it replaces, copy the new files in one go,
#                                     check the compose file. It does NOT restart Traefik.
#
# Restarting is a separate, deliberate step (see the message printed at the end), because on
# hailmary Traefik is also the front door to GitLab. Deploy of "traefik" through the GitLab
# pipeline stays refused on purpose.
#
# Managed files (per host): docker-compose.yml, config/traefik.yaml, config/dynamic/middlewares.yaml,
# everything in config/dynamic-hosts/<host>/, and docker-compose.override.yml (hailmary only).
# Never touched: .env, certs/, secrets/, start.sh, scripts/, anything not listed above. Nothing is deleted.
# Backups of replaced files go to <traefik dir>/.sync-backups/<time>/ on the host.
set -euo pipefail

HOST="${1:?usage: sync-traefik.sh <tars|endurance|hailmary|rocky> [--apply]}"
MODE="${2:-plan}"
case "$HOST" in tars|endurance|hailmary|rocky) ;; *) echo "unknown host: $HOST" >&2; exit 2;; esac
case "$MODE" in plan|--apply) ;; *) echo "unknown option: $MODE" >&2; exit 2;; esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHARED="$ROOT/infra/traefik/shared"
HOSTSRC="$ROOT/infra/traefik/hosts/$HOST"
[ -d "$HOSTSRC" ] || { echo "no desired state for $HOST in $HOSTSRC" >&2; exit 2; }

REMOTE_REL="devops/docker/traefik"
if [ "$HOST" = "tars" ]; then
  run() { bash -c "$1"; }
  RSYNC_DEST="$HOME/$REMOTE_REL/"
else
  run() { ssh -n -o BatchMode=yes "$HOST" "$1"; }
  RSYNC_DEST="$HOST:$REMOTE_REL/"
fi

# Build the exact tree we want on the host, in a temp dir (same layout as the host's traefik folder).
STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/config/dynamic" "$STAGE/config/dynamic-hosts/$HOST"
cp "$SHARED/docker-compose.yml"                  "$STAGE/docker-compose.yml"
cp "$SHARED/config/traefik.yaml"                 "$STAGE/config/traefik.yaml"
cp "$SHARED/config/dynamic/middlewares.yaml"     "$STAGE/config/dynamic/middlewares.yaml"
cp -a "$HOSTSRC/config/dynamic-hosts/$HOST/."    "$STAGE/config/dynamic-hosts/$HOST/"
[ -f "$HOSTSRC/docker-compose.override.yml" ] && cp "$HOSTSRC/docker-compose.override.yml" "$STAGE/docker-compose.override.yml"

RSYNC_COMMON=(-rc --no-owner --no-group --no-perms --chmod=F644,D755)

echo "==> $HOST: files that differ from the desired state"
CHANGES="$(rsync "${RSYNC_COMMON[@]}" -n --itemize-changes -e "ssh -o BatchMode=yes" "$STAGE/" "$RSYNC_DEST" | grep -v '^\.d' || true)"
if [ -z "$CHANGES" ]; then echo "    nothing to do: the host already matches."; exit 0; fi
echo "$CHANGES" | sed 's/^/    /'

echo; echo "==> content differences (- on the host now, + desired)"
while read -r _flags path; do
  [ -f "$STAGE/$path" ] || continue
  if run "test -f ~/$REMOTE_REL/$path"; then
    diff -u --label "host:$path" --label "desired:$path" <(run "cat ~/$REMOTE_REL/$path") "$STAGE/$path" || true
  else
    echo "--- new file: $path ($(wc -l < "$STAGE/$path") lines)"
  fi
done < <(echo "$CHANGES" | awk '{print $1, $2}')

if [ "$MODE" = "plan" ]; then
  echo; echo "PLAN ONLY - nothing was written. Re-run with --apply to copy these files (Traefik is not restarted)."
  exit 0
fi

TS="$(date +%Y%m%d-%H%M%S)"
echo; echo "==> APPLY: backing up replaced files to .sync-backups/$TS and copying (single rsync run)"
rsync "${RSYNC_COMMON[@]}" --backup --backup-dir=".sync-backups/$TS" -e "ssh -o BatchMode=yes" "$STAGE/" "$RSYNC_DEST"

echo "==> checking the compose file on the host"
run "cd ~/$REMOTE_REL && docker compose config -q" && echo "    compose file valid"
run "logger -t traefik-sync 'host=$HOST applied=$TS by=${USER:-?}'" || true

cat <<EOF

APPLIED. Traefik is still running the OLD configuration until it is restarted.
Roll back the files:   ssh $HOST 'cd ~/$REMOTE_REL && rsync -a .sync-backups/$TS/ ./'   (new files stay; they are harmless)
Restart when ready:    ssh $HOST 'docker restart traefik'     (a few seconds without web access on $HOST)
Then check:            scripts/traefik_smoke.py $HOST --compare <baseline file>
EOF
