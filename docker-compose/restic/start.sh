#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Secrets from Proton Pass (HOMELAB vault) ---
# pp_load: this host's PAT (TPM first), one login at most, TPM-sealed cache so a restart within 10 min
# does not log in and a Proton rate limit (429 / 2028) does not stop the start. See the helper's header.
source "$HOME/scripts/proton-pass/pass-secrets.sh"
# The repository password differs per host (each host has its own restic repository): hailmary's lives in its own Proton item,
# every other host keeps the original one. Unknown hosts fall back to the original, as before.
case "$(hostname -s)" in
    hailmary) RESTIC_PASSWORD_ITEM="restic - RESTIC_PASSWORD - hailmary" ;;
    rocky)    RESTIC_PASSWORD_ITEM="restic - RESTIC_PASSWORD - rocky" ;;
    *)        RESTIC_PASSWORD_ITEM="restic - RESTIC_PASSWORD" ;;
esac
pp_load restic "Starting restic" \
    "RESTIC_PASSWORD|${RESTIC_PASSWORD_ITEM}|note"

# --- Load non-secret env vars from .env ---
while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    export "$key=$value"
done < "$SCRIPT_DIR/.env"

# --- Guard: hand the container the repository password ONLY if the backup target really is the NAS ---
# backup.sh runs `restic init` when it cannot open a repository. A password plus an unmounted target (an empty local folder: rocky
# today, or any host whose NFS share dropped) would silently create a stray local repository and fill the disk. Without the
# password the jobs fail at the password check instead: loud, and harmless.
# Any failure here (a link into an unmounted NAS path, a missing folder) must mean "withhold", never abort the script.
BACKUP_TARGET="$(readlink -f "$SCRIPT_DIR/backup" 2>/dev/null || true)"
BACKUP_FSTYPE=""
[[ -n "$BACKUP_TARGET" ]] && BACKUP_FSTYPE="$(findmnt -T "$BACKUP_TARGET" -n -o FSTYPE 2>/dev/null || true)"
case "$BACKUP_FSTYPE" in
    nfs*) ;;
    *) echo "[restic] WARNING: $BACKUP_TARGET is not an NFS mount (filesystem: ${BACKUP_FSTYPE:-unknown}) - NOT passing RESTIC_PASSWORD;" \
            "backup jobs will fail until the NAS share is mounted and this script is run again" >&2
       unset RESTIC_PASSWORD ;;
esac

# --- Start the stack ---
docker compose -f "$SCRIPT_DIR/docker-compose.yml" -f "$SCRIPT_DIR/docker-compose.override.yml" up -d
