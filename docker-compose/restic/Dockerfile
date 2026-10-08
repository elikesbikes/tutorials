FROM alpine:3.24

# OCI image metadata — surfaced on Docker Hub and by `docker inspect`.
LABEL org.opencontainers.image.title="restic-backup" \
      org.opencontainers.image.description="Multi-job restic backup container: per-job cron schedules, shared tagged repository, per-tag retention, ntfy notifications, and an HTTP health endpoint." \
      org.opencontainers.image.licenses="MIT"

# Runtime dependencies. flock (util-linux) is required: BusyBox flock has no
# -w timeout flag, and backup.sh relies on `flock -w` to serialize jobs against
# the shared repo.
RUN apk add --no-cache python3 curl bash tzdata flock

# restic comes from the official release, not apk: Alpine 3.24 only packages 0.18.x.
# The checksum is pinned from the release's SHA256SUMS (GPG signature checked against
# the key fingerprint in restic's install docs, CF8F 18F2 ... D3F7 A907). To upgrade,
# change both values.
ARG RESTIC_VERSION=0.19.1
ARG RESTIC_SHA256=f415415624dcc452f2a02b8c33641791a8c6d6d3b65bbb3543fcf9a25151585c
RUN curl -fsSL -o /tmp/restic.bz2 \
      "https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_amd64.bz2" \
 && echo "${RESTIC_SHA256}  /tmp/restic.bz2" | sha256sum -c - \
 && bunzip2 -c /tmp/restic.bz2 > /usr/local/bin/restic \
 && chmod 755 /usr/local/bin/restic \
 && rm /tmp/restic.bz2 \
 && restic version

# Application code is baked into the image (was previously bind-mounted).
# jobs/, logs/, backup/ and data sources remain runtime bind mounts.
COPY app/ /app/
RUN chmod +x /app/entrypoint.sh /app/scripts/*.sh

ENTRYPOINT ["/app/entrypoint.sh"]
