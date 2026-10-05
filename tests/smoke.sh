#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
binary="$ROOT/.build/LockedDisplayKeeper"
for script in "$ROOT/install.sh" "$ROOT/manage.sh" "$ROOT"/scripts/*.sh "$0"; do
  /bin/bash -n "$script"
done
[[ "$("$binary" --version)" == "LockedDisplayKeeper $(cat "$ROOT/VERSION")" ]]
"$binary" --help >/dev/null
for value in 0 -1 nan inf 86401 text; do
  set +e
  "$binary" --duration "$value" >/dev/null 2>&1
  code=$?
  set -e
  [[ $code -eq 64 ]] || { echo "Expected usage error for duration=$value; got $code" >&2; exit 1; }
done
log=$(mktemp)
trap 'rm -f "$log"' EXIT
"$binary" --duration 0.25 2>"$log"
/usr/bin/grep -q 'started pid=' "$log"
/usr/bin/grep -q 'stopped' "$log"
echo "PASS: shell syntax, CLI validation, version, timed startup and shutdown."
echo "Physical lock-screen behavior requires the manual checks in README."
