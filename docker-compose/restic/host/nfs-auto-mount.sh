#!/usr/bin/env bash
set -uo pipefail

#####################################
# nfs-auto-mount.sh
# Version: 2.0.0
#
# Status: PRODUCTION
#
# Description:
# Safely manages NFS mounts by mounting when the NFS transport
# is reachable and detaching stale mounts when it is not.
# Designed to never hang on D-state NFS operations.
#
# Key design principle: NEVER call stat, test -d, ls, rm, or
# any filesystem operation on NFS mount point paths. Use
# /proc/self/mounts exclusively for mount state detection.
# This prevents D-state hangs with hard NFS mounts.
#
# Changelog (cumulative):
# - 1.1.0: TCP/2049 health check, forced lazy unmounts
# - 1.1.1: Normalize paths, fix false-negative detection
# - 1.1.2: Canonicalize logging
# - 1.2.0: Lock file, umount timeout, stderr logging
# - 1.3.0: Stale dentry recovery (rm + mkdir)
# - 2.0.0:
#   * BREAKING: never touch filesystem for mount state — /proc only
#   * Fix: umount runs in background subprocess to avoid D-state blocking
#   * Fix: D-state aware lock — steals lock from D-state holder
#   * Fix: mount point creation uses parent dir only (local fs)
#   * Removed: is_stale_mountpoint (called stat — D-state risk)
#   * Removed: rm -rf on mount points (D-state risk)
#   * Removed: test -d on mount points (D-state risk)
#####################################

#####################################
# CONSTANTS / DEFAULTS
#####################################
HOSTNAME="$(hostname -s)"

DEFAULT_LOG_FILE="/var/log/nfs-auto-mount.log"
LOG_FILE="${LOG_FILE:-$DEFAULT_LOG_FILE}"

PID_FILE="/var/run/nfs-auto-mount.pid"

DEFAULT_ENV_FILE_1="/home/ecloaiza/.nfs-mount.env"
DEFAULT_ENV_FILE_2="/home/ecloaiza/nfs-mount.env"

#####################################
# LOGGING
#####################################
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$HOSTNAME] $*"
  echo "$msg"
  {
    touch "$LOG_FILE"
    echo "$msg" >> "$LOG_FILE"
  } 2>/dev/null || true
}

fail() {
  log "ERROR: $*"
  exit 1
}

#####################################
# PID FILE LOCK (no flock — immune to D-state deadlock)
#####################################
acquire_lock() {
  if [[ -f "$PID_FILE" ]]; then
    local old_pid
    old_pid="$(cat "$PID_FILE" 2>/dev/null)" || old_pid=""
    if [[ -n "$old_pid" ]] && [[ -d "/proc/$old_pid" ]]; then
      local state
      state="$(awk '/^State:/ {print $2}' "/proc/$old_pid/status" 2>/dev/null)" || state=""
      if [[ "$state" == "D" ]]; then
        log "Previous instance (PID $old_pid) is in D-state (uninterruptible) — proceeding anyway"
      else
        log "Another instance is running (PID $old_pid, state=$state), exiting"
        exit 0
      fi
    fi
    # PID file exists but process is gone or D-state — safe to proceed
  fi
  echo $$ > "$PID_FILE"
}

cleanup_lock() {
  rm -f "$PID_FILE"
}
trap cleanup_lock EXIT

acquire_lock

#####################################
# ENV FILE RESOLUTION
#####################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ENV_FILE="${ENV_FILE_PATH:-$DEFAULT_ENV_FILE_1}"
[[ -f "$ENV_FILE" ]] || ENV_FILE="$DEFAULT_ENV_FILE_2"
[[ -f "$ENV_FILE" ]] || {
  [[ -f "$SCRIPT_DIR/nfs-mount.env" ]] && ENV_FILE="$SCRIPT_DIR/nfs-mount.env"
}

[[ -f "$ENV_FILE" ]] || fail "Env file not found"

# shellcheck disable=SC1090
source "$ENV_FILE"

#####################################
# VALIDATION
#####################################
: "${NFS_MOUNTS:?NFS_MOUNTS must be defined in the env file}"

NFS_PORT="${NFS_PORT:-2049}"
NFS_CONNECT_TIMEOUT_SECONDS="${NFS_CONNECT_TIMEOUT_SECONDS:-2}"

#####################################
# HELPERS
#####################################
normalize_path() {
  local p="$1"
  [[ "$p" != "/" ]] && p="${p%/}"
  echo "$p"
}

is_mounted_proc() {
  local nas_ip="$1"
  local export_path="$2"
  local mount_point="$3"
  local escaped_ip="${nas_ip//./\\.}"
  grep -qsE "^${escaped_ip}:${export_path}[[:space:]]+${mount_point}[[:space:]]+nfs" \
    /proc/self/mounts
}

nfs_transport_ok() {
  local nas_ip="$1"
  local port="$2"
  timeout "$NFS_CONNECT_TIMEOUT_SECONDS" \
    bash -c "</dev/tcp/${nas_ip}/${port}" \
    >/dev/null 2>&1
}

# Ensure mount point directory exists using ONLY local filesystem operations.
# The parent directory (e.g. /mnt/homenas) is always on the local fs.
# We NEVER stat or test -d the mount point itself.
ensure_mountpoint_dir() {
  local mount_point="$1"
  local parent_dir
  parent_dir="$(dirname "$mount_point")"
  mkdir -p "$parent_dir" 2>/dev/null || true
  mkdir "$mount_point" 2>/dev/null || true
}

# Unmount in a background subprocess so D-state can't block the script.
# umount -l detaches from VFS namespace immediately (no NFS RPC needed).
# We give it a few seconds, then move on regardless.
background_umount() {
  local mount_point="$1"
  local label="$2"

  log "  Attempting lazy unmount ($label)"

  umount -l "$mount_point" &>/dev/null &
  local umount_pid=$!

  local waited=0
  while [[ $waited -lt 5 ]]; do
    if ! kill -0 "$umount_pid" 2>/dev/null; then
      wait "$umount_pid" 2>/dev/null
      local rc=$?
      if [[ $rc -eq 0 ]]; then
        log "  Lazy unmount completed"
      else
        log "  Lazy unmount returned rc=$rc"
      fi
      return $rc
    fi
    sleep 1
    waited=$((waited + 1))
  done

  log "  Lazy unmount still running after 5s (PID $umount_pid likely D-state) — moving on"
  disown "$umount_pid" 2>/dev/null || true
  return 1
}

#####################################
# START
#####################################
log "========================================"
log "NFS auto-mount run starting"
log "Version: 2.0.0"
log "Log file: $LOG_FILE"
log "Using env: $ENV_FILE"
log "========================================"

#####################################
# PROCESS EACH MOUNT
#####################################
while IFS= read -r line; do
  [[ -z "$line" ]] && continue

  IFS='|' read -r NAS_IP NFS_EXPORT MOUNT_POINT MOUNT_OPTS <<< "$line"

  NFS_EXPORT="$(normalize_path "$NFS_EXPORT")"
  MOUNT_POINT="$(normalize_path "$MOUNT_POINT")"

  log "----------------------------------------"
  log "NAS:    $NAS_IP"
  log "Export: $NFS_EXPORT"
  log "Mount:  $MOUNT_POINT"
  log "Opts:   $MOUNT_OPTS"

  mounted_in_proc=false
  is_mounted_proc "$NAS_IP" "$NFS_EXPORT" "$MOUNT_POINT" && mounted_in_proc=true

  if nfs_transport_ok "$NAS_IP" "$NFS_PORT"; then
    log "NFS transport reachable on TCP/$NFS_PORT"

    if $mounted_in_proc; then
      log "Already mounted → no action"
    else
      ensure_mountpoint_dir "$MOUNT_POINT"

      log "Mounting NFS"
      if mount -t nfs -o "$MOUNT_OPTS" "$NAS_IP:$NFS_EXPORT" "$MOUNT_POINT" 2>&1 \
           | while IFS= read -r ml; do log "  mount: $ml"; done; [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        log "Mount complete"
      else
        log "Mount failed → clearing partial state and retrying"
        background_umount "$MOUNT_POINT" "clearing partial state"
        sleep 2
        ensure_mountpoint_dir "$MOUNT_POINT"
        if mount -t nfs -o "$MOUNT_OPTS" "$NAS_IP:$NFS_EXPORT" "$MOUNT_POINT" 2>&1 \
             | while IFS= read -r ml; do log "  mount(retry): $ml"; done; [[ ${PIPESTATUS[0]} -eq 0 ]]; then
          log "Mount complete on retry"
        else
          log "WARNING: mount failed after retry for $NAS_IP:$NFS_EXPORT → $MOUNT_POINT"
        fi
      fi
    fi
  else
    log "NFS transport NOT reachable on TCP/$NFS_PORT"

    if $mounted_in_proc; then
      log "Stale NFS mount in /proc → detaching"
      background_umount "$MOUNT_POINT" "server unreachable"

      if is_mounted_proc "$NAS_IP" "$NFS_EXPORT" "$MOUNT_POINT"; then
        log "  Still in /proc after lazy unmount (open handles or D-state)"
      else
        log "  Successfully removed from /proc"
      fi
    else
      log "Not mounted → no action"
    fi
  fi

done <<< "$NFS_MOUNTS"

log "========================================"
log "All mount checks complete"
