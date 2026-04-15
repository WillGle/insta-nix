#!/usr/bin/env bash

export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/${USER:-$(id -un)}/bin:${HOME}/.nix-profile/bin:${PATH}"

SCREEN_TIME_HOME="${SCREEN_TIME_HOME:-${XDG_DATA_HOME:-${HOME}/.local/share}/rofi-screen-time}"
SCREEN_TIME_CACHE_HOME="${SCREEN_TIME_CACHE_HOME:-${XDG_CACHE_HOME:-${HOME}/.cache}/rofi-screen-time}"
SCREEN_TIME_SAMPLE_SECONDS="${SCREEN_TIME_SAMPLE_SECONDS:-5}"
SCREEN_TIME_LIB_HOME="${SCREEN_TIME_LIB_HOME:-${HOME}/.local/lib/rofi-screen-time}"
CATEGORY_MAP_FILE="${CATEGORY_MAP_FILE:-${XDG_CONFIG_HOME:-${HOME}/.config}/rofi-screen-time/category-map.json}"
THEME_STATIC_ENV="${HOME}/.config/theme/static.env"
CACHE_FILE="${SCREEN_TIME_CACHE_HOME}/desktop-cache.tsv"

if [ -r "$THEME_STATIC_ENV" ]; then
  # shellcheck disable=SC1090
  . "$THEME_STATIC_ENV"
fi

BASE_COLOR="${THEME_STATIC_BASE:-#11140f}"
MANTLE_COLOR="${THEME_STATIC_MANTLE:-#1d211b}"
TEXT_COLOR="${THEME_STATIC_TEXT:-#e1e4da}"
SUBTEXT_COLOR="${THEME_STATIC_SUBTEXT:-#c3c8bc}"
ACCENT_COLOR="${THEME_STATIC_ACCENT:-#a7d293}"
SUCCESS_COLOR="${THEME_STATIC_SUCCESS:-#bccbb1}"
WARNING_COLOR="${THEME_STATIC_WARNING:-#d29922}"
ERROR_COLOR="${THEME_STATIC_ERROR:-#f85149}"
PURPLE_COLOR="${THEME_STATIC_PURPLE:-#a0cfd1}"
CYAN_COLOR="${THEME_STATIC_CYAN:-#8fc0ff}"

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
    day|overview|summary|trend|recommendations|recommendation)
      printf 'summary\n'
      ;;
    app|categories|windows|time|time-windows|activity)
      printf 'activity\n'
      ;;
    focus|health|quality|data-quality)
      printf 'health\n'
      ;;
    study-timer|timer)
      printf 'timer\n'
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

humanize_metric() {
  local key="$1"
  case "$key" in
    browser_ambiguity_ratio) printf "Browser Ambiguity\n" ;;
    unknown_share)          printf "Unknown Apps\n" ;;
    switch_rate)            printf "Switch Rate\n" ;;
    focus_score)            printf "Focus Score\n" ;;
    fragmentation_score)    printf "Fragmentation\n" ;;
    *) humanize_class "$key" ;;
  esac
}

escape_markup() {
  local value="${1//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  printf '%s\n' "$value"
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

format_ratio_percent() {
  local raw="${1:-}"
  jq -nr --arg raw "$raw" '
    ($raw | if . == "" or . == "null" then null else tonumber? end) as $ratio
    | if $ratio == null then
        "Unavailable"
      else
        (($ratio * 100) | round | tostring) + "%"
      end
  '
}

format_ratio_points_delta() {
  local raw="${1:-}"
  jq -nr --arg raw "$raw" '
    ($raw | if . == "" or . == "null" then null else tonumber? end) as $delta
    | if $delta == null then
        "Unavailable"
      else
        ($delta * 100) as $points
        | if $points > 0 then
            "+" + ($points | round | tostring) + "pp"
          elif $points < 0 then
            ($points | round | tostring) + "pp"
          else
            "0pp"
          end
      end
  '
}

format_score_delta() {
  local raw="${1:-}"
  jq -nr --arg raw "$raw" '
    ($raw | if . == "" or . == "null" then null else tonumber? end) as $delta
    | if $delta == null then
        "Unavailable"
      else
        if $delta > 0 then
          "+" + ($delta | round | tostring) + " pts"
        elif $delta < 0 then
          ($delta | round | tostring) + " pts"
        else
          "0 pts"
        end
      end
  '
}

format_rate_with_avg() {
  local current="${1:-}"
  local avg="${2:-}"
  jq -nr --arg current "$current" --arg avg "$avg" '
    def number_or_null($value):
      if $value == "" or $value == "null" then
        null
      else
        ($value | tonumber?)
      end;

    (number_or_null($current)) as $current_rate
    | (number_or_null($avg)) as $avg_rate
    | if $current_rate == null then
        "Unavailable"
      else
        (($current_rate * 10 | round / 10) | tostring) + "/h"
        + " • avg "
        + (if $avg_rate == null then "n/a" else (($avg_rate * 10 | round / 10) | tostring) + "/h" end)
      end
  '
}

format_ratio_with_avg() {
  local current="${1:-}"
  local avg="${2:-}"
  jq -nr --arg current "$current" --arg avg "$avg" '
    def number_or_null($value):
      if $value == "" or $value == "null" then
        null
      else
        ($value | tonumber?)
      end;

    (number_or_null($current)) as $current_ratio
    | (number_or_null($avg)) as $avg_ratio
    | if $current_ratio == null then
        "Unavailable"
      else
        (($current_ratio * 100) | round | tostring) + "%"
        + " • avg "
        + (if $avg_ratio == null then "n/a" else (($avg_ratio * 100) | round | tostring) + "%" end)
      end
  '
}

delta_label_seconds() {
  local delta="${1:-0}"
  local arrow="→"
  local abs_delta="$delta"

  if [ "$delta" -gt 0 ]; then
    arrow="↑"
  elif [ "$delta" -lt 0 ]; then
    arrow="↓"
    abs_delta=$((delta * -1))
  fi

  printf '%s %s\n' "$arrow" "$(seconds_to_short "$abs_delta")"
}

count_label() {
  local count="${1:-0}"
  local singular="$2"
  local plural="${3:-${2}s}"
  if [ "$count" -eq 1 ]; then
    printf '%d %s\n' "$count" "$singular"
    return 0
  fi
  printf '%d %s\n' "$count" "$plural"
}

percent_label() {
  local numerator="${1:-0}"
  local denominator="${2:-0}"
  if [ "$denominator" -le 0 ]; then
    printf '0%%\n'
    return 0
  fi
  printf '%d%%\n' $(( (numerator * 100) / denominator ))
}

day_file() {
  printf '%s/days/%s.json\n' "$SCREEN_TIME_HOME" "$1"
}

study_active_file() {
  printf '%s/study-active.json\n' "$SCREEN_TIME_HOME"
}

epoch_from_iso() {
  date -d "$1" +%s 2>/dev/null || printf '0\n'
}

time_from_minutes() {
  local minutes="${1:-0}"
  printf '%02d:%02d\n' $((minutes / 60)) $((minutes % 60))
}

slot_start_label() {
  local slot="${1:-0}"
  time_from_minutes $((slot * 30))
}

slot_end_label() {
  local slot="${1:-0}"
  time_from_minutes $((((slot + 1) * 30) % 1440))
}

slot_range_label() {
  local slot="${1:-0}"
  printf '%s-%s\n' "$(slot_start_label "$slot")" "$(slot_end_label "$slot")"
}

date_title() {
  local target="$1"
  local today
  local yesterday
  today="$(date +%F)"
  yesterday="$(date -d "$today -1 day" +%F)"

  if [ "$target" = "$today" ]; then
    printf 'Today\n'
  elif [ "$target" = "$yesterday" ]; then
    printf 'Yesterday\n'
  else
    date -d "$target" '+%a %d %b'
  fi
}

updated_time_label() {
  local timestamp="$1"
  if [ -z "$timestamp" ]; then
    printf 'No samples\n'
    return 0
  fi
  date -d "$timestamp" '+%H:%M'
}

default_day_json() {
  local target_date="$1"
  local now_iso="${2:-$(date --iso-8601=seconds)}"
  local sample="${3:-$SCREEN_TIME_SAMPLE_SECONDS}"
  local version="${4:-2}"

  jq -n \
    --arg date "$target_date" \
    --arg now "$now_iso" \
    --argjson sample "$sample" \
    --argjson version "$version" \
    '{
      version: $version,
      date: $date,
      updated_at: $now,
      sample_seconds: $sample,
      sample_count: 0,
      first_seen: "",
      last_seen: "",
      session_count: 0,
      switch_count: 0,
      last_app: "",
      last_sample_at: "",
      total_seconds: 0,
      slots_30m: ([range(0; 48)] | map(0)),
      apps: {},
      study: {
        total_seconds: 0,
        session_count: 0,
        last_started_at: "",
        last_stopped_at: "",
        active_overlap_seconds: 0
      }
    }'
}

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
    def default_study: {
      total_seconds: 0,
      session_count: 0,
      last_started_at: "",
      last_stopped_at: "",
      active_overlap_seconds: 0
    };
    def normalize_app($key):
      (. // {})
      | {
          key: $key,
          class: (.class // $key),
          name: (.name // $key),
          icon: (.icon // ""),
          seconds: (.seconds // 0),
          sample_count: (.sample_count // 0),
          session_count: (.session_count // 0),
          first_seen: (.first_seen // ""),
          last_seen: (.last_seen // ""),
          slots_30m: ((.slots_30m // zero_slots) | if length == 48 then . else zero_slots end)
        };

    (. // {}) as $day
    | {
        missing: ($day.missing // false),
        version: ($day.version // 0),
        date: ($day.date // $date),
        updated_at: ($day.updated_at // $now),
        sample_seconds: ($day.sample_seconds // $sample),
        sample_count: ($day.sample_count // 0),
        first_seen: ($day.first_seen // ""),
        last_seen: ($day.last_seen // ""),
        session_count: ($day.session_count // 0),
        switch_count: ($day.switch_count // 0),
        last_app: ($day.last_app // ""),
        last_sample_at: ($day.last_sample_at // ""),
        total_seconds: ($day.total_seconds // 0),
        slots_30m: (($day.slots_30m // zero_slots) | if length == 48 then . else zero_slots end),
        apps: (
          ($day.apps // {})
          | to_entries
          | map(.key as $key | {key: $key, value: (.value | normalize_app($key))})
          | from_entries
        ),
        study: (
          ($day.study // default_study)
          | {
              total_seconds: (.total_seconds // 0),
              session_count: (.session_count // 0),
              last_started_at: (.last_started_at // ""),
              last_stopped_at: (.last_stopped_at // ""),
              active_overlap_seconds: (.active_overlap_seconds // 0)
            }
        )
      }
    | .schema_ready = (.version >= 2)
    '
}

study_status_json() {
  local file
  local started_at=""
  local started_date=""
  local start_epoch=0
  local current_epoch=0
  local elapsed=0

  file="$(study_active_file)"
  if [ ! -f "$file" ]; then
    jq -n '{active:false, started_at:"", started_date:"", elapsed_seconds:0}'
    return 0
  fi
  if ! jq -e '.active == true and (.started_at // "" | length > 0)' "$file" >/dev/null 2>&1; then
    jq -n '{active:false, started_at:"", started_date:"", elapsed_seconds:0}'
    return 0
  fi

  started_at="$(jq -r '.started_at // empty' "$file")"
  start_epoch="$(epoch_from_iso "$started_at")"
  if [ "$start_epoch" -le 0 ]; then
    jq -n '{active:false, started_at:"", started_date:"", elapsed_seconds:0}'
    return 0
  fi

  current_epoch="$(date +%s)"
  if [ "$current_epoch" -gt "$start_epoch" ]; then
    elapsed=$((current_epoch - start_epoch))
  fi
  started_date="$(date -d "$started_at" +%F)"

  jq -n \
    --arg started_at "$started_at" \
    --arg started_date "$started_date" \
    --argjson elapsed_seconds "$elapsed" \
    '{active:true, started_at:$started_at, started_date:$started_date, elapsed_seconds:$elapsed_seconds}'
}

study_overlap_seconds_for_date() {
  local target_date="$1"
  local status_json=""
  local started_at=""
  local start_epoch=0
  local now_epoch=0
  local day_start=0
  local day_end=0
  local overlap_start=0
  local overlap_end=0

  status_json="$(study_status_json)"
  if [ "$(printf '%s' "$status_json" | jq -r '.active')" != "true" ]; then
    printf '0\n'
    return 0
  fi

  started_at="$(printf '%s' "$status_json" | jq -r '.started_at')"
  start_epoch="$(epoch_from_iso "$started_at")"
  now_epoch="$(date +%s)"
  day_start="$(date -d "$target_date 00:00:00" +%s)"
  day_end="$(date -d "$target_date +1 day 00:00:00" +%s)"

  overlap_start="$start_epoch"
  if [ "$day_start" -gt "$overlap_start" ]; then
    overlap_start="$day_start"
  fi
  overlap_end="$now_epoch"
  if [ "$day_end" -lt "$overlap_end" ]; then
    overlap_end="$day_end"
  fi

  if [ "$overlap_end" -le "$overlap_start" ]; then
    printf '0\n'
  else
    printf '%d\n' $((overlap_end - overlap_start))
  fi
}

merge_active_study_into_day_json() {
  local target_date="$1"
  local day_json="$2"
  local overlap=0
  local active_json=""
  local started_at=""

  overlap="$(study_overlap_seconds_for_date "$target_date")"
  if [ "$overlap" -le 0 ]; then
    printf '%s\n' "$day_json"
    return 0
  fi

  active_json="$(study_status_json)"
  started_at="$(printf '%s' "$active_json" | jq -r '.started_at // empty')"

  printf '%s' "$day_json" \
    | jq \
      --arg started_at "$started_at" \
      --argjson overlap "$overlap" \
      '
      .study.total_seconds = ((.study.total_seconds // 0) + $overlap)
      | .study.active_overlap_seconds = $overlap
      | .study.last_started_at = (if (.study.last_started_at // "") == "" then $started_at else .study.last_started_at end)
      '
}

day_json_for_date() {
  local target_date="$1"
  local now_iso=""
  local file=""
  local day_json=""

  now_iso="$(date --iso-8601=seconds)"
  file="$(day_file "$target_date")"

  if [ -f "$file" ]; then
    day_json="$(normalize_day_json "$target_date" "$now_iso" "$SCREEN_TIME_SAMPLE_SECONDS" <"$file")"
  else
    day_json="$(default_day_json "$target_date" "$now_iso" "$SCREEN_TIME_SAMPLE_SECONDS" 0 | jq '.missing = true | .schema_ready = false')"
  fi

  merge_active_study_into_day_json "$target_date" "$day_json"
}

trailing_days_json() {
  local target_date="$1"
  local count="${2:-7}"
  local start_date=""
  local cursor=""

  start_date="$(date -d "$target_date -$((count - 1)) days" +%F)"
  cursor="$start_date"

  while :; do
    day_json_for_date "$cursor"
    if [ "$cursor" = "$target_date" ]; then
      break
    fi
    cursor="$(date -d "$cursor +1 day" +%F)"
  done | jq -sc '.'
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
      done < <(find "$dir" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)
    done
  } | awk -F '\t' '!seen[$1]++' >"$tmp"

  mv "$tmp" "$CACHE_FILE"
}

resolve_app_meta() {
  local app_key="$1"
  local name=""
  local icon=""

  build_desktop_cache
  if [ -s "$CACHE_FILE" ]; then
    name="$(awk -F '\t' -v key="$app_key" '$1 == key { print $2; exit }' "$CACHE_FILE")"
    icon="$(awk -F '\t' -v key="$app_key" '$1 == key { print $3; exit }' "$CACHE_FILE")"
  fi

  if [ -z "$name" ]; then
    name="$(humanize_class "$app_key")"
  fi
  printf '%s\t%s\n' "$name" "$icon"
}

build_data_bundle_json() {
  local target_date="$1"
  local category_map_json="$2"
  local yesterday_date=""
  local today_json=""
  local yesterday_json=""
  local trailing_json=""
  local study_active_json=""

  yesterday_date="$(date -d "$target_date -1 day" +%F)"
  today_json="$(day_json_for_date "$target_date")"
  yesterday_json="$(day_json_for_date "$yesterday_date")"
  trailing_json="$(trailing_days_json "$target_date" 7)"
  study_active_json="$(study_status_json)"

  jq -n \
    --arg target_date "$target_date" \
    --arg yesterday_date "$yesterday_date" \
    --arg category_map_path "$CATEGORY_MAP_FILE" \
    --argjson category_map "$category_map_json" \
    --argjson today "$today_json" \
    --argjson yesterday "$yesterday_json" \
    --argjson trailing "$trailing_json" \
    --argjson study_active "$study_active_json" \
    '{
      target_date: $target_date,
      yesterday_date: $yesterday_date,
      category_map_path: $category_map_path,
      category_map: $category_map,
      today: $today,
      yesterday: $yesterday,
      trailing: $trailing,
      study_active: $study_active
    }'
}
