#!/usr/bin/env bash
# Drive auth-invalid-user and auth-invalid-password through the Cypress harness.
# Screenshots are written under /tmp during the run, then copied to the evidence dir.
set -euo pipefail

HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$HELPER_DIR/lib.sh"

require_toolchain
require_repo

"$HELPER_DIR/doctor.sh" | tee "$RUN_DIR/doctor.txt"

mkdir -p "$ARTIFACT_DIR/screenshots" "$ARTIFACT_DIR/videos" "$EVIDENCE_DIR"
spec=".cursor/skills/verify-rwa/helpers/invalid-credentials.cy.ts"
# Cypress ignores a --spec path that does not match e2e.specPattern
# (cypress/tests/**/*.spec.ts). Override specPattern for this invocation only.
config="$(printf '{"e2e":{"specPattern":"%s"},"video":true,"screenshotsFolder":"%s","videosFolder":"%s","trashAssetsBeforeRuns":false}' \
  "$spec" "${ARTIFACT_DIR}/screenshots" "${ARTIFACT_DIR}/videos")"
cmd=(
  yarn cypress:run
  --spec "$spec"
  --config "$config"
)

cd "$VERIFY_ROOT"
set +e
"${cmd[@]}" >"$RUN_DIR/cypress-invalid-credentials.log" 2>&1
cypress_ec=$?
set -e

cp "$RUN_DIR/doctor.txt" "$EVIDENCE_DIR/doctor.txt"
cp "$RUN_DIR/cypress-invalid-credentials.log" "$EVIDENCE_DIR/cypress-invalid-credentials.log"

{
  echo "command: ${cmd[*]}"
  echo "exit_code: ${cypress_ec}"
  echo "spec: ${spec}"
  echo "subfeatures: auth-invalid-user auth-invalid-password"
  echo "node: $(node -v)"
  echo "node_path: $(command -v node)"
  echo "yarn: $(yarn --version)"
  if grep -E '[0-9]+ passing' "$EVIDENCE_DIR/cypress-invalid-credentials.log" >/dev/null; then
    echo "cypress_summary: $(grep -E '[0-9]+ passing' "$EVIDENCE_DIR/cypress-invalid-credentials.log" | tail -n 1)"
  fi
} >"$EVIDENCE_DIR/commands.txt"

copy_named() {
  local name="$1"
  local found
  mapfile -t found < <(find "$ARTIFACT_DIR/screenshots" -type f -name "${name}.png" | sort)
  if [[ "${#found[@]}" -ne 1 ]]; then
    echo "expected one ${name}.png screenshot, found ${#found[@]}" >&2
    return 1
  fi
  cp "${found[0]}" "$EVIDENCE_DIR/${name}.png"
}

if [[ "$cypress_ec" -ne 0 ]]; then
  echo "Cypress exited ${cypress_ec}. Log: ${EVIDENCE_DIR}/cypress-invalid-credentials.log" >&2
  exit "$cypress_ec"
fi

copy_named auth-invalid-user
copy_named auth-invalid-password

shopt -s nullglob
videos=("$ARTIFACT_DIR"/videos/*.mp4)
shopt -u nullglob
if [[ "${#videos[@]}" -ge 1 ]]; then
  cp "${videos[0]}" "$EVIDENCE_DIR/invalid-credentials.mp4"
fi

echo "DRIVE OK exit_code=${cypress_ec}"
echo "evidence ${EVIDENCE_DIR}"
