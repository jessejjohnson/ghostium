#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_ROOT}/scripts/00-common.sh"

require_not_root

HEADLESS_BIN="${SRC_DIR}/${HEADLESS_OUT}/headless_shell"
CHROME_BIN="${SRC_DIR}/${CHROME_OUT}/chrome"
FIXTURE="${REPO_ROOT}/tests/fixtures/simple-page.html"

[[ -f "${FIXTURE}" ]] || die "Missing fixture: ${FIXTURE}"

if [[ -x "${HEADLESS_BIN}" ]]; then
  log "Smoke testing headless_shell."
  "${HEADLESS_BIN}" \
    --no-sandbox \
    --disable-gpu \
    --dump-dom \
    "file://${FIXTURE}" \
    | grep -q "ghostium-smoke-ok"

  log "headless_shell smoke test passed."
else
  log "Skipping headless_shell smoke test; binary not found."
fi

if [[ -x "${CHROME_BIN}" ]]; then
  log "Smoke testing chrome --headless=new."
  "${CHROME_BIN}" \
    --headless=new \
    --no-sandbox \
    --disable-gpu \
    --dump-dom \
    "file://${FIXTURE}" \
    | grep -q "ghostium-smoke-ok"

  log "chrome headless smoke test passed."
else
  log "Skipping chrome smoke test; binary not found."
fi
