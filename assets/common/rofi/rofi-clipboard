#!/usr/bin/env bash
set -euo pipefail

if pgrep -x rofi >/dev/null 2>&1; then
  pkill -x rofi
  exit 0
fi

selection="$(
  cliphist list | rofi -dmenu -i \
    -p "Clipboard:" \
    -config ~/.config/rofi/config.rasi \
    -theme-str 'window { width: 50%; }' \
    -theme-str 'listview { lines: 12; columns: 1; }' \
    -theme-str 'element { children: [ element-text ]; }' \
    -theme-str 'element-icon { enabled: false; }'
)"

if [ -n "$selection" ]; then
  printf '%s\n' "$selection" | cliphist decode | wl-copy
fi
