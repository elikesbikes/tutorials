#!/usr/bin/env bash
# Plan / apply the desired Traefik files (infra/traefik) to ONE host. Run from tars.
#
#   sync-traefik.sh <host>            PLAN: show what would change (diff), write nothing
#   sync-traefik.sh <host> --apply    APPLY: back up every file it replaces, copy the new files in one go,
#                                     write an exact rollback script, check the compose file.
#                                     It does NOT restart Traefik.
#
# Restarting is a separate, deliberate step (see the message printed at the end), because on
# hailmary Traefik is also the front door to GitLab. Deploy of "traefik" through the GitLab
# pipeline stays refused on purpose.
#
# Managed files (per host): docker-compose.yml, config/traefik.yaml, config/dynamic/middlewares.yaml,
# everything in config/dynamic-hosts/<host>/, and docker-compose.override.yml (hailmary only).
# Never touched: .env, certs/, secrets/, start.sh, scripts/, anything not listed above. Nothing is deleted.
#
# Every apply creates <traefik dir>/.sync-backups/<time>/ on the host containing
#   - the previous version of each file it replaced,
#   - NEW_FILES.txt: files that did not exist before (they are removed again by a rollback), and
#   - rollback.sh: puts the old files back and removes the new ones (does not restart Traefik).
#
# Test mode (no host involved): SYNC_LOCAL_DIR=/some/dir sync-traefik.sh tars --apply
set -euo pipefail

HOST="${1:?usage: sync-traefik.sh <tars|endurance|hailmary|rocky> [--apply]}"
MODE="${2:-plan}"
case "$HOST" in tars|endurance|hailmary|rocky) ;; *) echo "unknown host: $HOST" >&2; exit 2;; esac
case "$MODE" in plan|--apply) ;; *) echo "unknown option: $MODE" >&2; exit 2;; esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHARED="$ROOT/infra/traefik/shared"
HOSTSRC="$ROOT/infra/traefik/hosts/$HOST"
[ -d "$HOSTSRC" ] || { echo "no desired state for $HOST in $HOSTSRC" >&2; exit 2; }

if [ -n "${SYNC_LOCAL_DIR:-}" ]; then               # test mode
  run() { bash -c "$1"; }
  RDIR="$SYNC_LOCAL_DIR"; RSYNC_DEST="$SYNC_LOCAL_DIR/"; TESTMODE=1
elif [ "$HOST" = "tars" ]; then
  run() { bash -c "$1"; }
  RDIR="$HOME/devops/docker/traefik"; RSYNC_DEST="$RDIR/"; TESTMODE=0
else
  run() { ssh -n -o BatchMode=yes "$HOST" "$1"; }
  RDIR="devops/docker/traefik"; RSYNC_DEST="$HOST:$RDIR/"; TESTMODE=0
fi
copy_to_host() {   # copy_to_host <local file> <path relative to the traefik dir>
  if [ "$TESTMODE" = 1 ] || [ "$HOST" = "tars" ]; then cp "$1" "$RDIR/$2"; else scp -q "$1" "$HOST:$RDIR/$2"; fi
}

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
  if run "test -f '$RDIR/$path'"; then
    diff -u --label "host:$path" --label "desired:$path" <(run "cat '$RDIR/$path'") "$STAGE/$path" || true
  else
    echo "--- new file: $path ($(wc -l < "$STAGE/$path") lines)"
  fi
done < <(echo "$CHANGES" | awk '{print $1, $2}')

if [ "$MODE" = "plan" ]; then
  echo; echo "PLAN ONLY - nothing was written. Re-run with --apply to copy these files (Traefik is not restarted)."
  exit 0
fi

TS="${SYNC_TS:-$(date +%Y%m%d-%H%M%S)}"
BK=".sync-backups/$TS"
echo; echo "==> APPLY: backing up replaced files to $BK and copying (single rsync run)"
NEWFILES="$(echo "$CHANGES" | awk '$1 ~ /^[<>]f\+\+\+\+\+\+\+\+\+$/ {print $2}')"
rsync "${RSYNC_COMMON[@]}" --backup --backup-dir="$BK" -e "ssh -o BatchMode=yes" "$STAGE/" "$RSYNC_DEST"

# NEW_FILES.txt and rollback.sh (written AFTER the copy, into the backup folder)
printf '%s\n' "$NEWFILES" > "$STAGE/NEW_FILES.txt"
cat > "$STAGE/rollback.sh" <<EOF
#!/usr/bin/env bash
# Rollback of sync $TS for $HOST: put the previous files back and remove the files that sync created.
# Does NOT restart Traefik (do that on purpose afterwards).
set -euo pipefail
cd "\$(dirname "\$0")/../.."
BK="$BK"
[ -d "\$BK" ] || { echo "backup folder \$BK not found" >&2; exit 1; }
rsync -a --exclude rollback.sh --exclude NEW_FILES.txt "\$BK/" ./
while IFS= read -r f; do [ -n "\$f" ] && [ -f "\$f" ] && rm -f -- "\$f" && echo "removed new file: \$f"; done < "\$BK/NEW_FILES.txt"
echo "rolled back sync $TS"
EOF
chmod 755 "$STAGE/rollback.sh"
run "mkdir -p '$RDIR/$BK'"
copy_to_host "$STAGE/NEW_FILES.txt" "$BK/NEW_FILES.txt"
copy_to_host "$STAGE/rollback.sh"   "$BK/rollback.sh"
run "chmod 755 '$RDIR/$BK/rollback.sh'"

if [ "$TESTMODE" = 0 ]; then
  echo "==> checking the compose file on the host"
  run "cd '$RDIR' && docker compose config -q" && echo "    compose file valid"
  run "logger -t traefik-sync 'host=$HOST applied=$TS by=${USER:-?}'" || true
fi

cat <<EOF

APPLIED. Traefik is still running the OLD configuration until it is restarted.
New files created: $(echo "$NEWFILES" | tr '\n' ' ')
Roll back the files:   ssh $HOST '~/$RDIR/$BK/rollback.sh'      (restores old files AND removes the new ones)
Restart when ready:    ssh $HOST 'docker restart traefik'       (a few seconds without web access on $HOST)
Then check:            scripts/traefik_smoke.py $HOST --compare <baseline file>
EOF
