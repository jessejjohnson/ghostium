#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-common.sh"

require_root

BUILD_USER="${BUILD_USER:-ubuntu}"
WORK_OWNER="${WORK_OWNER:-ubuntu:ubuntu}"
FORMAT_WORK_DEVICE="${FORMAT_WORK_DEVICE:-1}"

log "Initializing EC2 instance for Chromium builds."

if [[ ! -d "/home/${BUILD_USER}" ]]; then
  die "Expected user /home/${BUILD_USER} does not exist. Set BUILD_USER if needed."
fi

log "Installing base system packages."
apt-get update
apt-get install -y \
  apt-transport-https \
  build-essential \
  ca-certificates \
  curl \
  file \
  git \
  jq \
  lsb-release \
  nano \
  ninja-build \
  nvme-cli \
  pkg-config \
  python3 \
  python3-pip \
  rsync \
  software-properties-common \
  tar \
  tmux \
  unzip \
  vim \
  wget \
  xz-utils \
  zip \
  zstd

find_work_device() {
  if [[ -n "${WORK_DEVICE:-}" ]]; then
    echo "${WORK_DEVICE}"
    return 0
  fi

  local root_source root_pkname
  root_source="$(findmnt -n -o SOURCE / || true)"
  root_pkname=""
  if [[ -n "${root_source}" ]]; then
    root_pkname="$(lsblk -no PKNAME "${root_source}" 2>/dev/null | head -n1 || true)"
  fi

  while read -r name type mountpoint; do
    [[ "${type}" == "disk" ]] || continue
    [[ -z "${mountpoint}" ]] || continue
    [[ "${name}" != loop* ]] || continue
    [[ -n "${root_pkname}" && "${name}" == "${root_pkname}" ]] && continue
    echo "/dev/${name}"
    return 0
  done < <(lsblk -dn -o NAME,TYPE,MOUNTPOINT)

  return 1
}

log "Selecting work EBS volume."
BUILD_DEVICE="$(find_work_device || true)"
if [[ -z "${BUILD_DEVICE}" ]]; then
  lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS,MODEL
  die "Could not find an unmounted non-root disk. Attach the EBS build volume, or set WORK_DEVICE=/dev/..."
fi

[[ -b "${BUILD_DEVICE}" ]] || die "Selected device is not a block device: ${BUILD_DEVICE}"

log "Selected build device: ${BUILD_DEVICE}"
lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS,MODEL "${BUILD_DEVICE}" || true

EXISTING_FS="$(blkid -s TYPE -o value "${BUILD_DEVICE}" 2>/dev/null || true)"

if [[ -n "${EXISTING_FS}" ]]; then
  log "Device already has filesystem '${EXISTING_FS}'. Not formatting."
elif [[ "${FORMAT_WORK_DEVICE}" == "1" ]]; then
  log "Formatting ${BUILD_DEVICE} as ext4."
  mkfs.ext4 -F -L chromium-work "${BUILD_DEVICE}"
else
  die "${BUILD_DEVICE} has no filesystem and FORMAT_WORK_DEVICE=0."
fi

mkdir -p "${WORK_MOUNT}"

UUID="$(blkid -s UUID -o value "${BUILD_DEVICE}")"
[[ -n "${UUID}" ]] || die "Could not determine UUID for ${BUILD_DEVICE}."

if ! grep -q "UUID=${UUID}" /etc/fstab; then
  log "Adding /etc/fstab entry for ${WORK_MOUNT}."
  echo "UUID=${UUID} ${WORK_MOUNT} ext4 defaults,nofail,noatime 0 2" >> /etc/fstab
else
  log "/etc/fstab already contains UUID=${UUID}."
fi

log "Mounting ${WORK_MOUNT}."
mount -a
findmnt "${WORK_MOUNT}" >/dev/null || die "${WORK_MOUNT} is not mounted."

log "Creating working directories."
mkdir -p \
  "${CHROMIUM_ROOT}" \
  "${BUILD_ROOT}" \
  "${DIST_ROOT}" \
  "${LOG_ROOT}" \
  "${WORK_MOUNT}/tmp"

chmod 755 "${WORK_MOUNT}"
chmod 1777 "${WORK_MOUNT}/tmp"

log "Applying sysctl settings."
cat > /etc/sysctl.d/99-chromium-builder.conf <<SYSCTL
vm.swappiness=10
fs.inotify.max_user_watches=1048576
fs.inotify.max_user_instances=1024
SYSCTL
sysctl --system >/dev/null

log "Raising file descriptor limits for ${BUILD_USER}."
cat > /etc/security/limits.d/99-chromium-builder.conf <<LIMITS
${BUILD_USER} soft nofile 1048576
${BUILD_USER} hard nofile 1048576
${BUILD_USER} soft nproc  1048576
${BUILD_USER} hard nproc  1048576
LIMITS

log "Instance initialization complete."
df -h "${WORK_MOUNT}"
