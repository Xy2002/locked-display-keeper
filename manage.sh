#!/bin/bash
set -euo pipefail
if [[ "$(uname -s)" != Darwin || "$(id -u)" == 0 ]]; then
  echo "Run as your logged-in macOS user, without sudo." >&2; exit 1
fi
label=local.user.locked-display-keeper
target="gui/$(id -u)/$label"
app_dir="$HOME/Library/Application Support/LockedDisplayKeeper"
plist="$HOME/Library/LaunchAgents/$label.plist"
log="$HOME/Library/Logs/LockedDisplayKeeper.log"
loaded() { /bin/launchctl print "$target" >/dev/null 2>&1; }
case "${1:-status}" in
  status)
    if loaded; then
      /bin/launchctl print "$target" | /usr/bin/awk '/^[[:space:]]*(state =|pid =|last exit code =)/ { print }'
    else
      echo "Service not loaded."
    fi
    if [[ -e "$plist" ]]; then echo "Installed: $plist"; else echo "Not installed."; fi
    /usr/bin/pmset -g assertions | /usr/bin/awk '/LockedDisplayKeeper|Keep display on while screen is locked/ { print }'
    ;;
  stop)
    /bin/launchctl disable "$target"
    if loaded; then /bin/launchctl bootout "$target"; fi
    echo "Stopped and disabled, including future logins. Use start to enable again."
    ;;
  start)
    if [[ ! -f "$plist" ]]; then echo "Not installed. Run install.sh first." >&2; exit 1; fi
    /bin/launchctl enable "$target"
    if ! loaded; then /bin/launchctl bootstrap "gui/$(id -u)" "$plist"; fi
    echo "Enabled."
    ;;
  logs)
    if [[ -f "$log" ]]; then tail -n 50 "$log"; else echo "No log yet."; fi
    ;;
  uninstall)
    if [[ -e "$plist" ]]; then
      existing=$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$plist" 2>/dev/null || true)
      if [[ "$existing" != "$app_dir/LockedDisplayKeeper" ]]; then
        echo "Refusing to remove an unrelated LaunchAgent." >&2; exit 1
      fi
    fi
    /bin/launchctl disable "$target"
    if loaded; then /bin/launchctl bootout "$target"; fi
    rm -f "$plist" "$app_dir/LockedDisplayKeeper" "$app_dir/manage.sh" "$app_dir/LICENSE"
    rmdir "$app_dir" 2>/dev/null || true
    echo "Uninstalled. Log retained at $log"
    ;;
  *) echo "Usage: $0 {status|start|stop|logs|uninstall}" >&2; exit 64 ;;
esac
