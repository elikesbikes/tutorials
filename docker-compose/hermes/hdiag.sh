#!/bin/sh
# hdiag [host] <subcommand> [argument]  -  READ-ONLY diagnostics through the restricted `hermes-diag` account on a host.
#   hosts: hailmary (default), kipp, rocky, tars, murph     e.g.  hdiag kipp hostinfo   hdiag hailmary status   hdiag rocky help
# Each host enforces everything itself (forced command, exact allowlists, redaction, audit); this wrapper only supplies
# the key (kept in RAM, removed on exit) and the PINNED host keys. The key comes from Proton Pass via start.sh.
set -eu
: "${HERMES_DIAG_SSH_KEY:?hdiag: no key available (the container was not started with ./start.sh)}"
case "${1:-}" in
  hailmary) HOST=192.168.5.25;  shift ;;
  kipp)     HOST=192.168.5.216; shift ;;
  rocky)    HOST=192.168.5.28;  shift ;;
  tars)     HOST=192.168.5.127; shift ;;
  murph)    HOST=192.168.5.41;  shift ;;
  *)        HOST="${HERMES_DIAG_HOST:-192.168.5.25}" ;;   # no host given: hailmary (backward compatible)
esac
D="$(mktemp -d /dev/shm/hdiag.XXXXXX)"
trap 'rm -rf "$D"' EXIT INT TERM
umask 077
printf '%s\n' "$HERMES_DIAG_SSH_KEY" > "$D/key"
ssh -n -i "$D/key" -o IdentitiesOnly=yes -o IdentityAgent=none -o BatchMode=yes \
    -o UserKnownHostsFile=/opt/hermes-diag/known_hosts -o StrictHostKeyChecking=yes \
    -o ConnectTimeout=10 -o ServerAliveInterval=10 -o ServerAliveCountMax=2 \
    "hermes-diag@$HOST" "$*"
