#!/bin/bash
# Start restic container using docker run
# This container will auto-restart on reboot due to --restart=unless-stopped

set -e

PROJECT_DIR="/home/ecloaiza/devops/docker/restic"
IMAGE_NAME="restic-restic"

# Build image if needed
cd "$PROJECT_DIR"
docker build -t "$IMAGE_NAME" .

# Remove existing container if it exists
docker rm -f restic 2>/dev/null || true

# Start container with docker run
docker run -d \
  --name restic \
  --hostname "${CONTAINER_HOSTNAME:-ranger0}" \
  --restart=unless-stopped \
  --env-file "$PROJECT_DIR/.env" \
  \
  -v "$PROJECT_DIR/app/entrypoint.sh:/app/entrypoint.sh:ro" \
  -v "$PROJECT_DIR/app/scripts:/app/scripts:ro" \
  -v "$PROJECT_DIR/app/status-api:/app/status-api:ro" \
  -v "$PROJECT_DIR/logs:/app/logs" \
  -v /var/lib/docker/volumes:/data/docker-volumes:ro \
  -v /home/ecloaiza:/data/bind-volumes:ro \
  -v "$PROJECT_DIR/backup:/backup" \
  -v /etc/localtime:/etc/localtime:ro \
  \
  -p 8484:8484 \
  \
  --network=frontend \
  \
  --log-driver=syslog \
  --log-opt syslog-address="udp://192.168.5.16:514" \
  --log-opt tag="restic" \
  \
  "$IMAGE_NAME"

echo "✓ Restic container started with auto-restart enabled"
docker ps --filter "name=restic"
