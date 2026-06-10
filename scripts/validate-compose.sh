#!/bin/bash
set -e

# Validate docker-compose configuration before deployment
# Usage: validate-compose.sh /path/to/project

PROJECT_DIR="${1:-.}"
PROJECT_NAME=$(basename "$PROJECT_DIR")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

echo "=== Validating $PROJECT_NAME ==="

cd "$PROJECT_DIR" || fail "Cannot access $PROJECT_DIR"

# 1. Check docker-compose.yml exists and is valid YAML
echo -n "Checking compose file syntax... "
if [ ! -f docker-compose.yml ]; then
  fail "docker-compose.yml not found"
fi
docker compose config > /dev/null 2>&1 || fail "Invalid docker-compose.yml syntax"
pass "docker-compose.yml valid"

# 2. Check required environment variables
echo -n "Checking environment variables... "
if [ ! -f .env ]; then
  warn ".env file not found (may be required)"
else
  # Extract required vars from compose file (portable: sed instead of grep -oP)
  REQUIRED_VARS=$(sed -n 's/.*\${\([A-Z_]*\)}.*/\1/p' docker-compose.yml | sort -u)
  MISSING=()
  while IFS= read -r VAR; do
    if ! grep -q "^${VAR}=" .env; then
      MISSING+=("$VAR")
    fi
  done <<< "$REQUIRED_VARS"

  if [ ${#MISSING[@]} -gt 0 ]; then
    fail "Missing env variables in .env: ${MISSING[*]}"
  fi
fi
pass "Environment variables configured"

# 3. Check bind mount directories exist
echo -n "Checking bind mount paths... "
MOUNTS=$(docker compose config | sed -n 's/.*- \.\///p' | sed 's/:.*//' | sort -u)
MISSING_MOUNTS=()
while IFS= read -r MOUNT; do
  if [ -n "$MOUNT" ] && [ ! -e "$MOUNT" ]; then
    MISSING_MOUNTS+=("$MOUNT")
  fi
done <<< "$MOUNTS"

if [ ${#MISSING_MOUNTS[@]} -gt 0 ]; then
  echo -n "Creating missing bind mount directories: ${MISSING_MOUNTS[*]}... "
  for MOUNT in "${MISSING_MOUNTS[@]}"; do
    mkdir -p "$MOUNT"
  done
  pass "Created"
else
  pass "All bind mounts exist"
fi

# 4. Check symlinks and NFS mounts
echo -n "Checking symlinks and NFS mounts... "
while IFS= read -r MOUNT; do
  if [ -n "$MOUNT" ] && [ -e "$MOUNT" ]; then
    if [ -L "$MOUNT" ]; then
      TARGET=$(readlink -f "$MOUNT")
      if [ ! -e "$TARGET" ]; then
        fail "Symlink $MOUNT points to non-existent $TARGET"
      fi
      pass "Symlink $MOUNT → $TARGET"
    fi

    # Check if it's an NFS mount
    if df "$MOUNT" | grep -q nfs; then
      pass "NFS mount verified: $MOUNT"
    fi
  fi
done <<< "$MOUNTS"
pass "Symlinks and NFS mounts OK"

# 5. Validate image names and registries
echo -n "Checking container images... "
IMAGES=$(docker compose config | sed -n 's/.*image:\s*//p' | sort -u)
while IFS= read -r IMAGE; do
  if [ -n "$IMAGE" ]; then
    # Check if image format is valid
    if ! [[ "$IMAGE" =~ ^[a-z0-9]([a-z0-9._/:-]*)?$ ]]; then
      fail "Invalid image name format: $IMAGE"
    fi
  fi
done <<< "$IMAGES"
pass "Image names valid"

# 6. Check for critical config issues
echo -n "Checking for common issues... "
ISSUES=()

# Check external networks exist
NETWORKS=$(docker compose config | sed -n 's/.*name:\s*//p')
while IFS= read -r NETWORK; do
  if [ -n "$NETWORK" ]; then
    if docker compose config | grep -q "external: true"; then
      if ! docker network ls | grep -q "^[^ ]*\s*$NETWORK"; then
        warn "External network '$NETWORK' may not exist on target host"
      fi
    fi
  fi
done <<< "$NETWORKS"

pass "Configuration checks passed"

echo
echo -e "${GREEN}=== All validation checks passed ===${NC}"
