#!/bin/bash
set -e

PATCH_DIR="$(dirname "$0")/patches"

cd ~/chromium/src

echo "Applying patches..."

# Apply each patch file
for patch in "$PATCH_DIR"/*.patch; do
    echo "Applying $patch"
    git apply "$patch"
done

echo "All patches applied."