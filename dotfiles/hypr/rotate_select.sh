#!/usr/bin/env bash
set -euo pipefail

# --- PATH & ENV cho NixOS/Hyprland khi chạy từ keybind ---
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:$PATH"
: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  sig="$(ls -1t /tmp/hypr 2>/dev/null | head -n1 || true)"
  [[ -n "$sig" ]] && export HYPRLAND_INSTANCE_SIGNATURE="$sig"
fi

# --- Args ---
#   rotate_select.sh                -> cycle 0→90→270 cho monitor under-cursor / focused
#   rotate_select.sh --set 0|1|2|3  -> ép góc cụ thể cho monitor được chọn
#   rotate_select.sh --all          -> cycle cho tất cả monitor đang bật
#   rotate_select.sh --all --set N  -> ép góc N cho tất cả
SET_MODE=""; ALL=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --set) shift; SET_MODE="${1:-}";;
    --all) ALL=1;;
    *) : ;;
  esac
  shift || true
done

# Chu kỳ: 0 (ngang) -> 1 (90) -> 3 (270) -> 0
CYCLE=(0 1 3)

# --- Kiểm tra binary cần thiết ---
command -v hyprctl >/dev/null 2>&1 || { echo "hyprctl not found"; exit 1; }
command -v jq      >/dev/null 2>&1 || { notify-send "Rotate" "Thiếu jq"; echo "jq is required"; exit 1; }

json_monitors="$(hyprctl -j monitors)"

pick_names() {
  if [[ "$ALL" -eq 1 ]]; then
    echo "$json_monitors" | jq -r '.[] | select(.disabled==false) | .name'
    return
  fi
  # Ưu tiên monitor đang focused
  local name
  name="$(echo "$json_monitors" | jq -r '.[] | select(.focused==true) | .name' || true)"
  if [[ -n "$name" && "$name" != "null" ]]; then
    echo "$name"; return
  fi
  # Fallback: monitor dưới con trỏ
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
  # Cuối cùng: monitor đầu tiên
  echo "$json_monitors" | jq -r '.[] | select(.disabled==false) | .name' | head -n1
}

rotate_one() {
  local MON="$1"
  local info
  info="$(echo "$json_monitors" | jq --arg m "$MON" -r '.[] | select(.name==$m)')"
  [[ -n "$info" ]] || { notify-send "Rotate" "Không tìm thấy $MON"; return; }

  local W H RR X Y SCALE CUR
  W="$(echo "$info" | jq -r '.width')"
  H="$(echo "$info" | jq -r '.height')"
  RR="$(echo "$info" | jq -r '.refreshRate')"      # giữ nguyên (vd: 59.95100)
  X="$(echo "$info" | jq -r '.x')"
  Y="$(echo "$info" | jq -r '.y')"
  SCALE="$(echo "$info" | jq -r '.scale')"
  CUR="$(echo "$info" | jq -r '.transform')"

  [[ "$W" != "null" && "$H" != "null" ]] || return 1
  # RR chuẩn: cắt đuôi 0 dư (59.95100 -> 59.951) để khớp mode
  RR="${RR%%0}"; RR="${RR%%.}"

  local NEXT="$CUR"
  if [[ -n "$SET_MODE" ]]; then
    case "$SET_MODE" in 0|1|2|3) NEXT="$SET_MODE" ;; *) notify-send "Rotate" "transform không hợp lệ: $SET_MODE"; return 1 ;; esac
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

  # refresh wallpaper (tránh cảm giác chưa xoay)
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
  [[ -n "$target" ]] || { notify-send "Rotate" "Không tìm thấy monitor"; exit 1; }
  rotate_one "$target"
fi
