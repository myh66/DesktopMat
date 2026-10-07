#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
# Compatibility entry point: the current app verifies interactive cloth.
exec bash "$PROJECT_ROOT/scripts/verify-cloth.sh"
