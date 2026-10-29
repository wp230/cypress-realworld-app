#!/usr/bin/env bash
# Start one Cypress Real World App dev instance for verification.
# Records the PID and log under /tmp/verify-rwa. Does not write proof evidence.
set -euo pipefail

HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$HELPER_DIR/lib.sh"

require_toolchain
require_repo

if [[ ! -d "$VERIFY_ROOT/node_modules/cypress" ]]; then
  echo "node_modules is missing. From ${VERIFY_ROOT} run: yarn install" >&2
  echo "Do not change dependency versions." >&2
  exit 1
fi

if [[ -f "$PID_FILE" ]]; then
  existing="$(cat "$PID_FILE" || true)"
  if [[ -n "${existing}" ]] && kill -0 "$existing" 2>/dev/null; then
    echo "A verify-rwa instance is already running as pid ${existing}. Refusing to start another." >&2
    echo "Run helpers/doctor.sh, or helpers/cleanup.sh if that pid is yours and you are finished." >&2
    exit 1
  fi
fi

if port_busy 3000 || port_busy 3001; then
  echo "Port 3000 or 3001 is already in use. This app cannot share those ports." >&2
  echo "Refusing to start a second instance." >&2
  echo "port 3000 inodes: $(listen_inodes 3000 | tr '\n' ' ')" >&2
  echo "port 3001 inodes: $(listen_inodes 3001 | tr '\n' ' ')" >&2
  exit 1
fi

mkdir -p "$RUN_DIR"
rm -f "$LOG_FILE"
cd "$VERIFY_ROOT"

if [[ -f data/database.json ]]; then
  git hash-object data/database.json >"$DB_SHA_FILE"
else
  echo "missing" >"$DB_SHA_FILE"
fi

# setsid makes yarn the process-group leader so cleanup can signal that group,
# not every node process on the machine.
setsid yarn dev >"$LOG_FILE" 2>&1 </dev/null &
echo $! >"$PID_FILE"
pid="$(cat "$PID_FILE")"

cat >"$META_FILE" <<EOF
root=${VERIFY_ROOT}
pid=${pid}
log=${LOG_FILE}
started=$(date -Is)
node=$(node -v)
node_path=$(command -v node)
yarn=$(yarn --version)
EOF

echo "started pid ${pid}"
echo "log ${LOG_FILE}"

ready=0
for _ in $(seq 1 60); do
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "yarn dev exited before it was ready. Last log lines:" >&2
    tail -n 80 "$LOG_FILE" >&2 || true
    exit 1
  fi
  frontend_ok=0
  backend_ok=0
  module_ok=0
  if curl -sf "http://localhost:3000/" | grep -q 'id="root"'; then
    frontend_ok=1
  fi
  if curl -sf "http://localhost:3001/" | grep -q "Cypress Realworld App - backend"; then
    backend_ok=1
  fi
  if curl -sf -o /dev/null "http://localhost:3000/src/index.tsx"; then
    module_ok=1
  fi
  if [[ "$frontend_ok" == 1 && "$backend_ok" == 1 && "$module_ok" == 1 ]] \
    && grep -q "Backend server running at http://localhost:3001" "$LOG_FILE" \
    && grep -q "http://localhost:3000" "$LOG_FILE"; then
    if grep -q "Failed to start the backend server" "$LOG_FILE"; then
      echo "Backend did not bind 3001. See ${LOG_FILE}." >&2
      exit 1
    fi
    ready=1
    break
  fi
  sleep 2
done

if [[ "$ready" != 1 ]]; then
  echo "Timed out waiting for http://localhost:3000 and http://localhost:3001." >&2
  echo "Use localhost. Vite binds ::1:3000, so 127.0.0.1 is the wrong address." >&2
  tail -n 80 "$LOG_FILE" >&2 || true
  exit 1
fi

echo "ready http://localhost:3000 http://localhost:3001"
