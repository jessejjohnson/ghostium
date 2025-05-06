#!/bin/bash
set -e

echo "=== Starting Deployment ==="

bash ./bootstrap.sh
bash ./apply_patches.sh
bash ./build_chromium.sh

echo "=== Deployment Finished ==="
echo "Binary is located at: ~/chromium/src/out/Default/chrome"