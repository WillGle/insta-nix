#!/usr/bin/env bash

SCREEN_TIME_HOME="${SCREEN_TIME_HOME:-${XDG_DATA_HOME:-${HOME}/.local/share}/rofi-screen-time}"
SCREEN_TIME_CACHE_HOME="${SCREEN_TIME_CACHE_HOME:-${XDG_CACHE_HOME:-${HOME}/.cache}/rofi-screen-time}"
SCREEN_TIME_SAMPLE_SECONDS="${SCREEN_TIME_SAMPLE_SECONDS:-5}"
CATEGORY_MAP_FILE="${CATEGORY_MAP_FILE:-${XDG_CONFIG_HOME:-${HOME}/.config}/rofi-screen-time/category-map.json}"
THEME_STATIC_ENV="${HOME}/.config/theme/static.env"
CACHE_FILE="${SCREEN_TIME_CACHE_HOME}/desktop-cache.tsv"

if [ -r "$THEME_STATIC_ENV" ]; then
  # shellcheck disable=SC1090
  . "$THEME_STATIC_ENV"
fi

THEME_PALETTE_FILE="${THEME_GENERATED_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/theme/generated}/palette.json"

BASE_COLOR="${THEME_STATIC_BASE:-#11140f}"
TEXT_COLOR="${THEME_STATIC_TEXT:-#e1e4da}"
SUBTEXT_COLOR="${THEME_STATIC_SUBTEXT:-#c3c8bc}"
ACCENT_COLOR="${THEME_STATIC_ACCENT:-#a7d293}"
SUCCESS_COLOR="@signalOk@"
WARNING_COLOR="@signalWarning@"
ERROR_COLOR="@signalCritical@"
PURPLE_COLOR="${THEME_STATIC_PURPLE:-#a0cfd1}"
CYAN_COLOR="${THEME_STATIC_CYAN:-#8fc0ff}"

# The packaged copy lives beside this file; direct repo tests may not have it.
SCREEN_TIME_PALETTE_LIB="${SCREEN_TIME_PALETTE_LIB:-$(dirname "${BASH_SOURCE[0]}")/palette.sh}"
if [ -r "$SCREEN_TIME_PALETTE_LIB" ]; then
  # shellcheck source=/dev/null
  . "$SCREEN_TIME_PALETTE_LIB"
fi

# Match the generated palette, falling back to static.env before generation.
# Keep signal colours fixed so their meaning survives wallpaper changes.
if declare -F load_runtime_palette >/dev/null && load_runtime_palette; then
  BASE_COLOR="${RUNTIME_PALETTE[0]}"
  TEXT_COLOR="${RUNTIME_PALETTE[2]}"
  SUBTEXT_COLOR="${RUNTIME_PALETTE[3]}"
  ACCENT_COLOR="${RUNTIME_PALETTE[4]}"
  PURPLE_COLOR="${RUNTIME_PALETTE[8]}"
  CYAN_COLOR="${RUNTIME_PALETTE[9]}"
fi

trim() {
  local value="${1:-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "$value"
}

normalize_class() {
  local value
  value="$(trim "${1,,}")"
  value="${value%.exe}"
  value="${value%-updater}"
  value="${value%_updater}"
  value="${value% updater}"
  printf '%s\n' "$value"
}

resolve_screen_time_view() {
  case "${1:-summary}" in
    day|overview|summary|trend)
      printf 'summary\n'
      ;;
    app|categories|windows|time|time-windows|activity)
      printf 'activity\n'
      ;;
    *)
      printf 'summary\n'
      ;;
  esac
}

humanize_class() {
  local value="${1//[_-]/ }"
  local out=""
  local word=""
  for word in $value; do
    out+="${word^} "
  done
  printf '%s\n' "${out%" "}"
}

rasi_quote() {
  jq -Rn --arg value "$1" '$value'
}

seconds_to_short() {
  local total="${1:-0}"
  local hours=$((total / 3600))
  local minutes=$(((total % 3600) / 60))

  if [ "$total" -gt 0 ] && [ "$hours" -eq 0 ] && [ "$minutes" -eq 0 ]; then
    printf '~1m\n'
    return 0
  fi
  if [ "$hours" -gt 0 ] && [ "$minutes" -gt 0 ]; then
    printf '%dh %dm\n' "$hours" "$minutes"
    return 0
  fi
  if [ "$hours" -gt 0 ]; then
    printf '%dh\n' "$hours"
    return 0
  fi
  printf '%dm\n' "$minutes"
}

seconds_to_compact() {
  local total="${1:-0}"
  local hours=$((total / 3600))
  local minutes=$(((total % 3600) / 60))

  if [ "$total" -gt 0 ] && [ "$hours" -eq 0 ] && [ "$minutes" -eq 0 ]; then
    printf '~1m\n'
    return 0
  fi
  if [ "$hours" -gt 0 ]; then
    printf '%dh %02dm\n' "$hours" "$minutes"
    return 0
  fi
  printf '%dm\n' "$minutes"
}

# Avoid jq startup for one number; round half away from zero.
format_ratio_percent() {
  local raw="${1:-}"
  case "$raw" in
    ""|null) printf 'Unavailable\n'; return 0 ;;
  esac
  awk -v r="$raw" 'BEGIN {
    if (r !~ /^[-+]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][-+]?[0-9]+)?$/) { print "Unavailable"; exit }
    x = r * 100
    printf "%d%%\n", (x < 0 ? int(x - 0.5) : int(x + 0.5))
  }'
}

day_file() {
  printf '%s/days/%s.json\n' "$SCREEN_TIME_HOME" "$1"
}

updated_time_label() {
  local timestamp="$1"
  if [ -z "$timestamp" ]; then
    printf 'No samples\n'
    return 0
  fi
  date -d "$timestamp" '+%H:%M'
}

# Shared day-file schema for the tracker, popup, and Waybar.
default_day_json() {
  local target_date="$1"
  local now_iso="${2:-$(date --iso-8601=seconds)}"
  local sample="${3:-$SCREEN_TIME_SAMPLE_SECONDS}"

  jq -n \
    --arg date "$target_date" \
    --arg now "$now_iso" \
    --argjson sample "$sample" \
    '{
      version: 3,
      date: $date,
      updated_at: $now,
      sample_seconds: $sample,
      sample_count: 0,
      first_seen: "",
      last_seen: "",
      total_seconds: 0,
      slots_30m: ([range(0; 48)] | map(0)),
      apps: {}
    }'
}

with_day_lock() {
  local state_dir="$1"
  shift
  local status=0

  mkdir -p "$state_dir/days"
  exec 7>>"$state_dir/days/.lock"
  flock 7
  "$@" || status=$?
  exec 7>&-
  return "$status"
}

# Read legacy schema and emit the minimal v3 shape. Historical app totals and
# slots are preserved; study, behavior, and session bookkeeping are dropped.
normalize_day_json() {
  local target_date="$1"
  local now_iso="${2:-$(date --iso-8601=seconds)}"
  local sample="${3:-$SCREEN_TIME_SAMPLE_SECONDS}"

  jq \
    --arg date "$target_date" \
    --arg now "$now_iso" \
    --argjson sample "$sample" \
    '
    def zero_slots: ([range(0; 48)] | map(0));
    def normalize_app($key):
      (. // {})
      | {
          class: (.class // $key),
          name: (.name // $key),
          icon: (.icon // ""),
          seconds: (.seconds // 0),
          sample_count: (.sample_count // 0),
          first_seen: (.first_seen // ""),
          last_seen: (.last_seen // ""),
          slots_30m: ((.slots_30m // zero_slots) | if length == 48 then . else zero_slots end)
        };

    (. // {}) as $day
    | {
        version: 3,
        date: ($day.date // $date),
        updated_at: ($day.updated_at // $now),
        sample_seconds: ($day.sample_seconds // $sample),
        sample_count: ($day.sample_count // 0),
        first_seen: ($day.first_seen // ""),
        last_seen: ($day.last_seen // ""),
        total_seconds: ($day.total_seconds // 0),
        slots_30m: (($day.slots_30m // zero_slots) | if length == 48 then . else zero_slots end),
        apps: (
          ($day.apps // {})
          | to_entries
          | map(.key as $key | {key: $key, value: (.value | normalize_app($key))})
          | from_entries
        )
      }
    '
}

day_json_for_date() {
  local target_date="$1"
  local now_iso=""
  local file=""

  now_iso="$(date --iso-8601=seconds)"
  file="$(day_file "$target_date")"

  if [ -f "$file" ]; then
    normalize_day_json "$target_date" "$now_iso" "$SCREEN_TIME_SAMPLE_SECONDS" <"$file"
  else
    default_day_json "$target_date" "$now_iso" "$SCREEN_TIME_SAMPLE_SECONDS"
  fi
}

build_desktop_cache() {
  if [ -s "$CACHE_FILE" ]; then
    return 0
  fi
  mkdir -p "$SCREEN_TIME_CACHE_HOME"

  local tmp
  local xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  local xdg_data_dirs="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
  local data_dir=""
  local search_dirs=("$xdg_data_home/applications")
  local dir=""
  local desktop=""
  local name=""
  local icon=""
  local wmclass=""
  local key=""
  tmp="$(mktemp)"

  for data_dir in ${xdg_data_dirs//:/ }; do
    search_dirs+=("$data_dir/applications")
  done
  search_dirs+=(
    "/var/lib/flatpak/exports/share/applications"
    "/var/lib/snapd/desktop/applications"
  )

  {
    for dir in "${search_dirs[@]}"; do
      [ -d "$dir" ] || continue
      while IFS= read -r -d '' desktop; do
        name=""
        icon=""
        wmclass=""
        while IFS= read -r line; do
          case "$line" in
            Name=*)
              [ -n "$name" ] || name="${line#Name=}"
              ;;
            Icon=*)
              [ -n "$icon" ] || icon="${line#Icon=}"
              ;;
            StartupWMClass=*)
              [ -n "$wmclass" ] || wmclass="${line#StartupWMClass=}"
              ;;
          esac
        done <"$desktop"

        [ -n "$name" ] || continue
        key="$(normalize_class "$(basename "$desktop" .desktop)")"
        [ -n "$key" ] && printf '%s\t%s\t%s\n' "$key" "$name" "$icon"
        if [ -n "$wmclass" ]; then
          key="$(normalize_class "$wmclass")"
          [ -n "$key" ] && printf '%s\t%s\t%s\n' "$key" "$name" "$icon"
        fi
      done < <(find -L "$dir" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)
    done
  } | awk -F '\t' '!seen[$1]++' >"$tmp"

  mv "$tmp" "$CACHE_FILE"
}

build_data_bundle_json() {
  local target_date="$1"
  local category_map_json="$2"
  local today_json=""

  today_json="$(day_json_for_date "$target_date")"

  jq -n \
    --arg target_date "$target_date" \
    --arg category_map_path "$CATEGORY_MAP_FILE" \
    --argjson category_map "$category_map_json" \
    --argjson today "$today_json" \
    '{
      target_date: $target_date,
      category_map_path: $category_map_path,
      category_map: $category_map,
      today: $today
    }'
}
