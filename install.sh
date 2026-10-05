#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
source_binary=""
if [[ $# -eq 2 && "$1" == --binary ]]; then
  source_binary="$2"
elif [[ $# -ne 0 ]]; then
  echo "Usage: $0 [--binary /path/to/LockedDisplayKeeper]" >&2; exit 64
fi
if [[ "$(uname -s)" != Darwin || "$(id -u)" == 0 ]]; then
  echo "Run as your logged-in macOS user, without sudo." >&2; exit 1
fi
if [[ "$(sw_vers -productVersion | cut -d. -f1)" -lt 13 ]]; then
  echo "macOS 13 or later is required; see README for tested versions." >&2; exit 1
fi
if ! /bin/launchctl print "gui/$(id -u)" >/dev/null 2>&1; then
  echo "An active graphical login session is required." >&2; exit 1
fi
if [[ -z "$source_binary" ]]; then
  if [[ -x "$ROOT/bin/LockedDisplayKeeper" ]]; then
    source_binary="$ROOT/bin/LockedDisplayKeeper"
  else
    "$ROOT/scripts/build.sh"
    source_binary="$ROOT/.build/LockedDisplayKeeper"
  fi
fi
if [[ ! -x "$source_binary" ]]; then
  echo "Executable not found: $source_binary" >&2; exit 1
fi
"$source_binary" --version
app_dir="$HOME/Library/Application Support/LockedDisplayKeeper"
agent_dir="$HOME/Library/LaunchAgents"
label=local.user.locked-display-keeper
plist="$agent_dir/$label.plist"
log_dir="$HOME/Library/Logs"
target="gui/$(id -u)/$label"

# Only replace an installation that points to this helper's known location.
if [[ -e "$plist" ]]; then
  existing=$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$plist" 2>/dev/null || true)
  if [[ "$existing" != "$app_dir/LockedDisplayKeeper" ]]; then
    echo "Refusing to replace an unrelated LaunchAgent: $plist" >&2; exit 1
  fi
fi
mkdir -p "$app_dir" "$agent_dir" "$log_dir"
chmod 700 "$app_dir"
tmp_dir=$(mktemp -d "$app_dir/.install.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT
cp "$source_binary" "$tmp_dir/LockedDisplayKeeper"
chmod 700 "$tmp_dir/LockedDisplayKeeper"
cp "$ROOT/manage.sh" "$tmp_dir/manage.sh"
chmod 700 "$tmp_dir/manage.sh"
tmp_plist="$tmp_dir/agent.plist"
/usr/bin/plutil -create xml1 "$tmp_plist"
/usr/bin/plutil -insert Label -string "$label" "$tmp_plist"
/usr/bin/plutil -insert ProgramArguments -json '[]' "$tmp_plist"
/usr/bin/plutil -insert ProgramArguments.0 -string "$app_dir/LockedDisplayKeeper" "$tmp_plist"
/usr/bin/plutil -insert RunAtLoad -bool YES "$tmp_plist"
/usr/bin/plutil -insert KeepAlive -bool YES "$tmp_plist"
/usr/bin/plutil -insert LimitLoadToSessionType -json '["Aqua"]' "$tmp_plist"
/usr/bin/plutil -insert ProcessType -string Background "$tmp_plist"
/usr/bin/plutil -insert ThrottleInterval -integer 10 "$tmp_plist"
/usr/bin/plutil -insert StandardOutPath -string "$log_dir/LockedDisplayKeeper.log" "$tmp_plist"
/usr/bin/plutil -insert StandardErrorPath -string "$log_dir/LockedDisplayKeeper.log" "$tmp_plist"
/usr/bin/plutil -lint "$tmp_plist" >/dev/null

if /bin/launchctl print "$target" >/dev/null 2>&1; then
  /bin/launchctl bootout "$target"
fi
mv -f "$tmp_dir/LockedDisplayKeeper" "$app_dir/LockedDisplayKeeper"
mv -f "$tmp_dir/manage.sh" "$app_dir/manage.sh"
cp "$ROOT/LICENSE" "$app_dir/LICENSE"
mv -f "$tmp_plist" "$plist"
chmod 600 "$plist"
/bin/launchctl enable "$target"
/bin/launchctl bootstrap "gui/$(id -u)" "$plist"
echo "Installed. The helper will start at login."
echo "Check status: ./manage.sh status"
echo "Stop and disable: ./manage.sh stop"
