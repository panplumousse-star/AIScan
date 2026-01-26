#!/bin/bash
# Build release AAB with obfuscation for Google Play Store
# Usage: ./build_release.sh

set -e

echo "Building release AAB with obfuscation..."

flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/debug-info

echo ""
echo "Build complete!"
echo "AAB: build/app/outputs/bundle/release/app-release.aab"
echo "Debug symbols: build/debug-info/"
echo ""
echo "IMPORTANT: Keep build/debug-info/ for crash symbolication!"
