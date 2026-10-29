#!/usr/bin/env bash
# Read-only check: is the running app the instance this verification run started?
set -euo pipefail

HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$HELPER_DIR/lib.sh"

require_toolchain
require_repo

fail() {
  echo "DOCTOR FAIL: $*"
  exit 1
}

[[ -f "$PID_FILE" ]] || fail "no pid file at ${PID_FILE}. Launch first."
[[ -f "$LOG_FILE" ]] || fail "no log file at ${LOG_FILE}."
[[ -f "$META_FILE" ]] || fail "no meta file at ${META_FILE}."

pid="$(cat "$PID_FILE")"
[[ -n "$pid" ]] || fail "pid file is empty."
kill -0 "$pid" 2>/dev/null || fail "recorded pid ${pid} is not running."

cwd="$(readlink "/proc/${pid}/cwd" || true)"
[[ "$cwd" == "$VERIFY_ROOT" ]] || fail "pid ${pid} cwd is ${cwd}, not ${VERIFY_ROOT}."

stdout_target="$(readlink "/proc/${pid}/fd/1" || true)"
[[ "$stdout_target" == "$LOG_FILE" ]] || fail "pid ${pid} stdout is ${stdout_target}, not ${LOG_FILE}."

cmdline="$(tr '\0' ' ' <"/proc/${pid}/cmdline")"
[[ "$cmdline" == *yarn* ]] || fail "pid ${pid} cmdline is not yarn dev: ${cmdline}"

# shellcheck source=/dev/null
source "$META_FILE"
[[ "${root}" == "$VERIFY_ROOT" ]] || fail "meta root ${root} is not ${VERIFY_ROOT}."
[[ "${log}" == "$LOG_FILE" ]] || fail "meta log does not match ${LOG_FILE}."

grep -q "Backend server running at http://localhost:3001" "$LOG_FILE" \
  || fail "log is missing the backend ready line for port 3001."
if grep -q "Failed to start the backend server" "$LOG_FILE"; then
  fail "backend fell off port 3001. Cypress apiUrl would not match."
fi
grep -q "http://localhost:3000" "$LOG_FILE" || fail "log is missing the frontend URL."

curl -sf "http://localhost:3000/" | grep -q 'id="root"' \
  || fail "http://localhost:3000 did not serve the app shell. Do not substitute 127.0.0.1."
curl -sf "http://localhost:3001/" | grep -q "Cypress Realworld App - backend" \
  || fail "http://localhost:3001 did not return the backend banner."
curl -sf -o /dev/null "http://localhost:3000/src/index.tsx" \
  || fail "Vite is not transforming /src/index.tsx yet."

mapfile -t tree < <(process_tree "$pid")
[[ "${#tree[@]}" -gt 0 ]] || fail "could not read the process tree for ${pid}."

for port in 3000 3001; do
  mapfile -t listeners < <(listener_pids "$port")
  if [[ "${#listeners[@]}" -eq 0 ]]; then
    fail "nothing is listening on port ${port}."
  fi
  for listener in "${listeners[@]}"; do
    if ! pid_in_tree "$listener" "${tree[@]}"; then
      fail "port ${port} is held by pid ${listener}, which is not a descendant of ${pid}."
    fi
  done
done

# Local auth only. Third-party provider modes are different apps.
backend_pid=""
for candidate in "${tree[@]}"; do
  cand_cmd="$(tr '\0' ' ' <"/proc/${candidate}/cmdline" 2>/dev/null || true)"
  if [[ "$cand_cmd" == *backend/app.ts* || "$cand_cmd" == *backend/app.js* ]]; then
    backend_pid="$candidate"
    break
  fi
done
[[ -n "$backend_pid" ]] || fail "no backend/app.ts process under pid ${pid}."

environ="$(tr '\0' '\n' <"/proc/${backend_pid}/environ" 2>/dev/null || true)"
echo "$environ" | grep -q '^NODE_ENV=development$' \
  || fail "backend NODE_ENV is not development, so /testData seed will not be mounted."
if echo "$environ" | grep -q '^VITE_AUTH0=\|^VITE_OKTA=\|^VITE_AWS_COGNITO=\|^VITE_GOOGLE='; then
  fail "backend was started with a third-party auth provider. This skill drives local sign-in."
fi

users_json="$(curl -sf "http://localhost:3001/testData/users" || true)"
[[ "$users_json" == *'"username"'* ]] || fail "seeded users are not readable at /testData/users."

echo "DOCTOR OK"
echo "pid ${pid}"
echo "cwd ${cwd}"
echo "log ${LOG_FILE}"
echo "stdout ${stdout_target}"
echo "node ${node} at ${node_path}"
echo "yarn ${yarn}"
echo "ports 3000 and 3001 are held by descendants of ${pid}"
echo "backend pid ${backend_pid} NODE_ENV=development"
echo "seed users are present"
echo "frontend http://localhost:3000"
echo "api http://localhost:3001"
