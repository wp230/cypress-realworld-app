#!/usr/bin/env bash
# Stop the instance this run started. Leave .cursor/skills/verify-rwa/evidence in place.
set -euo pipefail

HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$HELPER_DIR/lib.sh"

require_repo
mkdir -p "$EVIDENCE_DIR"

if [[ ! -f "$PID_FILE" ]]; then
  echo "no pid file at ${PID_FILE}; nothing to stop."
  {
    echo "command: .cursor/skills/verify-rwa/helpers/cleanup.sh"
    echo "exit_code: 0"
    echo "note: no pid file"
  } >>"$EVIDENCE_DIR/commands.txt"
  exit 0
fi

pid="$(cat "$PID_FILE")"
if [[ -z "$pid" ]]; then
  echo "pid file is empty." >&2
  exit 1
fi

mapfile -t tree < <(process_tree "$pid")

if [[ -f "$LOG_FILE" ]]; then
  cp "$LOG_FILE" "$EVIDENCE_DIR/yarn-dev.log"
fi

if kill -0 "$pid" 2>/dev/null; then
  # Negative pid is the process group created by setsid in launch.sh.
  kill -TERM -- "-${pid}" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  for _ in $(seq 1 20); do
    if ! kill -0 "$pid" 2>/dev/null; then
      break
    fi
    sleep 0.5
  done
fi

for member in "${tree[@]}"; do
  if kill -0 "$member" 2>/dev/null; then
    kill -KILL "$member" 2>/dev/null || true
  fi
done

# Do not kill listeners we do not own. Report them.
for port in 3000 3001; do
  mapfile -t listeners < <(listener_pids "$port" || true)
  if [[ "${#listeners[@]}" -eq 0 ]]; then
    continue
  fi
  for listener in "${listeners[@]}"; do
    if pid_in_tree "$listener" "${tree[@]}"; then
      kill -KILL "$listener" 2>/dev/null || true
    else
      echo "port ${port} is still held by pid ${listener}, which this run did not start. Left it alone." >&2
    fi
  done
done

if [[ -f "$DB_SHA_FILE" && -f "$VERIFY_ROOT/data/database.json" ]]; then
  before="$(cat "$DB_SHA_FILE")"
  after="$(git -C "$VERIFY_ROOT" hash-object data/database.json || true)"
  if [[ "$before" != "missing" && -n "$before" && "$before" != "$after" ]]; then
    git -C "$VERIFY_ROOT" checkout -- data/database.json
  fi
fi

rm -rf "$RUN_DIR"

{
  echo "command: .cursor/skills/verify-rwa/helpers/cleanup.sh"
  echo "exit_code: 0"
  echo "stopped_pid: ${pid}"
} >>"$EVIDENCE_DIR/commands.txt"

echo "CLEANUP OK stopped pid ${pid}"
echo "evidence kept at ${EVIDENCE_DIR}"
