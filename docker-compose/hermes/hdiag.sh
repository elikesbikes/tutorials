#!/bin/sh
# hdiag <subcommand> [argument]  -  READ-ONLY diagnostics on hailmary through the restricted `hermes-diag` account.
#   hdiag status | hdiag component <name> | hdiag container-logs <name> | hdiag service-journal <unit> | hdiag help
# The remote side enforces everything (forced command, exact allowlists, redaction); this wrapper only supplies the
# key (kept in RAM, removed on exit) and the PINNED hailmary host key. The key comes from Proton Pass via start.sh.
set -eu
: "${HERMES_DIAG_SSH_KEY:?hdiag: no key available (the container was not started with ./start.sh)}"
HOST="${HERMES_DIAG_HOST:-192.168.5.25}"
D="$(mktemp -d /dev/shm/hdiag.XXXXXX)"
trap 'rm -rf "$D"' EXIT INT TERM
umask 077
printf '%s\n' "$HERMES_DIAG_SSH_KEY" > "$D/key"
ssh -n -i "$D/key" -o IdentitiesOnly=yes -o IdentityAgent=none -o BatchMode=yes \
    -o UserKnownHostsFile=/opt/hermes-diag/known_hosts -o StrictHostKeyChecking=yes \
    -o ConnectTimeout=10 -o ServerAliveInterval=10 -o ServerAliveCountMax=2 \
    "hermes-diag@$HOST" "$*"
