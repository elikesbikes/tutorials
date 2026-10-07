FROM alpine:3.19

# OCI image metadata — surfaced on Docker Hub and by `docker inspect`.
LABEL org.opencontainers.image.title="restic-backup" \
      org.opencontainers.image.description="Multi-job restic backup container: per-job cron schedules, shared tagged repository, per-tag retention, ntfy notifications, and an HTTP health endpoint." \
      org.opencontainers.image.licenses="MIT"

# Runtime dependencies. flock (util-linux) is required: BusyBox flock has no
# -w timeout flag, and backup.sh relies on `flock -w` to serialize jobs against
# the shared repo.
RUN apk add --no-cache restic python3 curl bash tzdata flock

# Application code is baked into the image (was previously bind-mounted).
# jobs/, logs/, backup/ and data sources remain runtime bind mounts.
COPY app/ /app/
RUN chmod +x /app/entrypoint.sh /app/scripts/*.sh

ENTRYPOINT ["/app/entrypoint.sh"]
