#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
CONFIGURATION="${1:-release}"
ARCHITECTURE="${2:-native}"
if [[ $# -gt 2 || ( "$CONFIGURATION" != "release" && "$CONFIGURATION" != "debug" ) || ( "$ARCHITECTURE" != "native" && "$ARCHITECTURE" != "universal" ) ]]; then
    echo "Usage: scripts/build-app.sh [release|debug] [native|universal]" >&2
    exit 2
fi

# Keep all build caches within the project. No external tools or packages required.
SCRATCH_DIR="$PROJECT_ROOT/.build"
if [[ "$ARCHITECTURE" == "universal" ]]; then
    SCRATCH_DIR="$PROJECT_ROOT/.build/universal"
fi
export CLANG_MODULE_CACHE_PATH="$SCRATCH_DIR/ModuleCache"
export SWIFT_MODULECACHE_PATH="$SCRATCH_DIR/ModuleCache"
BUILD_OPTIONS=(-c "$CONFIGURATION" --scratch-path "$SCRATCH_DIR" --disable-sandbox)
if [[ "$ARCHITECTURE" == "universal" ]]; then
    BUILD_OPTIONS+=(--arch arm64 --arch x86_64)
fi
swift build "${BUILD_OPTIONS[@]}"
BIN_DIR="$(swift build "${BUILD_OPTIONS[@]}" --show-bin-path)"
OUTPUT_DIR="$PROJECT_ROOT/build"
APP_DIR="$OUTPUT_DIR/一席 · Desktop Mat.app"
STAGING_DIR="$(mktemp -d "$OUTPUT_DIR-staging.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
STAGED_APP="$STAGING_DIR/一席 · Desktop Mat.app"
mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources" "$OUTPUT_DIR"
cp "$BIN_DIR/DesktopMat" "$STAGED_APP/Contents/MacOS/DesktopMat"
cp "$PROJECT_ROOT/Resources/Info.plist" "$STAGED_APP/Contents/Info.plist"
cp "$PROJECT_ROOT/LICENSE" "$STAGED_APP/Contents/Resources/LICENSE.txt"
xcrun swift -module-cache-path "$SCRATCH_DIR/icon-module-cache" "$PROJECT_ROOT/scripts/generate-icon.swift" "$STAGING_DIR/DesktopMat.iconset" "$STAGED_APP/Contents/Resources/DesktopMat.icns"
shopt -s nullglob
for RESOURCE_BUNDLE in "$BIN_DIR"/*.bundle; do
    cp -R "$RESOURCE_BUNDLE" "$STAGED_APP/Contents/Resources/"
done
plutil -lint "$STAGED_APP/Contents/Info.plist"
codesign --force --sign - "$STAGED_APP"
codesign --verify --strict --deep "$STAGED_APP"
if [[ "$ARCHITECTURE" == "universal" ]]; then
    for ARCH in arm64 x86_64; do
        xcrun lipo "$STAGED_APP/Contents/MacOS/DesktopMat" -verify_arch "$ARCH"
    done
else
    xcrun lipo "$STAGED_APP/Contents/MacOS/DesktopMat" -verify_arch "$(uname -m)"
fi
if [[ -e "$APP_DIR" ]]; then
    rm -rf "$APP_DIR"
fi
mv "$STAGED_APP" "$APP_DIR"
echo "$APP_DIR"
