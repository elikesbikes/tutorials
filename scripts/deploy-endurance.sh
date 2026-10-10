#!/usr/bin/env bash
# Deploy a docker-compose project to endurance.
# Runs ON endurance, as ecloaiza, from the GitLab shell runner "endurance-shell"
# (tag: endurance, locked to this project, protected branches only).
#
# Usage: deploy-endurance.sh preflight|deploy <project>
#   preflight  read-only checks, changes nothing
#   deploy     preflight, then install the files from this pipeline's commit and
#              restart ONLY that project with its own start.sh (secrets come from
#              Proton Pass at start time; nothing secret is stored in GitLab)
#
# Safe by design:
#   - only the projects in ALLOWED are accepted
#   - never deletes anything on endurance, never touches data/, *_data/ or .env
#   - keeps the previous version of every file it replaces (rollback)
#   - if the project is not healthy after HEALTH_WAIT seconds it puts the old
#     files back, restarts once and fails the job
set -euo pipefail

MODE="${1:?usage: deploy-endurance.sh preflight|deploy <project>}"
PROJECT="${ENDURANCE_PROJECT:-${2:-}}"      # ENDURANCE_PROJECT can be set when playing the job by hand
ALLOWED="hermes honcho open-webui restic"
HEALTH_WAIT=180
MIN_FREE_GB=5

: "${CI_PROJECT_DIR:?must run inside a GitLab CI job}"
: "${CI_COMMIT_SHA:?must run inside a GitLab CI job}"
SRC_ROOT="$CI_PROJECT_DIR/docker-compose"
DEST_ROOT="$HOME/devops/docker"
BACKUP_ROOT="$DEST_ROOT/.deploy-backups"
SEALED_PAT_HANDLE="0x81010001"
PASS_CLI="$HOME/.local/bin/pass-cli"

log()   { printf '%s\n' "$*"; }
fail()  { printf 'ERROR: %s\n' "$*" >&2; audit "result=FAILED reason=$*"; exit 1; }
audit() { logger -t gitlab-deploy -- "mode=$MODE project=${PROJECT:-none} sha=${CI_COMMIT_SHA:0:8} pipeline=${CI_PIPELINE_ID:-?} user=${GITLAB_USER_LOGIN:-?} $*" 2>/dev/null || true; }

# ---------- which project? ----------
if [ -z "$PROJECT" ] || [ "$PROJECT" = "none" ]; then
  log "No docker-compose project changed in this commit - nothing to do."
  exit 0
fi
case " $ALLOWED " in
  *" $PROJECT "*) ;;
  *) fail "project '$PROJECT' is not allowed on endurance (allowed: $ALLOWED)";;
esac
SRC="$SRC_ROOT/$PROJECT"
DEST="$DEST_ROOT/$PROJECT"
[ -d "$SRC" ]  || fail "source folder not found in this commit: docker-compose/$PROJECT"
[ -d "$DEST" ] || fail "project folder does not exist on endurance: $DEST (create it by hand first)"

# ---------- checks (read-only) ----------
preflight() {
  log "==> Pre-flight for '$PROJECT' on $(hostname)"

  log "--- checkout is exactly the pipeline commit"
  [ "$(git -C "$CI_PROJECT_DIR" rev-parse HEAD)" = "$CI_COMMIT_SHA" ] || fail "checkout is not at $CI_COMMIT_SHA"

  log "--- required files in the repo copy"
  [ -f "$SRC/docker-compose.yml" ] || fail "docker-compose.yml missing"
  [ -f "$SRC/start.sh" ]           || fail "start.sh missing (this host starts projects with start.sh, not plain compose up)"

  log "--- compose file is valid YAML"
  bash "$CI_PROJECT_DIR/scripts/validate-compose.sh" "$SRC" >/dev/null || fail "compose validation failed"

  log "--- docker daemon and frontend network"
  docker ps >/dev/null                      || fail "cannot talk to docker"
  docker network inspect frontend >/dev/null 2>&1 || fail "docker network 'frontend' not found"

  log "--- free disk space (need >= ${MIN_FREE_GB} GB)"
  FREE_GB=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
  [ "${FREE_GB:-0}" -ge "$MIN_FREE_GB" ] || fail "only ${FREE_GB} GB free"

  if [ "$PROJECT" = "restic" ]; then
    log "--- restic: ./backup must be an NFS mount (never deploy it onto a local disk)"
    local bt bfs
    bt="$(readlink -f "$DEST/backup" 2>/dev/null || true)"
    bfs=""; [ -n "$bt" ] && bfs="$(findmnt -T "$bt" -n -o FSTYPE 2>/dev/null || true)"
    case "$bfs" in nfs*) ;; *) fail "restic: $DEST/backup is not on an NFS mount (found: ${bfs:-nothing}) - mount the NAS export and link ./backup to it first";; esac
  fi

  log "--- project folder is writable; routing .env present"
  touch "$DEST/.deploy-write-test" && rm -f "$DEST/.deploy-write-test" || fail "cannot write to $DEST"
  [ -f "$DEST/.env" ] || log "    note: no $DEST/.env (fine only if this project does not use one)"

  log "--- vTPM can unseal this host's Proton Pass token (result only, nothing printed)"
  tpm2_unseal -c "$SEALED_PAT_HANDLE" >/dev/null 2>&1 || fail "vTPM unseal failed (is the runner's user in the tss group?)"

  log "--- Proton Pass login works (one logged access under the endurance token)"
  local sess; sess="$(mktemp -d /tmp/pass-agent-deploy.XXXXXX)"
  if PROTON_PASS_KEY_PROVIDER=fs PROTON_PASS_SESSION_DIR="$sess" \
     PROTON_PASS_PERSONAL_ACCESS_TOKEN="$(tpm2_unseal -c "$SEALED_PAT_HANDLE" 2>/dev/null)" \
     "$PASS_CLI" login >/dev/null 2>&1; then
    PROTON_PASS_KEY_PROVIDER=fs PROTON_PASS_SESSION_DIR="$sess" "$PASS_CLI" logout --force >/dev/null 2>&1 || true
    rm -rf "$sess"
  else
    rm -rf "$sess"; fail "Proton Pass login failed"
  fi

  log "--- current containers of this project"
  (cd "$DEST" && docker compose ps --format 'table {{.Service}}\t{{.State}}\t{{.Health}}' 2>/dev/null) || true
  log "All pre-flight checks passed for '$PROJECT'."
}

# ---------- wait until every service of the project is running and healthy ----------
wait_healthy() {
  local deadline=$(( $(date +%s) + HEALTH_WAIT )) out bad
  while [ "$(date +%s)" -lt "$deadline" ]; do
    out="$(cd "$DEST" && docker compose ps -a --format '{{.Service}} {{.State}} {{.Health}}' 2>/dev/null || true)"
    bad="$(printf '%s\n' "$out" | awk 'NF && !($2=="running" && ($3=="" || $3=="healthy"))')"
    if [ -n "$out" ] && [ -z "$bad" ]; then return 0; fi
    sleep 5
  done
  log "Not healthy after ${HEALTH_WAIT}s:"; printf '%s\n' "${bad:-<no containers>}"
  return 1
}

if [ "$MODE" = "preflight" ]; then preflight; audit "result=preflight-ok"; exit 0; fi
[ "$MODE" = "deploy" ] || fail "unknown mode '$MODE'"

preflight

# ---------- deploy ----------
TS="$(date +%Y%m%d-%H%M%S)"
BK="$BACKUP_ROOT/$PROJECT/$TS"
mkdir -p "$BK"

OLD_DOCKERFILE_SUM="$(sha256sum "$DEST/Dockerfile" 2>/dev/null | cut -d' ' -f1 || true)"

log "==> Installing files (previous versions saved in $BK)"
rsync -amc --no-owner --no-group --backup --backup-dir="$BK" \
  --exclude='logs/' --exclude='.env' --exclude='backup/' --exclude='*.conf' \
  --exclude='docker-compose.override.yml' --exclude='certs/' --exclude='acme.json' \
  --exclude='secrets/' --exclude='*.htpasswd' --exclude='data/' --exclude='*_data/' \
  --exclude='.credentials*' --exclude='.claude.json' \
  --include='*/' --include='Dockerfile' --include='.gitignore' --include='*.yml' --include='*.yaml' \
  --include='*.py' --include='*.sh' --include='*.[mM][dD]' --include='*.json' --include='*.example' \
  --include='honcho.env' --include='*.png' --include='*.txt' --exclude='*' \
  "$SRC/" "$DEST/"

# keep the 5 newest backups of this project
ls -1dt "$BACKUP_ROOT/$PROJECT"/*/ 2>/dev/null | tail -n +6 | xargs -r rm -rf

rollback() {
  log "==> ROLLING BACK to the previous files"
  rsync -a "$BK/" "$DEST/" || true
  (cd "$DEST" && ./start.sh >/dev/null 2>&1) || true
  if wait_healthy; then log "Rollback restored a healthy project."; else log "Rollback did NOT restore health - check by hand."; fi
}

log "==> Checking the compose file with this host's .env"
(cd "$DEST" && docker compose config -q) || { rollback; fail "docker compose config failed after install"; }

# start.sh only runs "compose up -d", which never rebuilds an image. If this
# project builds its own image (hermes) and its Dockerfile changed, rebuild first.
NEW_DOCKERFILE_SUM="$(sha256sum "$DEST/Dockerfile" 2>/dev/null | cut -d' ' -f1 || true)"
if [ -n "$NEW_DOCKERFILE_SUM" ] && [ "$NEW_DOCKERFILE_SUM" != "$OLD_DOCKERFILE_SUM" ]; then
  log "==> Dockerfile changed - rebuilding the image first (docker compose build --pull)"
  (cd "$DEST" && docker compose build --pull) || { rollback; fail "image build failed"; }
fi

log "==> Creating missing bind-mount folders inside the project (as ecloaiza)"
(cd "$DEST" && docker compose config --format json | python3 -c '
import json, os, sys
root = os.getcwd()
for svc in json.load(sys.stdin).get("services", {}).values():
    for v in svc.get("volumes", []):
        src = v.get("source", "")
        if v.get("type") == "bind" and src.startswith(root + "/") and "." not in os.path.basename(src):
            print(src)
' | sort -u | while IFS= read -r d; do [ -e "$d" ] || { log "    creating $d"; mkdir -p "$d"; }; done)

log "==> Starting '$PROJECT' with its own start.sh"
if ! (cd "$DEST" && ./start.sh); then rollback; fail "start.sh failed"; fi

log "==> Waiting up to ${HEALTH_WAIT}s for every container to be running and healthy"
if wait_healthy; then
  log "==> '$PROJECT' deployed OK from ${CI_COMMIT_SHA:0:8}"
  audit "result=ok"
else
  rollback
  fail "project not healthy after ${HEALTH_WAIT}s"
fi
