#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
version=$(cat "$ROOT/VERSION")
"$ROOT/scripts/build.sh" universal
stage=$(mktemp -d "$ROOT/.build/package.XXXXXX")
trap 'rm -rf "$stage"' EXIT
name="locked-display-keeper-$version-macos-universal"
mkdir -p "$stage/$name/bin" "$ROOT/dist"
cp "$ROOT/.build/LockedDisplayKeeper" "$stage/$name/bin/"
cp "$ROOT/install.sh" "$ROOT/manage.sh" "$ROOT/README.md" "$ROOT/LICENSE" "$ROOT/VERSION" "$stage/$name/"
/usr/bin/ditto -c -k --keepParent "$stage/$name" "$ROOT/dist/$name.zip"
(cd "$ROOT/dist" && /usr/bin/shasum -a 256 "$name.zip" > "$name.zip.sha256")
echo "Packaged $ROOT/dist/$name.zip"
