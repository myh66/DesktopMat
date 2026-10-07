#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/ModuleCache"
export SWIFT_MODULECACHE_PATH="$PROJECT_ROOT/.build/ModuleCache"
swift test -c release --scratch-path "$PROJECT_ROOT/.build" --disable-sandbox
bash "$PROJECT_ROOT/scripts/build-app.sh" release
APP_EXECUTABLE="$PROJECT_ROOT/build/一席 · Desktop Mat.app/Contents/MacOS/DesktopMat"
"$APP_EXECUTABLE" --replace --verify "$PROJECT_ROOT/artifacts"
