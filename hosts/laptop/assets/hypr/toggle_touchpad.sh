#!/usr/bin/env bash
set -euo pipefail

# Touchpad lock. The state lives in a config fragment that hyprland.conf sources
# (__TOUCHPAD_STATE_CONF__), because `hyprctl reload` — which theme-apply issues
# on every wallpaper change — drops runtime keywords and would silently unlock.
# The keyword is still issued alongside the write so the change takes effect
# without waiting for a reload.
#
#   toggle_touchpad.sh           toggle the lock
#   toggle_touchpad.sh --reset   clear the lock (run at login)

notify() { command -v notify-send >/dev/null 2>&1 && notify-send "Touchpad" "$1"; return 0; }

STATE_FILE="@touchpadStateConf@"
LOCK_FILE="$STATE_FILE.lock"

RESET=0
case "${1:-}" in
  --reset) RESET=1 ;;
  "") ;;
  *)
    printf 'usage: toggle_touchpad.sh [--reset]\n' >&2
    exit 2
    ;;
esac

if ! mkdir -p "$(dirname "$STATE_FILE")"; then
  notify "Unable to create the touchpad state directory"
  exit 1
fi

if ! devices_json="$(hyprctl devices -j)"; then
  notify "Unable to read input devices"
  exit 1
fi
if ! DEVICE="$(jq -er 'first(.mice[]? | select(.name | endswith("-touchpad")) | .name) // empty' <<< "$devices_json")"; then
  DEVICE=""
fi
if [ -z "$DEVICE" ]; then
  notify "No touchpad device found"
  exit 1
fi

if ! exec 9>"$LOCK_FILE"; then
  notify "Unable to open touchpad lock"
  exit 1
fi
if ! flock 9; then
  notify "Unable to acquire touchpad lock"
  exit 1
fi

# A lock is recorded as the disabling device block; anything else (empty file,
# missing file) means unlocked.
locked=0
if [ -f "$STATE_FILE" ] && grep -q 'enabled = false' "$STATE_FILE"; then
  locked=1
fi

# Rewrite via a temporary file so a reload racing the write never sources a
# half-written block.
write_state() {
  local body="$1" tmp
  tmp="$(mktemp "$STATE_FILE.XXXXXX")"
  printf '%s' "$body" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

device_block() {
  printf 'device {\n  name = %s\n  enabled = %s\n}\n' "$DEVICE" "$1"
}

if [ "$RESET" -eq 1 ] || [ "$locked" -eq 1 ]; then
  write_state ""
  if ! hyprctl keyword "device[$DEVICE]:enabled" true; then
    notify "Failed to enable touchpad"
    exit 1
  fi
  [ "$RESET" -eq 1 ] || notify "Enabled"
else
  write_state "$(device_block false)"
  if ! hyprctl keyword "device[$DEVICE]:enabled" false; then
    notify "Failed to lock touchpad"
    exit 1
  fi
  notify "Locked"
fi
