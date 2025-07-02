#!/bin/bash
set -e

# Ghostium Step 2: Prepare Environment for Chromium Build
# This script prepares the Linux x64 instance with all necessary dependencies for Chromium build

PROJECT_NAME="ghostium-build"
DEPOT_TOOLS_DIR="/opt/depot_tools"
CHROMIUM_DIR="/mnt/chromium-build/chromium"
BUILD_USER="ghostium-builder"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Preparing Ghostium build environment for Linux x64..."


# Function to install dependencies
install_dependencies() {
    log "Installing Ubuntu dependencies..."
    
    # Update system
    sudo apt update -y
    
    # Install build essentials
    sudo apt install -y \
        build-essential git python3 python3-pip curl unzip openjdk-17-jdk \
        ninja-build pkg-config libglib2.0-dev libgtk-3-dev \
        libnss3-dev libnspr4-dev libasound2-dev libpulse-dev libxss-dev \
        libxtst-dev libxcomposite-dev libxdamage-dev libxrandr-dev libgbm-dev \
        libpango1.0-dev libatk1.0-dev libatk-bridge2.0-dev libcurl4-openssl-dev \
        libdrm-dev libxkbcommon-dev mesa-common-dev libgl1-mesa-dev \
        libglu1-mesa-dev libegl1-mesa-dev libgles2-mesa-dev \
        libcups2-dev libxcomposite-dev libxdamage-dev libxrandr-dev \
        libxtst-dev libxss-dev nodejs npm clang llvm lld wget
}

# Function to create build user
create_build_user() {
    log "Creating build user..."
    if ! id "$BUILD_USER" &>/dev/null; then
        sudo useradd -m -s /bin/bash "$BUILD_USER"
        sudo usermod -aG sudo "$BUILD_USER"
    fi
    
    # Create necessary directories
    sudo mkdir -p "$DEPOT_TOOLS_DIR"
    sudo chown -R "$BUILD_USER:$BUILD_USER" "$DEPOT_TOOLS_DIR"
    
    # Note: CHROMIUM_DIR will be created on the mounted volume by step3
}

# Function to install depot_tools
install_depot_tools() {
    log "Installing depot_tools..."
    
    # Linux installation
    if [ ! -d "$DEPOT_TOOLS_DIR/.git" ]; then
        sudo -u "$BUILD_USER" git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT_TOOLS_DIR"
    fi
    
    # Add to PATH for build user
    if ! grep -q "depot_tools" /home/$BUILD_USER/.bashrc; then
        echo "export PATH=\"$DEPOT_TOOLS_DIR:\$PATH\"" | sudo tee -a /home/$BUILD_USER/.bashrc
    fi
}

# Function to configure git
configure_git() {
    log "Configuring git..."
    
    sudo -u "$BUILD_USER" git config --global user.name "Jesse Johnson"
    sudo -u "$BUILD_USER" git config --global user.email "johnson.jesse@live.com"
    sudo -u "$BUILD_USER" git config --global core.autocrlf false
    sudo -u "$BUILD_USER" git config --global core.filemode false
    sudo -u "$BUILD_USER" git config --global color.ui true
}

# Function to download build scripts
download_build_scripts() {
    log "Downloading build scripts..."
    
    sudo -u "$BUILD_USER" aws s3 cp "s3://${PROJECT_NAME}-artifacts/step3-build-chromium.sh" "/home/$BUILD_USER/"
    sudo chmod +x "/home/$BUILD_USER/step3-build-chromium.sh"
}

# Function to prepare chromium workspace (will be done on mounted volume in step3)
prepare_chromium_workspace() {
    log "Chromium workspace will be prepared on mounted volume in step3..."
    # Note: The .gclient file will be created by step3 on the mounted volume
}

# Function to set up build environment variables
setup_environment() {
    echo "Setting up environment variables..."
    
    sudo -u "$BUILD_USER" tee -a "/home/$BUILD_USER/.bashrc" > /dev/null << EOF
# Ghostium build environment
export CHROMIUM_DIR="/mnt/chromium-build/chromium"
export GYP_DEFINES="use_sysroot=1"
export CC=clang
export CXX=clang++
EOF
}

# Function to optimize system for building
optimize_system() {
    log "Optimizing system for building..."
    
    # Increase file descriptor limits
    echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
    echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
    
    # Optimize memory settings
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
    echo "vm.overcommit_memory=1" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
    
    if ! swapon --show | grep -q "/swapfile"; then
        log "Setting up swap space..."
        sudo fallocate -l 16G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=16384
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi
}

# Function to mount and prepare build volume
mount_build_volume() {
    log "Setting up 500GB build volume..."
    
    # Check if volume is already mounted
    if mountpoint -q /mnt/chromium-build; then
        log "Build volume already mounted at /mnt/chromium-build"
        return 0
    fi
    
    # Wait for the EBS volume to be available
    log "Waiting for EBS volume /dev/nvme1n1 to be available..."
    while [ ! -b /dev/nvme1n1 ]; do
        sleep 5
        log "Still waiting for /dev/nvme1n1..."
    done
    
    # Check if volume has a filesystem
    if ! sudo file -s /dev/nvme1n1 | grep -q filesystem; then
        log "Formatting EBS volume with ext4 filesystem..."
        sudo mkfs.ext4 /dev/nvme1n1
    fi
    
    # Create mount point
    sudo mkdir -p /mnt/chromium-build
    
    # Mount the volume
    log "Mounting EBS volume..."
    sudo mount /dev/nvme1n1 /mnt/chromium-build
    
    # Set ownership to build user
    sudo chown -R $BUILD_USER:$BUILD_USER /mnt/chromium-build
    
    # Update environment variables to use mounted volume
    export CHROMIUM_DIR="/mnt/chromium-build/chromium"
    
    log "Build volume mounted and ready at /mnt/chromium-build"
}

# Main execution
main() {
    log "Starting Ghostium environment preparation..."
    log "Platform: Linux x64"
    log ""
    
    install_dependencies
    create_build_user
    install_depot_tools
    configure_git
    download_build_scripts
    prepare_chromium_workspace
    setup_environment
    optimize_system
    mount_build_volume
    
    log ""
    log "Environment preparation complete!"
    log ""
    log "Summary:"
    log "==========="
    log "Platform: Linux x64"
    log "Depot tools: Installed"
    log "Build user: $BUILD_USER"
    log "Chromium workspace: Will be prepared on mounted volume"
    log ""
    log "Next Steps:"
    log "1. Switch to build user: sudo su - $BUILD_USER"
    log "2. Run: ./step3-build-chromium.sh"
    log ""
    log "Note: The next step (source sync + build) will take 2-4 hours and use ~100GB disk space."
}

# Check if running as root on Linux platforms
if [[ $EUID -eq 0 ]] && [[ "$1" != "--allow-root" ]]; then
    log "This script should not be run as root. Run as ubuntu user instead."
    log "If you must run as root, use: $0 --allow-root"
    exit 1
fi

main "$@"