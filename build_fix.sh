#!/bin/bash
# Script to fix Android build issues (Windows/Linux path conflicts in WSL)
# Usage: ./build_fix.sh [--clean] [--build]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$SCRIPT_DIR/android"

# Linux SDK paths
LINUX_SDK="/home/plum_-/android-sdk"
LINUX_FLUTTER="/home/plum_-/snap/flutter/common/flutter"
LINUX_CMAKE="$LINUX_SDK/cmake/3.22.1"

echo "=== AIscan Build Fix Script ==="
echo ""

# Function to fix local.properties
fix_local_properties() {
    echo "[1/4] Fixing android/local.properties..."
    cat > "$ANDROID_DIR/local.properties" << EOF
sdk.dir=$LINUX_SDK
flutter.sdk=$LINUX_FLUTTER
flutter.buildMode=debug
flutter.versionName=1.0.0
flutter.versionCode=1
EOF
    echo "      Done."
}

# Function to ensure cmake.dir in gradle.properties
fix_gradle_properties() {
    echo "[2/4] Checking android/gradle.properties..."
    if ! grep -q "cmake.dir=" "$ANDROID_DIR/gradle.properties" 2>/dev/null; then
        echo "cmake.dir=$LINUX_CMAKE" >> "$ANDROID_DIR/gradle.properties"
        echo "      Added cmake.dir to gradle.properties"
    else
        echo "      cmake.dir already configured."
    fi
}

# Function to clean CMake caches
clean_cmake_caches() {
    echo "[3/4] Cleaning CMake caches..."

    # Clean aes_encrypt_file CMake cache
    rm -rf /home/plum_-/.pub-cache/hosted/pub.dev/aes_encrypt_file-*/android/.cxx 2>/dev/null || true

    # Clean project gradle cache
    rm -rf "$ANDROID_DIR/.gradle" 2>/dev/null || true

    # Clean build directory
    rm -rf "$SCRIPT_DIR/build" 2>/dev/null || true

    echo "      Done."
}

# Function to clean deep caches (use with --clean flag)
clean_deep_caches() {
    echo "[DEEP CLEAN] Cleaning Gradle global caches..."
    rm -rf ~/.gradle/caches/transforms-* 2>/dev/null || true
    echo "      Done."
}

# Function to build APK
build_apk() {
    echo "[4/4] Building debug APK..."
    echo ""

    # Export correct environment
    export ANDROID_HOME="$LINUX_SDK"
    export ANDROID_SDK_ROOT="$LINUX_SDK"
    export PATH="$LINUX_FLUTTER/bin:$LINUX_SDK/cmdline-tools/latest/bin:$LINUX_SDK/platform-tools:$PATH"

    cd "$ANDROID_DIR"
    ./gradlew assembleDebug

    echo ""
    echo "=== BUILD COMPLETE ==="
    echo "APK location: $SCRIPT_DIR/build/app/outputs/apk/debug/app-debug.apk"
}

# Parse arguments
DO_CLEAN=false
DO_BUILD=false

for arg in "$@"; do
    case $arg in
        --clean)
            DO_CLEAN=true
            ;;
        --build)
            DO_BUILD=true
            ;;
        --help|-h)
            echo "Usage: ./build_fix.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --clean    Deep clean Gradle caches (use if build still fails)"
            echo "  --build    Run the build after fixing paths"
            echo "  --help     Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./build_fix.sh              # Fix paths only"
            echo "  ./build_fix.sh --build      # Fix paths and build"
            echo "  ./build_fix.sh --clean --build  # Deep clean, fix paths, and build"
            exit 0
            ;;
    esac
done

# Run fixes
if [ "$DO_CLEAN" = true ]; then
    clean_deep_caches
fi

fix_local_properties
fix_gradle_properties
clean_cmake_caches

if [ "$DO_BUILD" = true ]; then
    build_apk
else
    echo ""
    echo "=== PATHS FIXED ==="
    echo "Run './build_fix.sh --build' to build the APK"
    echo "Or run manually: cd android && ANDROID_HOME=$LINUX_SDK ./gradlew assembleDebug"
fi
