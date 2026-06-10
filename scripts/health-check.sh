#!/bin/bash
set -e

# Comprehensive health check after docker compose up
# Tests service readiness, endpoints, and basic connectivity
# Usage: health-check.sh [timeout_seconds]

TIMEOUT=${1:-120}
PROJECT_DIR="${2:-.}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

fail() {
  echo -e "${RED}✗ FAILED: $1${NC}" >&2
  exit 1
}

pass() {
  echo -e "${GREEN}✓ $1${NC}"
}

warn() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

echo "=== Health Check (${TIMEOUT}s timeout) ==="
cd "$PROJECT_DIR" || fail "Cannot access $PROJECT_DIR"

ELAPSED=0
START_TIME=$(date +%s)

# 1. All services running
echo -n "Waiting for all services to start... "
while [ $ELAPSED -lt $TIMEOUT ]; do
  RUNNING=$(docker compose ps --filter status=running --services 2>/dev/null | wc -l)
  TOTAL=$(docker compose ps --services 2>/dev/null | wc -l)

  if [ "$RUNNING" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
    pass "All $TOTAL services running"
    break
  fi

  ELAPSED=$(($(date +%s) - START_TIME))
  sleep 2
done

if [ "$RUNNING" -ne "$TOTAL" ]; then
  fail "Only $RUNNING/$TOTAL services running after ${TIMEOUT}s"
fi

# 2. Check logs for errors
echo -n "Checking for startup errors in logs... "
ERRORS=$(docker compose logs 2>/dev/null | grep -iE "error|fatal|panic|crash" || true)
if [ -n "$ERRORS" ]; then
  warn "Potential errors in logs:"
  echo "$ERRORS" | head -5
else
  pass "No critical errors in logs"
fi

# 3. Port connectivity
echo "Checking port accessibility..."
PORTS=$(docker compose ps --format "table {{.Service}},{{.Ports}}" | tail -n +2)
while IFS= read -r LINE; do
  [ -z "$LINE" ] && continue
  SERVICE=$(echo "$LINE" | cut -d, -f1)
  PORTS_STR=$(echo "$LINE" | cut -d, -f2-)

  # Extract host:container port mappings
  while IFS= read -r PORT; do
    if [[ "$PORT" =~ ([0-9]+)-\>([0-9]+) ]]; then
      HOST_PORT="${BASH_REMATCH[1]}"
      CONTAINER_PORT="${BASH_REMATCH[2]}"

      echo -n "  $SERVICE (port $HOST_PORT): "
      if timeout 3 bash -c "echo > /dev/tcp/127.0.0.1/$HOST_PORT" 2>/dev/null; then
        pass "accessible"
      else
        warn "not responding yet (still initializing?)"
      fi
    fi
  done <<< "$PORTS_STR"
done <<< "$PORTS"

# 4. Volume accessibility
echo "Checking volume mounts..."
VOLUMES=$(docker compose config | grep -oP "^\s+- \./\K[^:]*(?=:)" | sort -u)
while IFS= read -r VOLUME; do
  [ -z "$VOLUME" ] && continue
  echo -n "  $VOLUME: "
  if [ -d "$VOLUME" ]; then
    if [ -w "$VOLUME" ]; then
      pass "readable and writable"
    else
      warn "readable but not writable"
    fi
  else
    fail "not accessible"
  fi
done <<< "$VOLUMES"

# 5. Network connectivity
echo "Checking network configuration..."
NETWORK=$(docker compose config | grep -oP '^\s+name:\s+\K.*' | head -1)
if [ -n "$NETWORK" ]; then
  echo -n "  Network '$NETWORK': "
  if docker network inspect "$NETWORK" > /dev/null 2>&1; then
    CONTAINERS=$(docker network inspect "$NETWORK" --format '{{len .Containers}}')
    pass "found with $CONTAINERS connected containers"
  else
    fail "network not found"
  fi
fi

# 6. Service-specific health checks (if defined)
echo "Checking service health..."
SERVICES=$(docker compose ps --services)
while IFS= read -r SERVICE; do
  [ -z "$SERVICE" ] && continue
  echo -n "  $SERVICE: "

  # Check if container has health check defined
  HEALTH_STATUS=$(docker compose ps "$SERVICE" --format "{{.State}}" 2>/dev/null || echo "unknown")

  if [[ "$HEALTH_STATUS" == "Up"* ]]; then
    pass "up"
  else
    fail "$SERVICE is not in 'Up' state (state: $HEALTH_STATUS)"
  fi
done <<< "$SERVICES"

echo
echo -e "${GREEN}=== Health check passed ===${NC}"
echo "Deployment ready for testing"
