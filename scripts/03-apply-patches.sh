#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-common.sh"

require_not_root

PATCH_SERIES="${PATCH_SERIES:-${REPO_ROOT}/patches/series}"
PATCH_ROOT="${PATCH_ROOT:-${REPO_ROOT}/patches}"
RESET_SRC="${RESET_SRC:-0}"

[[ -d "${SRC_DIR}/.git" ]] || die "Missing Chromium checkout: ${SRC_DIR}"
[[ -f "${PATCH_SERIES}" ]] || die "Missing patch series file: ${PATCH_SERIES}"

cd "${SRC_DIR}"

if [[ "${RESET_SRC}" == "1" ]]; then
  log "Resetting Chromium source before applying patches."
  git reset --hard
  git clean -fd
fi

if [[ ! -s "${PATCH_SERIES}" ]]; then
  log "Patch series is empty. Nothing to apply."
  exit 0
fi

log "Applying patch series: ${PATCH_SERIES}"

while IFS= read -r patch || [[ -n "${patch}" ]]; do
  patch="${patch%%#*}"
  patch="$(echo "${patch}" | xargs || true)"

  [[ -z "${patch}" ]] && continue

  patch_file="${PATCH_ROOT}/${patch}"
  [[ -f "${patch_file}" ]] || die "Patch listed in series does not exist: ${patch_file}"

  log "Checking patch: ${patch}"
  git apply --check "${patch_file}"

  log "Applying patch: ${patch}"
  git apply "${patch_file}"
done < "${PATCH_SERIES}"

log "Patch application complete."
git status --short
