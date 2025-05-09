#!/bin/bash
# Custom Chrome-like Chromium build with anti-fingerprinting features
# Author: Jesse Johnson
# Date: 2025-05-08

set -e

# Log function
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Error handling
handle_error() {
  log "ERROR: An error occurred on line $1"
  exit 1
}

trap 'handle_error $LINENO' ERR

# Configuration
CHROME_VERSION="135.0.7049.84"
REPO_DIR="$HOME/ghostium"
PATCH_DIR="$REPO_DIR/patches"
BUILD_DIR="$HOME/ghostium-build"
SRC_DIR="$BUILD_DIR/chromium/src"

# Step 1: Install dependencies
setup_environment() {
  log "=== Setting up build environment ==="
  
  sudo apt-get update
  sudo apt-get install -y git python3 python3-pip lsb-release sudo \
    curl pkg-config ninja-build gcc g++ default-jre \
    libatk1.0-dev libatspi2.0-dev libcairo2-dev \
    libegl1-mesa-dev libgbm-dev libglib2.0-dev libgtk-3-dev \
    libpango1.0-dev libpulse-dev libxcomposite-dev \
    libxdamage-dev libxkbcommon-dev libxrandr-dev \
    mesa-common-dev xvfb libnss3-dev

  # Create directories
  mkdir -p "$BUILD_DIR"
  
  # Configure git
  git config --global user.name "Jesse Johnson"
  git config --global user.email "jesse.johnson@pricespider.com"
  
  log "Environment setup complete"
}

# Step 2: Install depot_tools
install_depot_tools() {
  log "=== Installing depot_tools ==="
  
  if [ ! -d "$BUILD_DIR/depot_tools" ]; then
    cd "$BUILD_DIR"
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
  fi
  
  export PATH="$PATH:$BUILD_DIR/depot_tools"
  echo 'export PATH="$PATH:$BUILD_DIR/depot_tools"' >> ~/.bashrc
  source ~/.bashrc
  
  log "depot_tools installation complete"
}

# Step 3: Fetch Chromium source
fetch_chromium() {
  log "=== Fetching Chromium source code ==="
  
  mkdir -p "$BUILD_DIR/chromium"
  cd "$BUILD_DIR/chromium"
  
  if [ ! -d "$SRC_DIR" ]; then
    fetch --nohooks --no-history chromium
  fi
  
  cd "$SRC_DIR"
  
  # Find the tag for the requested Chrome version
  VERSION_TAG=$(git tag | grep "$CHROME_VERSION" | head -1)
  
  if [ -z "$VERSION_TAG" ]; then
    log "Warning: Specific version tag not found. Using latest stable."
    git checkout -f main
  else
    log "Checking out version: $VERSION_TAG"
    git checkout -f "$VERSION_TAG"
  fi
  
  # Run hooks to download additional dependencies
  gclient sync --with_branch_heads --with_tags
  gclient runhooks
  
  log "Chromium source fetch complete"
}

install_dependencies() {
  log "=== Installing Dependencies ==="
  
  "$SRC_DIR/build/install-build-deps.sh"

  log "Dependencies installed"
}

copy_build_config() {
  log "=== Copying build configuration ==="
  
  mkdir -p "$SRC_DIR/out/Default"
  
  cp "$REPO_DIR/args.gn" "$SRC_DIR/out/Default/args.gn"

  log "Build configuration copied"
}

# Step 6: Apply patches
apply_patches() {
  log "=== Applying fingerprinting protection patches ==="
  
  cd "$SRC_DIR"
  
  # Apply each patch
  for patch_file in "$PATCH_DIR"/*.patch; do
    log "Applying patch: $(basename "$patch_file")"
    git apply --reject --whitespace=fix "$patch_file" || true
    
    # Check for any rejected patches
    if find . -name "*.rej" | grep -q .; then
      log "Warning: Some patches were rejected. You may need to manually apply them."
      find . -name "*.rej"
    fi
  done
  
  log "Patches applied"
}

# Step 7: Build Chromium
build_chromium() {
  log "=== Building custom Chromium ==="
  
  cd "$SRC_DIR"
  
  # Generate build files
  gn gen out/Default
  
  # Get the number of CPU cores for parallel build
  NUM_CORES=$(nproc)
  
  # Build Chrome with ninja
  ninja -C out/Default chrome chrome_sandbox headless_shell -j$NUM_CORES
  
  log "Chromium build completed"
}

# Step 8: Package the build
package_build() {
  log "=== Packaging the build ==="
  
  BUILD_OUTPUT="$BUILD_DIR/ghostium"
  mkdir -p "$BUILD_OUTPUT"
  
  # Create directories
  mkdir -p "$BUILD_OUTPUT/resources"
  
  # Copy required files
  cp -a "$SRC_DIR/out/Default/chrome" "$BUILD_OUTPUT/"
  cp -a "$SRC_DIR/out/Default/chrome_sandbox" "$BUILD_OUTPUT/"
  cp -a "$SRC_DIR/out/Default/headless_shell" "$BUILD_OUTPUT/"
  cp -a "$SRC_DIR/out/Default/"*.so "$BUILD_OUTPUT/" 2>/dev/null || true
  cp -a "$SRC_DIR/out/Default/"*.pak "$BUILD_OUTPUT/"
  cp -a "$SRC_DIR/out/Default/icudtl.dat" "$BUILD_OUTPUT/"
  cp -a "$SRC_DIR/out/Default/v8_context_snapshot.bin" "$BUILD_OUTPUT/" 2>/dev/null || true
  
  # Create launcher script
  cat > "$BUILD_OUTPUT/launch_chrome.sh" << 'EOL'
#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export LD_LIBRARY_PATH="$DIR:$LD_LIBRARY_PATH"
"$DIR/chrome" "$@"
EOL
  chmod +x "$BUILD_OUTPUT/launch_chrome.sh"
  
  # Create headless launcher script
  cat > "$BUILD_OUTPUT/launch_headless.sh" << 'EOL'
#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export LD_LIBRARY_PATH="$DIR:$LD_LIBRARY_PATH"
"$DIR/headless_shell" "$@"
EOL
  chmod +x "$BUILD_OUTPUT/launch_headless.sh"
  
  # Create tar archive
  cd "$BUILD_DIR"
  tar -czf "ghostium_$(date '+%Y%m%d').tar.gz" ghostium

  log "Build packaged successfully to: $BUILD_DIR/ghostium_$(date '+%Y%m%d').tar.gz"
}

# Step 9: Run basic tests
run_tests() {
  log "=== Running basic tests ==="
  
  TEST_OUTPUT="$BUILD_DIR/test_results"
  mkdir -p "$TEST_OUTPUT"
  
  cd "$BUILD_OUTPUT"
  
  # Test headless mode
  log "Testing headless mode with a simple page load"
  ./headless_shell --no-sandbox --disable-gpu --headless --dump-dom "https://www.google.com" > "$TEST_OUTPUT/google_test.html"
  
  if grep -q "Google" "$TEST_OUTPUT/google_test.html"; then
    log "Basic page load test PASSED"
  else
    log "Basic page load test FAILED"
  fi
  
  # Test fingerprinting resistance
  log "Testing fingerprinting resistance"
  cat > "$TEST_OUTPUT/fingerprint_test.js" << 'EOL'
console.log("Testing fingerprinting resistance:");
console.log("UserAgent: " + navigator.userAgent);
console.log("Platform: " + navigator.platform);
console.log("HardwareConcurrency: " + navigator.hardwareConcurrency);
console.log("DeviceMemory: " + navigator.deviceMemory);
console.log("Screen dimensions: " + screen.width + "x" + screen.height);
console.log("Screen color depth: " + screen.colorDepth);
EOL
  
  ./headless_shell --no-sandbox --disable-gpu --headless --js-flags="--expose-gc" \
    --run-all-compositor-stages-before-draw \
    --virtual-time-budget=5000 \
    --run-javascript "$TEST_OUTPUT/fingerprint_test.js" > "$TEST_OUTPUT/fingerprint_results.txt"
  
  log "Fingerprint test results saved to: $TEST_OUTPUT/fingerprint_results.txt"
  
  log "Tests completed"
}

# Step 10: Main function
main() {
  log "=== Starting Ghostium build process ==="
  
  # Check for AWS EC2 environment
  if [ -f /sys/hypervisor/uuid ] && grep -q "ec2" /sys/hypervisor/uuid; then
    log "AWS EC2 environment detected"
  else
    log "Warning: Not running on AWS EC2. Some optimizations may not apply."
  fi
  
  # Print system information
  log "System information:"
  log "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d ':' -f2 | xargs)"
  log "Memory: $(free -h | grep 'Mem:' | awk '{print $2}')"
  log "Disk space: $(df -h / | awk 'NR==2 {print $4}') available"
  
  # Start build process
  time setup_environment
  time install_depot_tools
  time fetch_chromium
  time install_dependencies
  time copy_build_config
  time apply_patches
  time build_chromium
  time package_build
  time run_tests
  
  log "Build process completed successfully!"
  log "Ghostium build is available at: $BUILD_DIR/ghostium_$(date '+%Y%m%d').tar.gz"

  # Print system information
  log "System information:"
  log "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d ':' -f2 | xargs)"
  log "Memory: $(free -h | grep 'Mem:' | awk '{print $2}')"
  log "Disk space: $(df -h / | awk 'NR==2 {print $4}') available"
  
  return 0
}

# Execute main function
main "$@"