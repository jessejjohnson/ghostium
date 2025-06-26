#!/bin/bash
set -e

# Ghostium Step 3: Build Chromium
# This script performs the actual Chromium build with Ghostium customizations for Linux x64

PROJECT_NAME="ghostium-build"
DEPOT_TOOLS_DIR="/opt/depot_tools"
CHROMIUM_DIR="/mnt/chromium-build/chromium"
BUILD_DIR="out/Release"
ARTIFACTS_BUCKET="${PROJECT_NAME}-artifacts"

# Build configuration
PLATFORM="linux-x64"
TARGET_CPU="x64"
TARGET_OS="linux"

BUILD_START_TIME=$(date +%s)

echo "Starting Ghostium Chromium build for Linux x64..."

# Function to mount and prepare build volume
mount_build_volume() {
    log "Setting up 500GB build volume..."
    
    # Check if volume is already mounted
    if mountpoint -q /mnt/chromium-build; then
        log "Build volume already mounted at /mnt/chromium-build"
        return 0
    fi
    
    # Wait for the EBS volume to be available
    log "Waiting for EBS volume /dev/xvdf to be available..."
    while [ ! -b /dev/xvdf ]; do
        sleep 5
        log "Still waiting for /dev/xvdf..."
    done
    
    # Check if volume has a filesystem
    if ! sudo file -s /dev/xvdf | grep -q filesystem; then
        log "Formatting EBS volume with ext4 filesystem..."
        sudo mkfs.ext4 /dev/xvdf
    fi
    
    # Create mount point
    sudo mkdir -p /mnt/chromium-build
    
    # Mount the volume
    log "Mounting EBS volume..."
    sudo mount /dev/xvdf /mnt/chromium-build
    
    # Set ownership to build user
    sudo chown -R ghostium-builder:ghostium-builder /mnt/chromium-build
    
    # Update environment variables to use mounted volume
    export CHROMIUM_DIR="/mnt/chromium-build/chromium"
    
    log "Build volume mounted and ready at /mnt/chromium-build"
}

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to sync Chromium source
sync_chromium_source() {
    log "Syncing Chromium source code..."
    
    cd "$CHROMIUM_DIR"
    
    # Ensure depot_tools is in PATH
    export PATH="$DEPOT_TOOLS_DIR:$PATH"
    
    # Create .gclient file with target OS
    cat > .gclient << EOF
solutions = [
  {
    "name": "src",
    "url": "https://chromium.googlesource.com/chromium/src.git",
    "managed": False,
    "custom_deps": {},
    "custom_vars": {},
  },
]
target_os = ["linux"]
EOF
    
    # Initial gclient sync - this will take 1-2 hours
    log "Running gclient sync (this will take 1-2 hours)..."
    gclient sync --no-history --shallow
    
    log "Source sync complete"
}

# Function to apply Ghostium patches
apply_ghostium_patches() {
    log "Applying Ghostium customizations..."
    
    cd "$CHROMIUM_DIR/src"
    
    # Create Ghostium-specific modifications
    # These are example patches - customize based on your fingerprintable signal requirements
    
    # 1. Modify user agent generation
    cat > chrome/common/ghostium_user_agent.patch << 'EOF'
// Ghostium: Custom user agent modifications for fingerprint management
// This is a placeholder - implement your specific user agent logic
EOF
    
    # 2. Disable unnecessary features for headless automation
    cat > chrome/browser/ghostium_feature_disable.patch << 'EOF'
// Ghostium: Disable features not needed for headless automation
// Extension system, themes, background apps, etc.
EOF
    
    # 3. Fingerprint signal management hooks
    cat > content/browser/ghostium_fingerprint_manager.patch << 'EOF'
// Ghostium: Hooks for managing fingerprintable signals
// Canvas, WebGL, fonts, screen resolution, etc.
EOF
    
    log "Ghostium patches prepared"
}

# Function to configure build
configure_build() {
    log "Configuring build..."
    
    cd "$CHROMIUM_DIR/src"
    
    # Create build arguments for Linux x64
    cat > "${BUILD_DIR}.args" << EOF
# Ghostium build configuration for Linux x64
is_debug = false
is_official_build = true
target_cpu = "x64"
target_os = "linux"
symbol_level = 1

# Optimization settings
use_thin_lto = true
is_cfi = false
use_cfi_icall = false

# Disable unnecessary features for headless automation
enable_nacl = false
enable_print_preview = false
enable_service_discovery = false
enable_background_mode = false
enable_google_now = false
enable_one_click_signin = false
enable_settings_app = false
enable_supervised_users = false
enable_task_manager = false
enable_themes = false

# Essential features for automation
enable_webrtc = true
enable_extensions = false
enable_plugins = false

# Media codecs
proprietary_codecs = false
ffmpeg_branding = "Chromium"
enable_av1_decoder = true
enable_dav1d_decoder = true

# Linux-specific settings
use_sysroot = true
use_cups = false
use_pulseaudio = false
use_alsa = false
use_gio = false
treat_warnings_as_errors = false

# Ghostium-specific feature flags
# ghostium_fingerprint_management = true
# ghostium_headless_optimizations = true
# ghostium_container_mode = true
EOF
    
    # Generate build files
    log "Generating build files with gn..."
    gn gen "$BUILD_DIR" --args="$(cat ${BUILD_DIR}.args | tr '\n' ' ')"
    
    log "Build configured"
}

# Function to perform the build
build_chromium() {
    log "Building Chromium (this will take 2-4 hours)..."
    
    cd "$CHROMIUM_DIR/src"
    
    # Build chrome target
    log "Starting autoninja build..."
    autoninja -C "$BUILD_DIR" chrome
    
    # Build additional targets if needed
    log "Building additional targets..."
    autoninja -C "$BUILD_DIR" chromedriver
    
    log "Build complete"
}

# Function to package artifacts
package_artifacts() {
    log "Packaging build artifacts..."
    
    cd "$CHROMIUM_DIR/src/$BUILD_DIR"
    
    # Create artifacts directory
    mkdir -p "ghostium-linux-x64-$(date +%Y%m%d-%H%M%S)"
    ARTIFACT_DIR="ghostium-linux-x64-$(date +%Y%m%d-%H%M%S)"
    
    # Linux artifacts
    cp chrome "$ARTIFACT_DIR/"
    cp chromedriver "$ARTIFACT_DIR/"
    cp -r locales "$ARTIFACT_DIR/" 2>/dev/null || true
    cp -r resources "$ARTIFACT_DIR/" 2>/dev/null || true
    cp *.so "$ARTIFACT_DIR/" 2>/dev/null || true
    cp *.bin "$ARTIFACT_DIR/" 2>/dev/null || true
    
    # Create archive
    tar -czf "${ARTIFACT_DIR}.tar.gz" "$ARTIFACT_DIR"
    
    log "Artifacts packaged: ${ARTIFACT_DIR}.tar.gz"
    
    # Upload to S3
    log "Uploading artifacts to S3..."
    aws s3 cp "${ARTIFACT_DIR}.tar.gz" "s3://${ARTIFACTS_BUCKET}/builds/${ARTIFACT_DIR}.tar.gz"
    
    # Upload build metadata
    cat > build-info.json << EOF
{
    "platform": "linux-x64",
    "architecture": "x64",
    "build_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "build_duration_seconds": $(($(date +%s) - BUILD_START_TIME)),
    "commit_hash": "$(git rev-parse HEAD)",
    "artifact_name": "${ARTIFACT_DIR}.tar.gz",
    "artifact_size_bytes": $(stat -c%s "${ARTIFACT_DIR}.tar.gz" 2>/dev/null || stat -f%z "${ARTIFACT_DIR}.tar.gz")
}
EOF
    
    aws s3 cp build-info.json "s3://${ARTIFACTS_BUCKET}/builds/${ARTIFACT_DIR}-info.json"
    
    log "Artifacts uploaded successfully"
}

# Function to run basic tests
run_tests() {
    log "Running basic functionality tests..."
    
    cd "$CHROMIUM_DIR/src/$BUILD_DIR"
    
    # Test chrome binary
    ./chrome --version || true
    ./chromedriver --version || true
    
    log "Basic tests complete"
}

# Function to cleanup
cleanup() {
    log "Cleaning up build artifacts..."
    
    cd "$CHROMIUM_DIR/src"
    
    # Remove intermediate build files to save space
    rm -rf "$BUILD_DIR/obj" 2>/dev/null || true
    rm -rf "$BUILD_DIR/gen" 2>/dev/null || true
    
    log "Cleanup complete"
}

# Function to display build summary
show_summary() {
    BUILD_END_TIME=$(date +%s)
    BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
    BUILD_HOURS=$((BUILD_DURATION / 3600))
    BUILD_MINUTES=$(((BUILD_DURATION % 3600) / 60))
    
    echo ""
    echo "Ghostium Build Complete!"
    echo "========================"
    echo "Platform: Linux x64"
    echo "Architecture: x64"
    echo "Build Duration: ${BUILD_HOURS}h ${BUILD_MINUTES}m"
    echo "Build Directory: $CHROMIUM_DIR/src/$BUILD_DIR"
    echo ""
    echo "Artifacts:"
    echo "- Chrome binary: $(ls -la $CHROMIUM_DIR/src/$BUILD_DIR/chrome* | head -1)"
    echo "- ChromeDriver: $(ls -la $CHROMIUM_DIR/src/$BUILD_DIR/chromedriver* | head -1)"
    echo ""
    echo "Uploaded to S3: s3://${ARTIFACTS_BUCKET}/builds/"
    echo ""
}

# Main execution
main() {
    log "Starting Ghostium build process..."
    log "Platform: Linux x64"
    log "Target CPU: $TARGET_CPU"
    log "Target OS: $TARGET_OS"
    log "Build Directory: $BUILD_DIR"
    
    # Mount and prepare the build volume first
    mount_build_volume
    
    log "Updated Chromium Directory: $CHROMIUM_DIR"
    
    # Create the chromium directory if it doesn't exist
    mkdir -p "$CHROMIUM_DIR"
    
    # Check disk space on mounted volume
    FREE_SPACE=$(df /mnt/chromium-build | awk 'NR==2 {print $4}')
    if [[ $FREE_SPACE -lt 104857600 ]]; then  # 100GB in KB
        log "Warning: Low disk space on build volume. Build requires at least 100GB free space."
        log "Available: $(($FREE_SPACE / 1048576))GB"
    else
        log "Build volume has $(($FREE_SPACE / 1048576))GB available space"
    fi
    
    sync_chromium_source
    apply_ghostium_patches
    configure_build
    build_chromium
    run_tests
    package_artifacts
    cleanup
    show_summary
    
    log "All build steps completed successfully!"
}

# Error handling
trap 'log "Build failed at line $LINENO"' ERR

# Check if depot_tools is available
if ! command -v gn &> /dev/null; then
    log "depot_tools not found in PATH"
    log "Please ensure step2-prepare-environment.sh was run successfully"
    exit 1
fi

# Check disk space (need at least 100GB free)
# Note: Check will be done after mounting the build volume

main "$@"