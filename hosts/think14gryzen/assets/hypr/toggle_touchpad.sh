#!/usr/bin/env bash
set -euo pipefail

notify() { command -v notify-send >/dev/null 2>&1 && notify-send "Touchpad" "$1"; return 0; }

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/touchpad-locked"

DEVICE=$(hyprctl devices -j | jq -r '.mice[] | select(.name | endswith("-touchpad")) | .name' | head -n1)

if [[ -z "$DEVICE" ]]; then
  notify "No touchpad device found"
  exit 1
fi

if [[ -f "$STATE_FILE" ]]; then
  hyprctl keyword "device[$DEVICE]:enabled" true
  rm -f "$STATE_FILE"
  notify "Enabled"
else
  hyprctl keyword "device[$DEVICE]:enabled" false
  touch "$STATE_FILE"
  notify "Locked"
fi
