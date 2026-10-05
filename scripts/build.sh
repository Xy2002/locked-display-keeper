#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != Darwin ]]; then
  echo "Build requires macOS." >&2; exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Install Apple Command Line Tools first: xcode-select --install" >&2; exit 1
fi
mode="${1:-native}"
case "$mode" in native|universal) ;; *) echo "Usage: $0 [native|universal]" >&2; exit 64;; esac
mkdir -p "$ROOT/.build/module-cache"
build_arch() {
  xcrun swiftc -swift-version 5 -O \
    -target "$1-apple-macosx13.0" \
    -module-cache-path "$ROOT/.build/module-cache" \
    -framework Foundation -framework CoreGraphics -framework IOKit \
    "$ROOT/src/main.swift" -o "$2"
}
if [[ "$mode" == universal ]]; then
  build_arch arm64 "$ROOT/.build/LockedDisplayKeeper-arm64"
  build_arch x86_64 "$ROOT/.build/LockedDisplayKeeper-x86_64"
  xcrun lipo -create "$ROOT/.build/LockedDisplayKeeper-arm64" \
    "$ROOT/.build/LockedDisplayKeeper-x86_64" -output "$ROOT/.build/LockedDisplayKeeper"
else
  build_arch "$(uname -m)" "$ROOT/.build/LockedDisplayKeeper"
fi
/usr/bin/codesign --force --sign - "$ROOT/.build/LockedDisplayKeeper"
echo "Built $ROOT/.build/LockedDisplayKeeper"
