#!/bin/bash

# Configuration
CHROMIUM_VERSION="137.0.7151.56"
BUILD_DIR="$HOME/chromium-build"
PATCH_DIR="$PWD/patches"
OUT_DIR="$PWD/out"

# Fetch Chromium source
mkdir -p "$ATTACHED_EFS_DIR/chromium"
cd "$ATTACHED_EFS_DIR/chromium"
if [ ! -d "$ATTACHED_EFS_DIR/chromium/src" ]; then
  fetch --nohooks --no-history chromium
fi
cd src
VERSION_TAG=$(git tag | grep "$CHROMIUM_VERSION" | head -1)
if [ -z "$VERSION_TAG" ]; then
  echo "Warning: Specific version tag not found. Using latest stable."
  git checkout -f main
else
  echo "Checking out version: $VERSION_TAG"
  git checkout -f "$VERSION_TAG"
fi
gclient sync --with_branch_heads --with_tags
gclient runhooks

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

# Package for distribution
mkdir -p $OUT_DIR
cp -r out/Release/* $OUT_DIR/
cp -r out/Release/locales* $OUT_DIR/
cp -r out/Release/resources* $OUT_DIR/

echo "Build complete. Output available in $OUT_DIR"