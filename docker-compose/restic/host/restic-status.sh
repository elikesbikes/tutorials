#!/usr/bin/env bash
set -euo pipefail

#####################################
# restic-status.sh
#
# Prints a daily pass/fail summary
# of all restic backup runs.
#
# Usage:
#   ./restic-status.sh            # all logs
#   ./restic-status.sh -n 30      # last 30 days
#   ./restic-status.sh -f         # failures only
#   ./restic-status.sh -n 30 -f   # last 30 days, failures only
#####################################

LOG_DIR="/home/ecloaiza/devops/docker/restic/logs"
LIMIT=0
FAILURES_ONLY=false

usage() {
  echo "Usage: $0 [-n DAYS] [-f]"
  echo "  -n DAYS   Show only the last N days (default: all)"
  echo "  -f        Show failures only"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n) LIMIT="${2:?-n requires a number}"; shift 2 ;;
    -f) FAILURES_ONLY=true; shift ;;
    *)  usage ;;
  esac
done

[[ -d "$LOG_DIR" ]] || { echo "Log directory not found: $LOG_DIR"; exit 1; }

mapfile -t LOG_FILES < <(ls "$LOG_DIR"/backup-*.log 2>/dev/null | sort)

if [[ ${#LOG_FILES[@]} -eq 0 ]]; then
  echo "No log files found in $LOG_DIR"
  exit 0
fi

# Apply -n limit (take last N files)
if [[ "$LIMIT" -gt 0 ]]; then
  LOG_FILES=("${LOG_FILES[@]: -$LIMIT}")
fi

# Header
printf "%-12s  %-6s  %-10s  %9s  %12s  %-7s  %s\n" \
  "DATE" "STATUS" "SNAPSHOT" "FILES" "ADDED" "TIME" "NOTE"
printf '%s\n' "$(printf '%.0s-' {1..80})"

OK=0
FAIL=0

for log in "${LOG_FILES[@]}"; do
  date="${log##*backup-}"
  date="${date%.log}"

  snapshot=$(grep -oP "snapshot \K[0-9a-f]+" "$log" 2>/dev/null | head -1 || true)
  files=$(grep -oP "processed \K[0-9]+" "$log" 2>/dev/null | head -1 || true)
  added=$(grep -oP "Added to the repository: \K[^\s]+ [^\s]+" "$log" 2>/dev/null | head -1 || true)
  duration=$(grep -oP "processed [0-9]+ files, [^ ]+ [^ ]+ in \K[0-9]+:[0-9]+" "$log" 2>/dev/null | head -1 || true)
  note=$(grep -oP "(Stale file handle|ERROR: \K.*|backup failed)" "$log" 2>/dev/null | head -1 || true)

  if [[ -n "$snapshot" ]]; then
    status="✅ OK"
    (( OK++ )) || true
    $FAILURES_ONLY && continue
    printf "%-12s  %-8s  %-10s  %9s  %12s  %-7s  %s\n" \
      "$date" "$status" "$snapshot" "${files:--}" "${added:--}" "${duration:--}" "${note:-}"
  else
    status="❌ FAIL"
    (( FAIL++ )) || true
    note="${note:-unknown}"
    printf "%-12s  %-8s  %-10s  %9s  %12s  %-7s  %s\n" \
      "$date" "$status" "-" "-" "-" "-" "$note"
  fi
done

printf '%s\n' "$(printf '%.0s-' {1..80})"
printf "Total: %d runs  |  ✅ %d succeeded  |  ❌ %d failed\n" \
  $(( OK + FAIL )) "$OK" "$FAIL"
