#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-common.sh"

require_not_root

[[ -d "${SRC_DIR}" ]] || die "Missing Chromium source dir: ${SRC_DIR}."

mkdir -p "${DIST_ROOT}" "${BUILD_ROOT}/packages"

cd "${SRC_DIR}"

VERSION="$(cat "${STABLE_VERSION_FILE}" 2>/dev/null || true)"
if [[ -z "${VERSION}" ]]; then
  VERSION="$(git rev-parse --short HEAD)"
fi

COMMIT="$(git rev-parse HEAD)"
SHORT_COMMIT="$(git rev-parse --short HEAD)"
STAMP="$(date -u '+%Y%m%dT%H%M%SZ')"

PACKAGE_ROOT="${BUILD_ROOT}/packages"
rm -rf "${PACKAGE_ROOT}"
mkdir -p "${PACKAGE_ROOT}"

copy_runtime_files() {
  local out_dir="$1"
  local dest="$2"

  mkdir -p "${dest}"

  local entries=(
    "chrome"
    "headless_shell"
    "chrome-wrapper"
    "chrome_sandbox"
    "chrome_crashpad_handler"
    "libEGL.so"
    "libGLESv2.so"
    "libvk_swiftshader.so"
    "libvulkan.so.1"
    "v8_context_snapshot.bin"
    "snapshot_blob.bin"
    "icudtl.dat"
    "resources.pak"
    "chrome_100_percent.pak"
    "chrome_200_percent.pak"
    "headless_lib.pak"
    "locales"
    "MEIPreload"
    "PrivacySandboxAttestationsPreloaded"
    "WidevineCdm"
    "xdg-mime"
    "xdg-settings"
    "swiftshader"
    "angledata"
  )

  for entry in "${entries[@]}"; do
    if [[ -e "${out_dir}/${entry}" ]]; then
      cp -a "${out_dir}/${entry}" "${dest}/"
    fi
  done

  cp -a "${out_dir}"/*.so "${dest}/" 2>/dev/null || true
  cp -a "${out_dir}"/*.pak "${dest}/" 2>/dev/null || true
}

write_metadata() {
  local dest="$1"
  local target_name="$2"
  local out_dir="$3"

  cat > "${dest}/BUILD-METADATA.txt" <<META
target=${target_name}
stable_version=${VERSION}
src_commit=${COMMIT}
src_short_commit=${SHORT_COMMIT}
built_at=${STAMP}
build_host=$(hostname)
build_os=$(lsb_release -ds 2>/dev/null || cat /etc/os-release)
target_os=linux
target_cpu=x64
out_dir=${out_dir}
META

  cp -a "${out_dir}/args.gn" "${dest}/args.gn"

  cat > "${dest}/README.txt" <<README
This package was built from Chromium source for Linux x86_64.

Target: ${target_name}
Version label: ${VERSION}
Commit: ${COMMIT}

Examples:

Headless shell:
  ./headless_shell --no-sandbox --disable-gpu --dump-dom https://example.com

Chrome headless:
  ./chrome --headless=new --no-sandbox --disable-gpu --remote-debugging-port=9222 about:blank

Chrome headed:
  ./chrome --no-sandbox

Notes:
- Install normal Linux desktop/runtime libraries on the target machine if needed.
- Running as root usually requires --no-sandbox.
- For server environments, use native headless mode or xvfb.
README
}

package_target() {
  local target_name="$1"
  local out_dir="$2"
  local primary_bin="$3"

  if [[ ! -x "${out_dir}/${primary_bin}" ]]; then
    log "Skipping ${target_name}; missing ${out_dir}/${primary_bin}"
    return 0
  fi

  local pkg_name="chromium-${target_name}-linux-x64-${VERSION}-${SHORT_COMMIT}"
  local pkg_dir="${PACKAGE_ROOT}/${pkg_name}"

  log "Packaging ${target_name} from ${out_dir}."

  mkdir -p "${pkg_dir}"
  copy_runtime_files "${out_dir}" "${pkg_dir}"
  write_metadata "${pkg_dir}" "${target_name}" "${out_dir}"

  cat > "${pkg_dir}/run-${target_name}.sh" <<RUNNER
#!/usr/bin/env bash
set -euo pipefail
DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
cd "\${DIR}"

if [[ -x "./${primary_bin}" ]]; then
  exec "./${primary_bin}" "\$@"
else
  echo "Missing ./${primary_bin}" >&2
  exit 1
fi
RUNNER
  chmod +x "${pkg_dir}/run-${target_name}.sh"

  local tarball="${DIST_ROOT}/${pkg_name}.tar.zst"
  tar --zstd -cf "${tarball}" -C "${PACKAGE_ROOT}" "${pkg_name}"

  sha256sum "${tarball}" > "${tarball}.sha256"

  log "Created ${tarball}"
  ls -lh "${tarball}" "${tarball}.sha256"
}

package_target "headless-shell" "${HEADLESS_OUT}" "headless_shell"
package_target "chrome" "${CHROME_OUT}" "chrome"

log "Package directory:"
ls -lh "${DIST_ROOT}"
