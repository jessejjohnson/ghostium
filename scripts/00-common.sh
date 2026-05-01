#!/usr/bin/env bash

set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

WORK_MOUNT="${WORK_MOUNT:-/work}"
CHROMIUM_ROOT="${CHROMIUM_ROOT:-/work/chromium}"
SRC_DIR="${SRC_DIR:-/work/chromium/src}"
DEPOT_TOOLS_DIR="${DEPOT_TOOLS_DIR:-/work/depot_tools}"
BUILD_ROOT="${BUILD_ROOT:-/work/build}"
DIST_ROOT="${DIST_ROOT:-/work/dist}"
LOG_ROOT="${LOG_ROOT:-/work/logs}"

HEADLESS_OUT="${HEADLESS_OUT:-out/headless}"
CHROME_OUT="${CHROME_OUT:-out/chrome}"

SWAPFILE="${SWAPFILE:-/work/swapfile}"
SWAP_SIZE="${SWAP_SIZE:-32G}"

JOBS="${JOBS:-24}"

GCLIENT_TEMPLATE="${GCLIENT_TEMPLATE:-${REPO_ROOT}/config/linux-x64.gclient}"
HEADLESS_ARGS_TEMPLATE="${HEADLESS_ARGS_TEMPLATE:-${REPO_ROOT}/config/headless.args.gn}"
CHROME_ARGS_TEMPLATE="${CHROME_ARGS_TEMPLATE:-${REPO_ROOT}/config/chrome.args.gn}"

STABLE_INFO_FILE="${CHROMIUM_ROOT}/stable-release.json"
STABLE_VERSION_FILE="${CHROMIUM_ROOT}/stable-version.txt"
STABLE_COMMIT_FILE="${CHROMIUM_ROOT}/stable-commit.txt"
CHECKOUT_METADATA_FILE="${CHROMIUM_ROOT}/checkout-metadata.txt"

log() {
  printf '\n[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "Run this script with sudo."
}

require_not_root() {
  [[ "${EUID}" -ne 0 ]] || die "Do not run this script with sudo."
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

ensure_path() {
  export PATH="${DEPOT_TOOLS_DIR}:${PATH}"
}

ensure_dirs() {
  mkdir -p "${CHROMIUM_ROOT}" "${BUILD_ROOT}" "${DIST_ROOT}" "${LOG_ROOT}"
}

run_logged() {
  local name="$1"
  shift
  mkdir -p "${LOG_ROOT}"
  log "Running: $name"
  "$@" 2>&1 | tee "${LOG_ROOT}/${name}.log"
}

sha256_file() {
  local file="$1"
  sha256sum "$file" | awk '{print $1}'
}
