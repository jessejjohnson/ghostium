#!/bin/bash
set -e

cd ~/chromium/src

# Configure
gn gen out/Default --args='
is_debug=false
symbol_level=0
use_jumbo_build=true
enable_nacl=false
is_official_build=true
chrome_pgo_phase=0
ffmpeg_branding="Chrome"
proprietary_codecs=true
target_cpu="x64"
'

# Build
ninja -C out/Default chrome

echo "Chromium build complete!"