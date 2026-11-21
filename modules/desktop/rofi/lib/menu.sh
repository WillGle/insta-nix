#!/usr/bin/env bash
# Shared Rofi dmenu protocol helpers.

escape_markup() {
  local value="${1:-}"
  # Quote replacements so Bash 5.2+ treats & literally.
  value="${value//&/"&amp;"}"
  value="${value//</"&lt;"}"
  value="${value//>/"&gt;"}"
  printf '%s' "$value"
}

emit_row() {
  local token="$1"
  local display="$2"
  local icon="${3:-}"
  printf '%s' "$token"
  printf '\0display\x1f%s' "$display"
  if [ -n "$icon" ]; then
    printf '\x1ficon\x1f%s' "$icon"
  fi
  printf '\n'
}

row_markup() {
  local title="$1"
  local subtitle="${2:-}"

  if [ -n "$subtitle" ]; then
    # Preserve subtitle markup; escape the title.
    printf '<span weight="600">%s</span>&#10;<span size="small">%s</span>' \
      "$(escape_markup "$title")" \
      "$subtitle"
  else
    printf '<span weight="600">%s</span>' "$(escape_markup "$title")"
  fi
}

# Resolve the first readable theme path from the provided candidates.
resolve_rofi_theme() {
  local candidate
  for candidate in "$@"; do
    [ -n "$candidate" ] || continue
    if [ -r "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

run_rofi_menu() {
  local prompt="${1:-}"
  local message="${2:-}"
  local binary="${ROFI_BIN:-rofi}"
  local config="${ROFI_CONFIG:-${XDG_CONFIG_HOME:-${HOME}/.config}/rofi/config.rasi}"
  local theme="${ROFI_THEME:-}"
  local -a args=(
    -dmenu
    -markup-rows
    -show-icons
    -no-custom
    -config "$config"
  )

  if [ -n "$theme" ]; then
    args+=(-theme "$theme")
  fi
  if [ -n "$prompt" ]; then
    args+=(-p "$prompt")
  fi
  if [ -n "$message" ]; then
    args+=(-mesg "$message")
  fi

  "$binary" "${args[@]}"
}
