#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-common.sh"

require_not_root

log "Preparing Chromium checkout."

require_cmd git
require_cmd curl
require_cmd jq

ensure_dirs

if [[ ! -f "${GCLIENT_TEMPLATE}" ]]; then
  die "Missing gclient template: ${GCLIENT_TEMPLATE}"
fi

if [[ ! -d "${DEPOT_TOOLS_DIR}/.git" ]]; then
  log "Cloning depot_tools."
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "${DEPOT_TOOLS_DIR}"
else
  log "Updating depot_tools."
  git -C "${DEPOT_TOOLS_DIR}" pull --ff-only
fi

ensure_path

log "Bootstrapping depot_tools."
"${DEPOT_TOOLS_DIR}/update_depot_tools"
gclient --version >/dev/null

log "Writing .gclient from ${GCLIENT_TEMPLATE}."
mkdir -p "${CHROMIUM_ROOT}"
cp "${GCLIENT_TEMPLATE}" "${CHROMIUM_ROOT}/.gclient"

log "Resolving latest Linux Stable release."
curl -fsSL \
  "https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Linux&num=1" \
  -o "${STABLE_INFO_FILE}"

STABLE_VERSION="$(jq -r '.[0].version' "${STABLE_INFO_FILE}")"
STABLE_HASH="$(jq -r '.[0].hashes.chromium // empty' "${STABLE_INFO_FILE}")"

if [[ -z "${STABLE_VERSION}" || "${STABLE_VERSION}" == "null" ]]; then
  die "Could not resolve Stable version from ChromiumDash."
fi

echo "${STABLE_VERSION}" > "${STABLE_VERSION_FILE}"
log "Latest Linux Stable version: ${STABLE_VERSION}"

if [[ -n "${STABLE_HASH}" && "${STABLE_HASH}" != "null" ]]; then
  echo "${STABLE_HASH}" > "${STABLE_COMMIT_FILE}"
  log "Chromium Stable commit hash: ${STABLE_HASH}"
else
  : > "${STABLE_COMMIT_FILE}"
  log "ChromiumDash did not return a Chromium commit hash. Will sync default revision."
fi

cd "${CHROMIUM_ROOT}"

if [[ ! -d "${SRC_DIR}/.git" ]]; then
  log "Fetching Chromium source. This is the long first-time checkout."

  rm -f "${CHROMIUM_ROOT}/.gclient" "${CHROMIUM_ROOT}/.gclient_entries"

  fetch --nohooks --no-history chromium

  log "Replacing fetch-generated .gclient with repo template."
  cp "${GCLIENT_TEMPLATE}" "${CHROMIUM_ROOT}/.gclient"
else
  log "Chromium source already exists. Ensuring .gclient matches repo template."
  cp "${GCLIENT_TEMPLATE}" "${CHROMIUM_ROOT}/.gclient"
fi

if [[ -s "${STABLE_COMMIT_FILE}" ]]; then
  STABLE_COMMIT="$(cat "${STABLE_COMMIT_FILE}")"
  log "Syncing to Stable Chromium commit ${STABLE_COMMIT}."
  gclient sync \
    --revision "src@${STABLE_COMMIT}" \
    --nohooks \
    --delete_unversioned_trees
else
  log "Syncing Chromium default revision."
  gclient sync \
    --nohooks \
    --delete_unversioned_trees
fi

cd "${SRC_DIR}"

log "Installing Chromium build dependencies."
sudo ./build/install-build-deps.sh \
  --no-prompt \
  --no-chromeos-fonts \
  --no-nacl

log "Running gclient hooks."
gclient runhooks

log "Recording checkout metadata."
{
  echo "stable_version=$(cat "${STABLE_VERSION_FILE}" 2>/dev/null || true)"
  echo "stable_commit=$(cat "${STABLE_COMMIT_FILE}" 2>/dev/null || true)"
  echo "src_commit=$(git rev-parse HEAD)"
  echo "src_branch=$(git branch --show-current || true)"
  echo "prepared_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} | tee "${CHECKOUT_METADATA_FILE}"

log "Chromium preparation complete."
