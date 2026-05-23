#!/usr/bin/env bash
set -euo pipefail

mode="${1:-drun}"

if pgrep -x rofi >/dev/null 2>&1; then
  pkill -x rofi
  exit 0
fi

exec rofi -show "$mode" -config ~/.config/rofi/config.rasi
