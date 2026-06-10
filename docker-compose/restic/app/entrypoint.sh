#!/bin/sh
set -e

#####################################
# entrypoint.sh — multi-job scheduler setup
#
# Installs one crontab line per job conf in /app/jobs/*.conf, then starts
# the status API and crond. Job confs are validated here so one bad file
# skips that job only — the container always starts.
#####################################

mkdir -p /app/logs/status

CRONTAB_FILE=/etc/crontabs/root
: > "$CRONTAB_FILE"

for conf in /app/jobs/*.conf; do
  # Glob may not match anything — *.conf stays literal then
  [ -e "$conf" ] || continue

  # Validate in a subshell so a bad conf can't poison the entrypoint env
  # or leak variables into the next job's validation.
  (
    JOB_NAME="" JOB_CRON="" JOB_SOURCES=""
    # shellcheck disable=SC1090  # conf path is dynamic by design
    . "$conf" || { echo "[entrypoint] WARN: cannot source $conf — skipping"; exit 1; }

    stem="$(basename "$conf" .conf)"

    case "$JOB_NAME" in
      ""|*[!A-Za-z0-9_-]*)
        echo "[entrypoint] WARN: $conf: JOB_NAME='$JOB_NAME' invalid (need [A-Za-z0-9_-]+) — skipping"
        exit 1 ;;
    esac

    if [ "$JOB_NAME" != "$stem" ]; then
      echo "[entrypoint] WARN: $conf: JOB_NAME='$JOB_NAME' must equal filename stem '$stem' — skipping"
      exit 1
    fi

    # BusyBox crond needs exactly 5 fields; this also rejects @daily and quoting mistakes.
    # set -f stops the * fields from glob-expanding against the filesystem.
    set -f
    # shellcheck disable=SC2086  # word splitting is the point here
    set -- $JOB_CRON
    set +f
    if [ $# -ne 5 ]; then
      echo "[entrypoint] WARN: $conf: JOB_CRON='$JOB_CRON' must have exactly 5 fields — skipping"
      exit 1
    fi

    if [ -z "$JOB_SOURCES" ]; then
      echo "[entrypoint] WARN: $conf: JOB_SOURCES is empty — skipping"
      exit 1
    fi

    # JOB_CRON expands unquoted into 5 crontab fields; the only argument is
    # the conf path, which is space-free by the JOB_NAME/stem rule above.
    # Output is teed to the per-job cron log AND to /proc/1/fd/1 (PID 1 = crond,
    # the container's stdout) so the docker logging driver ships it to syslog.
    echo "$JOB_CRON /app/scripts/backup.sh $conf 2>&1 | tee -a /app/logs/cron-$JOB_NAME.log > /proc/1/fd/1" >> "$CRONTAB_FILE"
    echo "[entrypoint] Installed job '$JOB_NAME' (cron: $JOB_CRON)"
  ) || true
done

JOB_COUNT="$(grep -c . "$CRONTAB_FILE" 2>/dev/null || true)"

#####################################
# Legacy fallback — pre-multi-job hosts that still configure BACKUP_CRON
# in .env and have no jobs/*.conf yet. Generates a conf replicating the old
# auto-detect behavior so a half-migrated host keeps backing up.
#####################################
if [ "$JOB_COUNT" -eq 0 ] && [ -n "${BACKUP_CRON:-}" ]; then
  echo "[entrypoint] ============================================================"
  echo "[entrypoint] DEPRECATED: BACKUP_CRON is set but no job confs were found."
  echo "[entrypoint] Generating a legacy 'docker-volumes' job. Please migrate to"
  echo "[entrypoint] jobs/*.conf (see jobs/example.conf.example) and remove"
  echo "[entrypoint] BACKUP_CRON from .env."
  echo "[entrypoint] ============================================================"

  # jobs/ is mounted read-only — write the generated conf container-locally.
  # Named docker-volumes (not 'legacy') so its snapshots carry the same tag
  # the real job conf will use after migration.
  LEGACY_CONF=/etc/docker-volumes.conf
  SOURCES="/data/docker-volumes"
  for p in /data/bind-volumes/docker /data/bind-volumes/devops/docker \
           /data/bind-volumes/Devops/docker /data/bind-volumes/DevOps/docker; do
    [ -d "$p" ] && SOURCES="$SOURCES $p"
  done

  cat > "$LEGACY_CONF" <<EOF
JOB_NAME="docker-volumes"
JOB_CRON="$BACKUP_CRON"
JOB_SOURCES="$SOURCES"
EOF

  echo "$BACKUP_CRON /app/scripts/backup.sh $LEGACY_CONF 2>&1 | tee -a /app/logs/cron-docker-volumes.log > /proc/1/fd/1" >> "$CRONTAB_FILE"
  JOB_COUNT=1
elif [ -n "${BACKUP_CRON:-}" ]; then
  echo "[entrypoint] NOTE: BACKUP_CRON is set but ignored (job confs take precedence) — remove it from .env"
fi

if [ "$JOB_COUNT" -eq 0 ]; then
  echo "[entrypoint] WARN: no valid jobs configured — crond will run nothing and /health will report 503"
fi

echo "[entrypoint] Installed crontab:"
sed 's/^/[entrypoint]   /' "$CRONTAB_FILE"

echo "[entrypoint] Starting HTTP status server on :${STATUS_PORT:-8484}"
python3 /app/status-api/app.py &

echo "[entrypoint] Starting crond"
exec crond -f -l 8
