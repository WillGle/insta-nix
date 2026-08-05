#!/usr/bin/env bash
set -euo pipefail

# --- PATH & ENV for NixOS/Hyprland when running from keybind ---
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:${PATH:-}"
: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send "Rotate" "$1" || true
}

usage() {
  echo "usage: rotate_select.sh [--all] [--set 0|1|2|3]" >&2
}

# --- Args ---
#   rotate_select.sh                -> cycle 0→90→270 for focused / under-cursor monitor
#   rotate_select.sh --set 0|1|2|3  -> force specific transform for selected monitor
#   rotate_select.sh --all          -> cycle for all active monitors
#   rotate_select.sh --all --set N  -> force transform N for all
SET_MODE=""
ALL=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --set)
      if [ "$#" -lt 2 ]; then
        usage
        exit 2
      fi
      SET_MODE="$2"
      shift 2
      ;;
    --all)
      ALL=1
      shift
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done
if [ -n "$SET_MODE" ] && ! [[ "$SET_MODE" =~ ^[0-3]$ ]]; then
  notify "Invalid transform: $SET_MODE"
  exit 2
fi

# --- Check required binaries ---
command -v hyprctl >/dev/null 2>&1 || { echo "hyprctl not found" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { notify "Missing jq"; echo "jq is required" >&2; exit 1; }

if ! json_monitors="$(hyprctl monitors -j)"; then
  notify "Unable to read monitors"
  exit 1
fi
if ! jq -e 'type == "array"' >/dev/null <<< "$json_monitors"; then
  notify "Hyprland returned invalid monitor data"
  exit 1
fi

pick_names() {
  local cursor_json focused

  if [ "$ALL" -eq 1 ]; then
    jq -r '.[] | select(.disabled == false) | .name' <<< "$json_monitors"
    return
  fi

  # Prefer the focused monitor.
  focused="$(jq -r 'first(.[] | select(.focused == true and .disabled == false) | .name) // empty' <<< "$json_monitors")"
  if [ -n "$focused" ]; then
    printf '%s\n' "$focused"
    return
  fi

  # Fallback: monitor under cursor, using JSON so negative coordinates and commas are safe.
  if cursor_json="$(hyprctl cursorpos -j 2>/dev/null)" \
    && jq -e '.x | type == "number"' >/dev/null <<< "$cursor_json" \
    && jq -e '.y | type == "number"' >/dev/null <<< "$cursor_json"; then
    jq -r --argjson cursor "$cursor_json" '
      first(
        .[]
        | select(.disabled == false)
        | select(
            $cursor.x >= .x and $cursor.x < (.x + (.width / .scale))
            and $cursor.y >= .y and $cursor.y < (.y + (.height / .scale))
          )
        | .name
      ) // empty
    ' <<< "$json_monitors"
    return
  fi

  # Last resort: first active monitor.
  jq -r 'first(.[] | select(.disabled == false) | .name) // empty' <<< "$json_monitors"
}

refresh_wallpaper() {
  local monitor="$1"
  local active wallpaper

  if pgrep -x swww-daemon >/dev/null 2>&1 && command -v swww >/dev/null 2>&1; then
    swww redraw || true
  elif pgrep -x hyprpaper >/dev/null 2>&1 \
    && active="$(hyprctl hyprpaper listactive 2>/dev/null)" \
    && wallpaper="$(awk -v prefix="$monitor = " '
      index($0, prefix) == 1 { print substr($0, length(prefix) + 1); found = 1 }
      END { if (!found) exit 1 }
    ' <<< "$active")"; then
    hyprctl hyprpaper wallpaper "$monitor,$wallpaper" >/dev/null 2>&1 || true
  fi
}

rotate_one() {
  local monitor="$1"
  local info fields width height x y scale current next mode

  if ! info="$(jq -ce --arg monitor "$monitor" 'first(.[] | select(.name == $monitor))' <<< "$json_monitors")"; then
    notify "Monitor $monitor not found"
    return 1
  fi

  fields="$(jq -r '[.width, .height, .x, .y, .scale, .transform] | @tsv' <<< "$info")"
  IFS=$'\t' read -r width height x y scale current <<< "$fields"
  if ! [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]] \
    || ! [[ "$x" =~ ^-?[0-9]+$ && "$y" =~ ^-?[0-9]+$ ]]; then
    notify "Invalid geometry for $monitor"
    return 1
  fi

  if [ -n "$SET_MODE" ]; then
    next="$SET_MODE"
  else
    case "$current" in
      0) next=1 ;;
      1) next=3 ;;
      3) next=0 ;;
      *) next=0 ;;
    esac
  fi

  # Hyprland may report width/height swapped while a monitor is rotated.
  if ! mode="$(jq -er '
    .width as $width
    | .height as $height
    | .transform as $transform
    | (.refreshRate | round) as $refresh
    | first(
        .availableModes[]?
        | capture("^(?<width>[0-9]+)x(?<height>[0-9]+)@(?<rate>[0-9.]+)Hz$")
        | select((.rate | tonumber | round) == $refresh)
          | select(
            ((.width | tonumber) == $width and (.height | tonumber) == $height)
            or (
              ($transform == 1 or $transform == 3)
              and ((.width | tonumber) == $height and (.height | tonumber) == $width)
            )
          )
        | "\(.width)x\(.height)@\(.rate)"
      )
  ' <<< "$info")"; then
    notify "No current mode found for $monitor"
    return 1
  fi

  if ! hyprctl keyword monitor "$monitor,$mode,${x}x${y},$scale,transform,$next"; then
    notify "Failed to rotate $monitor"
    return 1
  fi

  # Refresh wallpaper without taking ownership of its process lifecycle.
  refresh_wallpaper "$monitor"
  notify "$monitor → transform=$next"
}

if [ "$ALL" -eq 1 ]; then
  status=0
  while IFS= read -r name; do
    if [ -n "$name" ] && ! rotate_one "$name"; then
      status=1
    fi
  done < <(pick_names)
  exit "$status"
else
  target="$(pick_names)"
  if [ -z "$target" ]; then
    notify "No monitor found"
    exit 1
  fi
  rotate_one "$target"
fi
