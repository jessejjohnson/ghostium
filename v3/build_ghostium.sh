#!/bin/bash

# Configuration
CHROMIUM_VERSION="137.0.7151.56"
ATTACHED_EFS_DIR="~/chromium-build"
PATCH_DIR="${PWD}/patches"
OUT_DIR="${PWD}/out"

# Fetch Chromium source
mkdir -p "${ATTACHED_EFS_DIR}/chromium" && cd "${ATTACHED_EFS_DIR}/chromium"
fetch --nohooks --no-history chromium
cd src
git checkout tags/$CHROMIUM_VERSION
gclient sync --with_branch_heads

# Apply Ghostium patches
for patch in $PATCH_DIR/*.patch; do
  git apply $patch
done

# Run hooks
gclient runhooks

# Configure build
gn gen out/Release --args="is_debug=false is_official_build=true symbol_level=0 enable_nacl=false blink_symbol_level=0 use_sysroot=true proprietary_codecs=true ffmpeg_branding=\"Chrome\" enable_widevine=true"

# Build Chromium
autoninja -C out/Release chrome

# Package binary
mkdir -p $OUT_DIR
cp out/Ghostium/chrome ~/ghostium-dist/ghostium
cp -r out/Ghostium/locales ~/ghostium-dist/
cp -r out/Ghostium/resources ~/ghostium-dist/

# Package for distribution
mkdir -p $OUT_DIR
cp -r out/Release/* $OUT_DIR/
cp -r out/Release/locales* $OUT_DIR/
cp -r out/Release/resources* $OUT_DIR/

echo "Build complete. Output available in $OUT_DIR"