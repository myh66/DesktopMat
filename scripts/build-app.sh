#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/ModuleCache"
export SWIFT_MODULECACHE_PATH="$PROJECT_ROOT/.build/ModuleCache"
CONFIGURATION="${1:-release}"
if [[ "$CONFIGURATION" != "release" && "$CONFIGURATION" != "debug" ]]; then
    echo "Usage: scripts/build-app.sh [release|debug]" >&2
    exit 2
fi

# Keep all build caches within the project. No external tools or packages required.
swift build -c "$CONFIGURATION" --scratch-path "$PROJECT_ROOT/.build" --disable-sandbox
BIN_DIR="$(swift build -c "$CONFIGURATION" --scratch-path "$PROJECT_ROOT/.build" --show-bin-path)"
OUTPUT_DIR="$PROJECT_ROOT/build"
APP_DIR="$OUTPUT_DIR/一席 · Desktop Mat.app"
STAGING_DIR="$(mktemp -d "$OUTPUT_DIR-staging.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
STAGED_APP="$STAGING_DIR/一席 · Desktop Mat.app"
mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources" "$OUTPUT_DIR"
cp "$BIN_DIR/DesktopMat" "$STAGED_APP/Contents/MacOS/DesktopMat"
cp "$PROJECT_ROOT/Resources/Info.plist" "$STAGED_APP/Contents/Info.plist"
xcrun swift -module-cache-path "$PROJECT_ROOT/.build/icon-module-cache" "$PROJECT_ROOT/scripts/generate-icon.swift" "$STAGING_DIR/DesktopMat.iconset" "$STAGED_APP/Contents/Resources/DesktopMat.icns"
shopt -s nullglob
for RESOURCE_BUNDLE in "$BIN_DIR"/*.bundle; do
    cp -R "$RESOURCE_BUNDLE" "$STAGED_APP/Contents/Resources/"
done
plutil -lint "$STAGED_APP/Contents/Info.plist"
codesign --force --sign - "$STAGED_APP"
codesign --verify --strict "$STAGED_APP"
if [[ -e "$APP_DIR" ]]; then
    rm -rf "$APP_DIR"
fi
mv "$STAGED_APP" "$APP_DIR"
echo "$APP_DIR"
