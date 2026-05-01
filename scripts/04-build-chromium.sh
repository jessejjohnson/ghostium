#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-common.sh"

require_not_root
ensure_path

BUILD_HEADLESS="${BUILD_HEADLESS:-1}"
BUILD_CHROME="${BUILD_CHROME:-1}"

require_cmd gn
require_cmd autoninja

[[ -d "${SRC_DIR}" ]] || die "Missing Chromium source dir: ${SRC_DIR}. Run 02-prepare-chromium.sh first."
[[ -f "${HEADLESS_ARGS_TEMPLATE}" ]] || die "Missing headless GN template: ${HEADLESS_ARGS_TEMPLATE}"
[[ -f "${CHROME_ARGS_TEMPLATE}" ]] || die "Missing chrome GN template: ${CHROME_ARGS_TEMPLATE}"

log "Creating or enabling swap."

if [[ ! -f "${SWAPFILE}" ]]; then
  log "Creating swapfile ${SWAPFILE} size ${SWAP_SIZE}."
  if ! fallocate -l "${SWAP_SIZE}" "${SWAPFILE}"; then
    log "fallocate failed; using dd fallback."
    dd if=/dev/zero of="${SWAPFILE}" bs=1M count="$((32 * 1024))" status=progress
  fi
  chmod 600 "${SWAPFILE}"
  mkswap "${SWAPFILE}"
else
  log "Swapfile already exists: ${SWAPFILE}"
fi

if ! swapon --show=NAME | grep -qx "${SWAPFILE}"; then
  log "Enabling swapfile."
  sudo swapon "${SWAPFILE}"
else
  log "Swapfile already enabled."
fi

if ! grep -qF "${SWAPFILE} none swap sw 0 0" /etc/fstab; then
  log "Adding swapfile to /etc/fstab."
  echo "${SWAPFILE} none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
fi

free -h

cd "${SRC_DIR}"

if [[ "${BUILD_HEADLESS}" == "1" ]]; then
  log "Configuring headless_shell build."
  mkdir -p "${HEADLESS_OUT}"
  cp "${HEADLESS_ARGS_TEMPLATE}" "${HEADLESS_OUT}/args.gn"
  gn gen "${HEADLESS_OUT}" --check
fi

if [[ "${BUILD_CHROME}" == "1" ]]; then
  log "Configuring normal chrome build."
  mkdir -p "${CHROME_OUT}"
  cp "${CHROME_ARGS_TEMPLATE}" "${CHROME_OUT}/args.gn"
  gn gen "${CHROME_OUT}" --check
fi

log "Starting build with JOBS=${JOBS}."

if [[ "${BUILD_HEADLESS}" == "1" ]]; then
  log "Building headless_shell."
  autoninja -C "${HEADLESS_OUT}" headless_shell -j "${JOBS}"
fi

if [[ "${BUILD_CHROME}" == "1" ]]; then
  log "Building chrome."
  autoninja -C "${CHROME_OUT}" chrome -j "${JOBS}"
fi

log "Build complete."

if [[ -x "${HEADLESS_OUT}/headless_shell" ]]; then
  ls -lh "${HEADLESS_OUT}/headless_shell"
fi

if [[ -x "${CHROME_OUT}/chrome" ]]; then
  ls -lh "${CHROME_OUT}/chrome"
fi
