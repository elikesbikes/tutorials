#!/usr/bin/env bash
# Run ON the host (copied there by hand). Restart Traefik, then check that key addresses answer
# exactly as before. If they do not within WAIT seconds, run the rollback of the given sync
# (restores the old files and removes the new ones), restart again, and check once more.
#
# Usage: traefik-restart-guarded.sh <sync-backup-folder-name> <address=expected-http-code> [...]
#   e.g. traefik-restart-guarded.sh 20261005-170000 gitlab.home.elikesbikes.com=302 auth.home.elikesbikes.com=200
#
# Output goes to ~/traefik-guarded-restart.<backup>.log (so it still completes if the ssh session
# that started it drops). Final line is RESULT=OK | RESULT=ROLLED_BACK_OK | RESULT=ROLLBACK_FAILED.
# Exit codes: 0 ok, 2 rolled back and healthy, 3 rolled back and STILL failing (manual action).
# Requests go to this host's own Traefik on 127.0.0.1:443 (TLS not verified), one GET / per address.
set -uo pipefail

BK="${1:?usage: traefik-restart-guarded.sh <backup-folder-name> <address=code> [...]}"; shift
CHECKS=("$@"); [ ${#CHECKS[@]} -gt 0 ] || { echo "give at least one address=code" >&2; exit 64; }
TRAEFIK_DIR="${TRAEFIK_DIR:-$HOME/devops/docker/traefik}"
WAIT="${WAIT:-40}"
LOG="$HOME/traefik-guarded-restart.$BK.log"
exec >>"$LOG" 2>&1

log() { echo "$(date +%T) $*"; }

check_all() {
  local c n want got
  for c in "${CHECKS[@]}"; do
    n="${c%%=*}"; want="${c##*=}"
    got="$(curl -sk -o /dev/null -m 4 -w '%{http_code}' --resolve "$n:443:127.0.0.1" "https://$n/" 2>/dev/null)"
    [ "$got" = "$want" ] || { echo "   $n: wanted $want, got ${got:-none}"; return 1; }
  done
}

wait_ok() {
  local end=$((SECONDS + WAIT))
  while [ "$SECONDS" -lt "$end" ]; do check_all >/dev/null && return 0; sleep 2; done
  check_all; return 1
}

log "restarting traefik (backup $BK, ${#CHECKS[@]} checks, wait ${WAIT}s)"
docker restart traefik >/dev/null
if wait_ok; then
  log "OK: every check answers as expected"; logger -t traefik-guarded "restart ok backup=$BK"
  echo "RESULT=OK"; exit 0
fi

log "CHECKS FAILED - rolling back to the previous files"
if [ -x "$TRAEFIK_DIR/.sync-backups/$BK/rollback.sh" ]; then
  "$TRAEFIK_DIR/.sync-backups/$BK/rollback.sh"
else
  log "no rollback.sh in $BK - cannot roll back"; echo "RESULT=ROLLBACK_FAILED"; exit 3
fi
docker restart traefik >/dev/null
if wait_ok; then
  log "rolled back: checks pass again with the OLD configuration"; logger -t traefik-guarded "rolled back backup=$BK"
  echo "RESULT=ROLLED_BACK_OK"; exit 2
fi
log "ROLLBACK ALSO FAILED - manual action needed"; logger -t traefik-guarded "ROLLBACK FAILED backup=$BK"
echo "RESULT=ROLLBACK_FAILED"; exit 3
