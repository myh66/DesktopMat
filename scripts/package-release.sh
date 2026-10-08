#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
CREATE_ZIP=true
for OPTION in "$@"; do
    case "$OPTION" in
        --no-zip) CREATE_ZIP=false ;;
        --zip) CREATE_ZIP=true ;;
        -h|--help)
            echo "Usage: scripts/package-release.sh [--no-zip]"
            echo "Build an ad-hoc-signed Universal Release app, DMG, ZIP, and SHA256SUMS."
            echo "The version comes from Resources/Info.plist. No notarization is performed."
            exit 0
            ;;
        *) echo "Unknown option: $OPTION" >&2; exit 2 ;;
    esac
done

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_ROOT/Resources/Info.plist")"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]]; then
    echo "Resources/Info.plist must contain a safe release version (for example 0.3.0)." >&2
    exit 2
fi

bash "$PROJECT_ROOT/scripts/build-app.sh" release universal
APP_NAME="一席 · Desktop Mat.app"
APP_DIR="$PROJECT_ROOT/build/$APP_NAME"
EXECUTABLE="$APP_DIR/Contents/MacOS/DesktopMat"

verify_app() {
    local APP_PATH="$1"
    local INFO_PATH="$APP_PATH/Contents/Info.plist"
    local BINARY_PATH="$APP_PATH/Contents/MacOS/DesktopMat"
    local APP_VERSION MINIMUM_VERSION BINARY_MINIMUM ARCH
    plutil -lint "$INFO_PATH"
    APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PATH")"
    MINIMUM_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$INFO_PATH")"
    if [[ "$APP_VERSION" != "$VERSION" || ! "$MINIMUM_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ || "${MINIMUM_VERSION%%.*}" -lt 15 ]]; then
        echo "App must match the source version and declare macOS 15 or newer." >&2
        return 1
    fi
    if [[ ! -x "$BINARY_PATH" || ! -s "$APP_PATH/Contents/Resources/DesktopMat.icns" ]]; then
        echo "App executable or generated icon is missing." >&2
        return 1
    fi
    # SwiftPM's native and Swift Build backends use different resource bundle
    # layouts. Bundle.module supports both; validate the actual shipped shader.
    local RESOURCE_BUNDLE="$APP_PATH/Contents/Resources/DesktopMat_DesktopMat.bundle"
    if [[ ! -s "$RESOURCE_BUNDLE/Contents/Resources/Shaders/Rug.metal" && ! -s "$RESOURCE_BUNDLE/Shaders/Rug.metal" ]]; then
        echo "App Metal shader resource is missing." >&2
        return 1
    fi
    if ! cmp -s "$PROJECT_ROOT/LICENSE" "$APP_PATH/Contents/Resources/LICENSE.txt"; then
        echo "App must include the complete project license." >&2
        return 1
    fi
    codesign --verify --strict --deep "$APP_PATH"
    for ARCH in arm64 x86_64; do
        xcrun lipo "$BINARY_PATH" -verify_arch "$ARCH"
        BINARY_MINIMUM="$(xcrun vtool -arch "$ARCH" -show-build "$BINARY_PATH" | awk '$1 == "minos" { print $2 }')"
        if [[ "$BINARY_MINIMUM" != "$MINIMUM_VERSION" ]]; then
            echo "$ARCH binary minimum macOS version ($BINARY_MINIMUM) differs from Info.plist ($MINIMUM_VERSION)." >&2
            return 1
        fi
    done
}
verify_app "$APP_DIR"

OUTPUT_DIR="$PROJECT_ROOT/build/releases/v$VERSION"
ASSET_NAME="DesktopMat-v$VERSION-universal"
mkdir -p "$OUTPUT_DIR"
STAGING_DIR="$(mktemp -d "$OUTPUT_DIR/.package-stage.XXXXXX")"
MOUNT_DIR="$STAGING_DIR/mounted"
DMG_MOUNTED=false
cleanup() {
    if [[ "$DMG_MOUNTED" == true ]]; then
        if hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || hdiutil detach -force "$MOUNT_DIR" >/dev/null 2>&1; then
            DMG_MOUNTED=false
        else
            echo "Could not unmount release verification volume at $MOUNT_DIR." >&2
        fi
    fi
    if [[ "$DMG_MOUNTED" == false ]]; then rm -rf "$STAGING_DIR"; fi
}
trap cleanup EXIT
PAYLOAD_DIR="$STAGING_DIR/payload"
ASSET_DIR="$STAGING_DIR/assets"
mkdir -p "$PAYLOAD_DIR" "$ASSET_DIR"

# Archive only the generated app. Source, caches, logs, and reference videos are
# outside this payload; the DMG contains the app and an Applications shortcut.
ditto --norsrc --noextattr "$APP_DIR" "$PAYLOAD_DIR/$APP_NAME"
ln -s /Applications "$PAYLOAD_DIR/Applications"
verify_app "$PAYLOAD_DIR/$APP_NAME"
hdiutil create -volname "一席 · Desktop Mat v$VERSION" \
    -srcfolder "$PAYLOAD_DIR" -fs HFS+ -format UDZO -nospotlight \
    "$ASSET_DIR/$ASSET_NAME.dmg"
hdiutil verify "$ASSET_DIR/$ASSET_NAME.dmg"
mkdir -p "$MOUNT_DIR"
hdiutil attach -readonly -nobrowse -noautoopen -mountpoint "$MOUNT_DIR" \
    "$ASSET_DIR/$ASSET_NAME.dmg"
DMG_MOUNTED=true
verify_app "$MOUNT_DIR/$APP_NAME"
if [[ ! -L "$MOUNT_DIR/Applications" || "$(readlink "$MOUNT_DIR/Applications")" != "/Applications" ]]; then
    echo "DMG Applications shortcut is missing or incorrect." >&2
    exit 1
fi
hdiutil detach "$MOUNT_DIR"
DMG_MOUNTED=false

CHECKSUM_FILES=("$ASSET_NAME.dmg")
if [[ "$CREATE_ZIP" == true ]]; then
    ditto -c -k --keepParent --norsrc --noextattr \
        "$PAYLOAD_DIR/$APP_NAME" "$ASSET_DIR/$ASSET_NAME.zip"
    EXTRACT_DIR="$STAGING_DIR/extracted"
    mkdir -p "$EXTRACT_DIR"
    ditto -x -k "$ASSET_DIR/$ASSET_NAME.zip" "$EXTRACT_DIR"
    shopt -s nullglob dotglob
    ZIP_ROOT_ITEMS=("$EXTRACT_DIR"/*)
    if [[ ${#ZIP_ROOT_ITEMS[@]} -ne 1 || "${ZIP_ROOT_ITEMS[0]}" != "$EXTRACT_DIR/$APP_NAME" ]]; then
        echo "ZIP must contain only the generated app." >&2
        exit 1
    fi
    verify_app "$EXTRACT_DIR/$APP_NAME"
    CHECKSUM_FILES+=("$ASSET_NAME.zip")
fi
(
    cd "$ASSET_DIR"
    shasum -a 256 "${CHECKSUM_FILES[@]}" > SHA256SUMS
    shasum -a 256 -c SHA256SUMS
)

for FILE_NAME in "${CHECKSUM_FILES[@]}" SHA256SUMS; do
    mv -f "$ASSET_DIR/$FILE_NAME" "$OUTPUT_DIR/$FILE_NAME"
done
if [[ "$CREATE_ZIP" != true ]]; then
    rm -f "$OUTPUT_DIR/$ASSET_NAME.zip"
fi

echo "Universal architectures: $(xcrun lipo -archs "$EXECUTABLE")"
echo "Ad-hoc signed app; Developer ID signing and notarization were not performed."
for FILE_NAME in "${CHECKSUM_FILES[@]}" SHA256SUMS; do
    echo "$OUTPUT_DIR/$FILE_NAME"
done
