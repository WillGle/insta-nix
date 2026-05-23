#!/usr/bin/env bash
set -euo pipefail

# --- PATH & ENV for NixOS/Hyprland when running from keybind ---
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:$PATH"
: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  sig="$(ls -1t /tmp/hypr 2>/dev/null | head -n1 || true)"
  [[ -n "$sig" ]] && export HYPRLAND_INSTANCE_SIGNATURE="$sig"
fi

# --- Args ---
#   rotate_select.sh                -> cycle 0→90→270 for focused / under-cursor monitor
#   rotate_select.sh --set 0|1|2|3  -> force specific transform for selected monitor
#   rotate_select.sh --all          -> cycle for all active monitors
#   rotate_select.sh --all --set N  -> force transform N for all
SET_MODE=""; ALL=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --set) shift; SET_MODE="${1:-}";;
    --all) ALL=1;;
    *) : ;;
  esac
  shift || true
done

# Cycle: 0 (landscape) -> 1 (90) -> 3 (270) -> 0
CYCLE=(0 1 3)

# --- Check required binaries ---
command -v hyprctl >/dev/null 2>&1 || { echo "hyprctl not found"; exit 1; }
command -v jq      >/dev/null 2>&1 || { notify-send "Rotate" "Missing jq"; echo "jq is required"; exit 1; }

json_monitors="$(hyprctl -j monitors)"

pick_names() {
  if [[ "$ALL" -eq 1 ]]; then
    echo "$json_monitors" | jq -r '.[] | select(.disabled==false) | .name'
    return
  fi
  # Prefer the focused monitor
  local name
  name="$(echo "$json_monitors" | jq -r '.[] | select(.focused==true) | .name' || true)"
  if [[ -n "$name" && "$name" != "null" ]]; then
    echo "$name"; return
  fi
  # Fallback: monitor under cursor
  if pos="$(hyprctl cursorpos 2>/dev/null)"; then
    local cx cy
    cx="$(awk '{print $1}' <<<"$pos")"
    cy="$(awk '{print $2}' <<<"$pos")"
    echo "$json_monitors" | jq -r --argjson cx "$cx" --argjson cy "$cy" '
      .[] | select(.disabled==false)
      | select($cx >= .x and $cx < (.x + .width) and $cy >= .y and $cy < (.y + .height))
      | .name' | head -n1
    return
  fi
  # Last resort: first active monitor
  echo "$json_monitors" | jq -r '.[] | select(.disabled==false) | .name' | head -n1
}

rotate_one() {
  local MON="$1"
  local info
  info="$(echo "$json_monitors" | jq --arg m "$MON" -r '.[] | select(.name==$m)')"
  [[ -n "$info" ]] || { notify-send "Rotate" "Monitor $MON not found"; return; }

  local W H RR X Y SCALE CUR
  W="$(echo "$info" | jq -r '.width')"
  H="$(echo "$info" | jq -r '.height')"
  RR="$(echo "$info" | jq -r '.refreshRate')"      # giữ nguyên (vd: 59.95100)
  X="$(echo "$info" | jq -r '.x')"
  Y="$(echo "$info" | jq -r '.y')"
  SCALE="$(echo "$info" | jq -r '.scale')"
  CUR="$(echo "$info" | jq -r '.transform')"

  [[ "$W" != "null" && "$H" != "null" ]] || return 1
  # Clean refresh rate: strip trailing zeroes (59.95100 -> 59.951) to match mode
  RR="${RR%%0}"; RR="${RR%%.}"

  local NEXT="$CUR"
  if [[ -n "$SET_MODE" ]]; then
    case "$SET_MODE" in 0|1|2|3) NEXT="$SET_MODE" ;; *) notify-send "Rotate" "Invalid transform: $SET_MODE"; return 1 ;; esac
  else
    for i in "${!CYCLE[@]}"; do
      if [[ "${CYCLE[$i]}" == "$CUR" ]]; then
        NEXT="${CYCLE[$(((i+1)%${#CYCLE[@]}))]}"; break
      fi
    done
  fi

  local RES="${W}x${H}@${RR}"
  local POS="${X}x${Y}"
  hyprctl keyword monitor "${MON},${RES},${POS},${SCALE},transform,${NEXT}"

  # Refresh wallpaper (avoid stale display after rotation)
  if pgrep -x swww-daemon >/dev/null 2>&1 && command -v swww >/dev/null 2>&1; then
    swww redraw || true
  elif pgrep -x hyprpaper >/dev/null 2>&1; then
    pkill hyprpaper || true
    ( setsid hyprpaper >/dev/null 2>&1 & ) || true
  fi

  notify-send "Rotate" "$MON → transform=$NEXT" || true
}

if [[ "$ALL" -eq 1 ]]; then
  while read -r n; do [[ -n "$n" ]] && rotate_one "$n"; done < <(pick_names)
else
  target="$(pick_names)"
  [[ -n "$target" ]] || { notify-send "Rotate" "No monitor found"; exit 1; }
  rotate_one "$target"
fi
