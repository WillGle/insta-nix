#!/usr/bin/env bash
set -euo pipefail

notify() { command -v notify-send >/dev/null 2>&1 && notify-send "Touchpad" "$1"; return 0; }

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
STATE_FILE="$RUNTIME_DIR/touchpad-locked"
LOCK_FILE="$STATE_FILE.lock"

if [ ! -d "$RUNTIME_DIR" ] || [ ! -w "$RUNTIME_DIR" ]; then
  notify "Runtime directory is unavailable"
  exit 1
fi
if ! command -v flock >/dev/null 2>&1; then
  notify "Missing flock"
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

SESSION_ID="${HYPRLAND_INSTANCE_SIGNATURE:-}"
if [ -z "$SESSION_ID" ]; then
  if ! SESSION_ID="$(hyprctl instances -j | jq -er 'if length == 1 then .[0].instance else empty end')"; then
    notify "Unable to identify the Hyprland session"
    exit 1
  fi
fi

if ! exec 9>"$LOCK_FILE"; then
  notify "Unable to open touchpad lock"
  exit 1
fi
if ! flock 9; then
  notify "Unable to acquire touchpad lock"
  exit 1
fi

locked=0
if [ -f "$STATE_FILE" ]; then
  IFS= read -r saved_session < "$STATE_FILE" || true
  [ "${saved_session:-}" = "$SESSION_ID" ] && locked=1
fi

if [ "$locked" -eq 1 ]; then
  if ! hyprctl keyword "device[$DEVICE]:enabled" true; then
    notify "Failed to enable touchpad"
    exit 1
  fi
  rm -f "$STATE_FILE"
  notify "Enabled"
else
  if ! hyprctl keyword "device[$DEVICE]:enabled" false; then
    notify "Failed to lock touchpad"
    exit 1
  fi
  printf '%s\n' "$SESSION_ID" > "$STATE_FILE"
  notify "Locked"
fi
