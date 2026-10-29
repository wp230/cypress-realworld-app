#!/usr/bin/env bash
# Shared paths for the verify-rwa helpers. Source this; do not execute it.
set -euo pipefail

VERIFY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
RUN_DIR="/tmp/verify-rwa"
PID_FILE="$RUN_DIR/pid"
LOG_FILE="$RUN_DIR/yarn-dev.log"
META_FILE="$RUN_DIR/meta.env"
DB_SHA_FILE="$RUN_DIR/database.json.sha"
ARTIFACT_DIR="$RUN_DIR/artifacts"
EVIDENCE_DIR="$VERIFY_ROOT/.cursor/skills/verify-rwa/evidence"
NODE_BIN_DIR="${NVM_DIR:-$HOME/.nvm}/versions/node/v22.20.0/bin"

export PATH="$NODE_BIN_DIR:$PATH"
hash -r

require_toolchain() {
  local node_path yarn_ver
  node_path="$(command -v node)"
  if [[ "$(node -v)" != "v22.20.0" ]]; then
    echo "Node must be v22.20.0 (.node-version). Got $(node -v) at ${node_path}." >&2
    echo "Install it and prepend its bin: export PATH=\"${NODE_BIN_DIR}:\$PATH\"" >&2
    exit 1
  fi
  if [[ "$node_path" != "$NODE_BIN_DIR/node" ]]; then
    echo "node on PATH is ${node_path}, not ${NODE_BIN_DIR}/node. Another Node is shadowing v22.20.0." >&2
    exit 1
  fi
  yarn_ver="$(yarn --version)"
  case "$yarn_ver" in
    1.*) ;;
    *)
      echo "Yarn Classic 1.x is required (packageManager yarn@1.22.22). Got ${yarn_ver}." >&2
      exit 1
      ;;
  esac
}

require_repo() {
  if [[ ! -f "$VERIFY_ROOT/package.json" || ! -f "$VERIFY_ROOT/.node-version" ]]; then
    echo "VERIFY_ROOT ${VERIFY_ROOT} is not the Cypress Real World App checkout." >&2
    exit 1
  fi
}

# PIDs of a process and every descendant. Never matches by process name.
process_tree() {
  local pid="$1"
  local child
  echo "$pid"
  for child in $(ps -o pid= --ppid "$pid" 2>/dev/null || true); do
    process_tree "$child"
  done
}

# This image does not ship ss. Match LISTEN inodes in /proc/net/tcp{,6}
# to the process whose fd points at socket:[inode].
listen_inodes() {
  python3 - "$1" <<'PY'
import sys
port = int(sys.argv[1])
for name in ("tcp", "tcp6"):
    try:
        lines = open(f"/proc/net/{name}")
    except FileNotFoundError:
        continue
    next(lines, None)
    for line in lines:
        parts = line.split()
        if len(parts) < 10 or parts[3] != "0A":
            continue
        local_port = int(parts[1].split(":")[1], 16)
        if local_port == port and parts[9] != "0":
            print(parts[9])
PY
}

pid_for_socket_inode() {
  local inode="$1" fd target pid
  for fd in /proc/[0-9]*/fd/*; do
    target="$(readlink "$fd" 2>/dev/null || true)"
    if [[ "$target" == "socket:[${inode}]" ]]; then
      pid="${fd#/proc/}"
      echo "${pid%%/*}"
      return 0
    fi
  done
  return 1
}

listener_pids() {
  local port="$1" inode pid
  while read -r inode; do
    [[ -n "$inode" ]] || continue
    if pid="$(pid_for_socket_inode "$inode")"; then
      echo "$pid"
    fi
  done < <(listen_inodes "$port") | sort -u
}

port_busy() {
  [[ -n "$(listen_inodes "$1")" ]]
}

pid_in_tree() {
  local needle="$1"
  shift
  local pid
  for pid in "$@"; do
    if [[ "$pid" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}
