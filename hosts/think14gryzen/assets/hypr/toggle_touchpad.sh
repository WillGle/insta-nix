#!/usr/bin/env bash
set -euo pipefail

# Locks every input node belonging to the built-in touchpad.
#
# Two details this has to get right:
#
#  1. The pad exposes TWO libinput nodes from one physical device: a "-touchpad"
#     node carrying absolute touch/gestures, and a "-mouse" node carrying
#     relative motion and the physical BTN_LEFT/RIGHT/MIDDLE. Disabling only the
#     first leaves the pad clickable, which is not a lock.
#  2. `hyprctl keyword` is runtime-only and is wiped by `hyprctl reload`, which
#     theme-apply issues on every wallpaper change. So the state is also written
#     to a config file that hyprland.conf sources; a reload then re-applies it
#     instead of silently unlocking.

notify() { command -v notify-send >/dev/null 2>&1 && notify-send "Touchpad" "$1"; return 0; }
notify_error() {
  command -v notify-send >/dev/null 2>&1 && notify-send -u critical "Touchpad" "$1"
  return 0
}

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
STATE_FILE="$STATE_DIR/touchpad.conf"
LOCK_FILE="$RUNTIME_DIR/touchpad-toggle.lock"

RESET=0
case "${1:-}" in
  --reset) RESET=1 ;;
  "") ;;
  *)
    printf 'usage: %s [--reset]\n' "${0##*/}" >&2
    exit 2
    ;;
esac

if [ ! -d "$RUNTIME_DIR" ] || [ ! -w "$RUNTIME_DIR" ]; then
  notify_error "Runtime directory is unavailable"
  exit 1
fi
if ! command -v flock >/dev/null 2>&1; then
  notify_error "Missing flock"
  exit 1
fi

mkdir -p "$STATE_DIR"

if ! exec 9>"$LOCK_FILE"; then
  notify_error "Unable to open touchpad lock"
  exit 1
fi
if ! flock -w 10 9; then
  notify_error "Unable to acquire touchpad lock"
  exit 1
fi

if ! devices_json="$(hyprctl devices -j)"; then
  notify_error "Unable to read input devices"
  exit 1
fi

if ! touchpad="$(jq -er 'first(.mice[]? | select(.name | endswith("-touchpad")) | .name) // empty' <<< "$devices_json")"; then
  touchpad=""
fi
if [ -z "$touchpad" ]; then
  notify_error "No touchpad device found"
  exit 1
fi

# Every node sharing the touchpad's device prefix, so the companion "-mouse"
# node is locked alongside it.
mapfile -t DEVICES < <(
  jq -r --arg prefix "${touchpad%-touchpad}-" \
    '.mice[]? | select(.name | startswith($prefix)) | .name' <<< "$devices_json"
)
if [ "${#DEVICES[@]}" -eq 0 ]; then
  notify_error "No touchpad nodes resolved"
  exit 1
fi

apply_enabled() {
  local value="$1" device
  for device in "${DEVICES[@]}"; do
    hyprctl keyword "device[$device]:enabled" "$value" >/dev/null || return 1
  done
}

write_state() {
  local enabled="$1" tmp device
  tmp="$(mktemp "$STATE_FILE.XXXXXX")"
  {
    printf '# Written by toggle_touchpad.sh; sourced from hyprland.conf so the\n'
    printf '# lock survives a hyprctl reload. Reset at every session start.\n'
    if [ "$enabled" = "false" ]; then
      for device in "${DEVICES[@]}"; do
        printf 'device {\n  name = %s\n  enabled = false\n}\n' "$device"
      done
    fi
  } > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

if [ "$RESET" -eq 1 ]; then
  apply_enabled true || true
  write_state true
  exit 0
fi

locked=0
if [ -f "$STATE_FILE" ] && grep -q '^  enabled = false$' "$STATE_FILE"; then
  locked=1
fi

if [ "$locked" -eq 1 ]; then
  if ! apply_enabled true; then
    notify_error "Failed to enable touchpad"
    exit 1
  fi
  write_state true
  notify "Enabled"
else
  if ! apply_enabled false; then
    notify_error "Failed to lock touchpad"
    exit 1
  fi
  write_state false
  notify "Locked (${#DEVICES[@]} nodes)"
fi
