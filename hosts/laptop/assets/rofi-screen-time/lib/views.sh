#!/usr/bin/env bash

bar_markup() {
  local value="${1:-0}"
  local max="${2:-0}"
  local width="${3:-12}"
  local fill_color="${4:-$ACCENT_COLOR}"
  local empty_color="${5:-$BASE_COLOR}"
  local filled=0
  local out=""
  local i=0

  if [ "$max" -gt 0 ]; then
    filled=$((value * width / max))
  fi
  if [ "$filled" -le 0 ] && [ "$value" -gt 0 ]; then
    filled=1
  fi

  while [ "$i" -lt "$filled" ]; do
    out+="<span foreground=\"$fill_color\">█</span>"
    i=$((i + 1))
  done
  while [ "$i" -lt "$width" ]; do
    out+="<span foreground=\"$empty_color\">█</span>"
    i=$((i + 1))
  done

  printf '%s\n' "$out"
}

# Small counts read faster as countable marks than as a digit the eye has to
# parse. Used for values whose interesting range is a handful, where a
# proportional bar would be almost entirely empty and say nothing.
pips_markup() {
  local filled="${1:-0}"
  local total="${2:-5}"
  local color="${3:-$ACCENT_COLOR}"
  local i=0
  local on=""
  local off=""

  [ "$filled" -gt "$total" ] && filled="$total"
  while [ "$i" -lt "$total" ]; do
    if [ "$i" -lt "$filled" ]; then on+="●"; else off+="○"; fi
    i=$((i + 1))
  done
  printf '<span foreground="%s">%s</span><span foreground="%s">%s</span>' \
    "$color" "$on" "$BASE_COLOR" "$off"
}

# The category palette, hoisted out of momentum_sparkline_from_json so the
# 24-hour strip and the category breakdown agree on what colour a category is.
# This is identity colour, not severity: it answers "which category" and must
# never be read as "how bad", which is what severity_color below is for.
# Assigns rather than prints, so per-slot loops can ask 48 times without paying
# a subshell each time. category_color below is the printing form.
set_category_color() {
  case "${1:-}" in
    Study) CATEGORY_COLOR="$SUCCESS_COLOR" ;;
    Work) CATEGORY_COLOR="$CYAN_COLOR" ;;
    Communication) CATEGORY_COLOR="$WARNING_COLOR" ;;
    Entertainment | Media) CATEGORY_COLOR="$ERROR_COLOR" ;;
    Browser) CATEGORY_COLOR="$PURPLE_COLOR" ;;
    *) CATEGORY_COLOR="$SUBTEXT_COLOR" ;;
  esac
}

category_color() {
  set_category_color "${1:-}"
  printf '%s' "$CATEGORY_COLOR"
}

# One threshold ladder for every bounded metric, so the same number cannot read
# as "fine" in one block and "warning" in another.
severity_color() {
  local value="${1:-0}"
  local warn_at="${2:-50}"
  local crit_at="${3:-70}"
  if [ "$value" -ge "$crit_at" ]; then
    printf '%s' "$ERROR_COLOR"
  elif [ "$value" -ge "$warn_at" ]; then
    printf '%s' "$WARNING_COLOR"
  else
    printf '%s' "$SUCCESS_COLOR"
  fi
}

sparkline_from_json() {
  local values_json="$1"
  local highlight_index="${2:-}"
  local index=0
  local out=""
  local chars=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
  local color=""
  local glyph_index=0
  local positive=""

  # One jq pass emits "<glyph index>\t<is positive>" per value so the loop below
  # forks nothing. It used to spend two processes on length and max plus three
  # per data point, and render_app_usage_timeline calls this once per app: a
  # 48-slot sparkline across six apps was over eight hundred jq processes.
  # An empty array emits no rows, leaving out="" and the bare newline the
  # length<=0 early return used to print.
  while IFS=$'\t' read -r glyph_index positive; do
    if [ "$positive" = "true" ]; then
      color="$CYAN_COLOR"
    else
      color="$BASE_COLOR"
    fi
    if [ -n "$highlight_index" ] && [ "$index" -eq "$highlight_index" ]; then
      color="$ACCENT_COLOR"
    fi
    out+="<span foreground=\"$color\">${chars[$glyph_index]}</span>"
    index=$((index + 1))
  done < <(
    printf '%s' "$values_json" | jq -r '
      (map(select(type == "number")) | max // 0) as $max
      | .[]
      | (. // 0) as $value
      | "\(if $max <= 0 then 0 else (($value * 7 / $max) | floor) end)\t\($value > 0)"
    '
  )

  printf '%s\n' "$out"
}

render_momentum_chart() {
  local slots_bundle_json="$1"
  printf '<span foreground="%s" weight="600">Usage Through The Day</span>\n<span foreground="%s" size="small">00        06        12        18        24   ·   each block = 30m</span>\n%s\n<span size="small" foreground="%s">Legend: <span foreground="%s">■ Work</span>  <span foreground="%s">■ Study</span>  <span foreground="%s">■ Browser</span>  <span foreground="%s">■ Comm</span>  <span foreground="%s">■ Leisure</span></span>\n' \
    "$ACCENT_COLOR" \
    "$SUBTEXT_COLOR" \
    "$(momentum_sparkline_from_json "$slots_bundle_json")" \
    "$SUBTEXT_COLOR" \
    "$CYAN_COLOR" \
    "$SUCCESS_COLOR" \
    "$PURPLE_COLOR" \
    "$WARNING_COLOR" \
    "$ERROR_COLOR"
}

momentum_sparkline_from_json() {
  local slots_bundle_json="$1"
  local out=""
  local glyph_index=0
  local chars=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
  local dominant_cat=""
  local active=0

  # One jq pass emits "<dominant category>\t<glyph index>" per slot, the same
  # shape sparkline_from_json above uses. This function used to re-run jq over
  # the whole bundle once per slot plus a second jq per non-empty slot -- about
  # a hundred processes for one chart, on both the summary and timer views,
  # which is exactly the antipattern the comment on sparkline_from_json
  # describes having removed there.
  #
  # The active flag is a field of its own rather than an empty category field:
  # tab is IFS whitespace, so an empty leading field would be swallowed and
  # every column would read back shifted. Ties go to the first category in key
  # order, as before.
  while IFS=$'\t' read -r active dominant_cat glyph_index; do
    if [ "$active" = "0" ]; then
      CATEGORY_COLOR="$BASE_COLOR"
    else
      set_category_color "$dominant_cat"
    fi
    out+="<span foreground=\"$CATEGORY_COLOR\">${chars[$glyph_index]}</span>"
  done < <(
    printf '%s' "$slots_bundle_json" | jq -r '
      . as $bundle
      | ([.[] | .[]] | max // 0) as $max
      | ($bundle | to_entries) as $cats
      | range(0; 48)
      | . as $i
      | ($cats | map({cat: .key, sec: (.value[$i] // 0)})) as $slot
      | ($slot | map(.sec) | add // 0) as $value
      | (
          reduce $slot[] as $c ({cat: "Unknown", sec: 0};
            if $c.sec > .sec then {cat: $c.cat, sec: $c.sec} else . end
          ) | .cat
        ) as $dominant
      | if $value <= 0 then
          "0\tUnknown\t0"
        else
          "1\t\($dominant)\t\(if $max <= 0 then 1 else (($value * 6 / $max) | floor + 1) end)"
        end
    '
  )

  printf '%s\n' "$out"
}

render_timeline_chart() {
  local slots_json="$1"
  local detail="$2"
  local peak_index=""

  peak_index="$(printf '%s' "$slots_json" | jq -r '
    [to_entries[] | select(.value > 0)]
    | if length == 0 then -1 else (max_by(.value) | .key) end
  ')"

  printf '<span foreground="%s" size="small">00        06        12        18        24</span>\n%s\n<span foreground="%s" size="small">%s</span>\n' \
    "$SUBTEXT_COLOR" \
    "$(sparkline_from_json "$slots_json" "$( [ "$peak_index" -ge 0 ] 2>/dev/null && printf '%s' "$peak_index" || true )")" \
    "$SUBTEXT_COLOR" \
    "$(escape_markup "$detail")"
}

render_hero_day_strip() {
  local context_json="$1"
  local slots_json slots_bundle_json
  slots_json="$(printf '%s' "$context_json" | jq -c '.today.raw.slots_30m // []')"
  slots_bundle_json="$(printf '%s' "$context_json" | jq -c '.today.categories.slots // {}')"

  printf '<span foreground="%s" size="small">00       03       06       09       12       15       18       21       24</span>\n%s\n%s\n%s' \
    "$SUBTEXT_COLOR" \
    "$(momentum_sparkline_from_json "$slots_bundle_json")" \
    "$(kv_markup_raw_value "Activity curve" "$(sparkline_from_json "$slots_json")")" \
    "$(kv_markup_raw_value "Category mix" "Colored by dominant app type per 30m block")"
}

render_transition_bars() {
  local context_json="$1"
  local limit="${2:-5}"
  local output=""
  local max_count

  max_count="$(printf '%s' "$context_json" | jq -r \
    --argjson limit "$limit" '
      (.today.behavior.transitions // [])
      | if ($limit > 0) then .[:$limit] else . end
      | ([.[].count] | max) // 0
    ')"

  while IFS=$'\t' read -r from_app to_app count label; do
    [ -n "$from_app" ] || continue
    # Window classes, humanised the same way every other view shows them, so
    # this panel does not say "brave-browser" where the cards say "Brave Browser".
    local pair_name
    pair_name="$(humanize_class "$from_app") → $(humanize_class "$to_app")"
    # The newline is appended outside the substitution: $( ) strips trailing
    # newlines, so a \n inside the format string is silently swallowed and every
    # row runs into the next one.
    output+="$(printf '%s  %s  %4s×  <span foreground="%s" size="small">%s</span>' \
      "$(escape_markup "$(pad_right "$(clip_text "$pair_name" 24)" 24)")" \
      "$(bar_markup "$count" "$max_count" 14 "$ACCENT_COLOR" "$BASE_COLOR")" \
      "$count" \
      "$SUBTEXT_COLOR" \
      "$(escape_markup "$label")")"$'\n'
  done < <(
    printf '%s' "$context_json" | jq -r \
      --argjson limit "$limit" '
        (.today.behavior.transitions // [])
        | if ($limit > 0) then .[:$limit] else . end
        | (([.[].count] | max) // 0) as $top
        | .[]
        | [
            (if .from != "" then .from else "Unknown" end),
            (if .to != "" then .to else "Unknown" end),
            (.count | tostring),
            # Relative to the busiest pair, not an absolute count. A fixed
            # ">10 is a work loop" makes every row in a top-five list say the
            # same thing, which is a column that costs space and tells you
            # nothing. Against the leader it separates the dominant loops from
            # the occasional hops.
            (if .from == .to then "within task"
             elif ($top > 0 and .count * 2 >= $top) then "work loop"
             else "cross-context" end)
          ]
        | @tsv
      '
  )

  if [ -z "$output" ]; then
    printf '%s\n' "$(kv_markup "Transitions" "No app transitions recorded yet")"
  else
    printf '%s' "${output%$'\n'}"
  fi
}

kv_markup() {
  local label="$1"
  local value="$2"
  printf '<span foreground="%s">%s</span> <span weight="600">%s</span>' \
    "$SUBTEXT_COLOR" \
    "$(escape_markup "$label")" \
    "$(escape_markup "$value")"
}

kv_markup_raw_value() {
  local label="$1"
  local value="$2"
  printf '<span foreground="%s">%s</span> <span weight="600">%s</span>' \
    "$SUBTEXT_COLOR" \
    "$(escape_markup "$label")" \
    "$value"
}

# The label is padded by characters (pad_right) before it is escaped: %-*s
# counted bytes, so a "●" tag or an "&amp;" entity in the label pushed the
# value column right on that row alone.
kv_markup_aligned() {
  local width="$1"
  local label="$2"
  local value="$3"
  printf '<span foreground="%s">%s</span> <span weight="600">%s</span>' \
    "$SUBTEXT_COLOR" \
    "$(escape_markup "$(pad_right "$label" "$width")")" \
    "$(escape_markup "$value")"
}

kv_markup_raw_value_aligned() {
  local width="$1"
  local label="$2"
  local value="$3"
  printf '<span foreground="%s">%s</span> <span weight="600">%s</span>' \
    "$SUBTEXT_COLOR" \
    "$(escape_markup "$(pad_right "$label" "$width")")" \
    "$value"
}

# Left-align to a width measured in characters. bash's printf pads %-Ns by
# bytes, so a label holding "→" (1 character, 3 bytes) came out two columns
# short and the bar after it started early.
pad_right() {
  local value="${1:-}" width="${2:-0}" fill
  fill=$((width - ${#value}))
  [ "$fill" -gt 0 ] || { printf '%s' "$value"; return 0; }
  printf '%s%*s' "$value" "$fill" ''
}

clip_text() {
  local value="${1:-}"
  local max="${2:-18}"

  if [ "${#value}" -le "$max" ]; then
    printf '%s\n' "$value"
    return 0
  fi
  if [ "$max" -le 3 ]; then
    printf '%s\n' "${value:0:$max}"
    return 0
  fi
  printf '%s...\n' "${value:0:$((max - 3))}"
}

render_digital_health() {
  local context_json="$1"
  local eye_risk cog_load circ_phase ultr_score rec_gaps wellbeing_json wellbeing_val afi confidence untracked

  # All twelve context reads in one jq (NUL-separated); each was a process
  # re-parsing the ~150 KB context. The wellbeing value follows
  # score_value_text: "Unavailable" unless the score is available.
  local -a f
  mapfile -d '' -t f < <(printf '%s' "$context_json" | jq -j '
    .today.scores.digital_wellbeing_score as $wb
    | [ (.today.metrics.eye_strain_risk // "Low"),
        (.today.metrics.cognitive_load_score // "—"),
        (.today.metrics.circadian_phase // "Unknown"),
        (.today.metrics.ultradian_score // 0),
        (.today.metrics.recovery_gap_count // 0),
        (.today.metrics.attention_fragmentation_index | if . == null then "—" else (. * 10 | round / 10 | tostring) end),
        (if $wb.available == true then ($wb.value | round | tostring) else "Unavailable" end),
        ($wb.confidence // "Medium"),
        ($wb.untracked_percent // 0),
        (if (.today.metrics.cognitive_load_score // 0) > 50 then "y" else "n" end),
        (if (.today.metrics.cognitive_load_score // 0) > 70 then "y" else "n" end)
      ] | map(tostring) | join(([0] | implode))')
  eye_risk="${f[0]}"; cog_load="${f[1]}"; circ_phase="${f[2]}"; ultr_score="${f[3]}"
  rec_gaps="${f[4]}"; afi="${f[5]}"; wellbeing_val="${f[6]}"; confidence="${f[7]}"; untracked="${f[8]}"

  local eye_color="$SUCCESS_COLOR"
  [ "$eye_risk" = "Moderate" ] && eye_color="$WARNING_COLOR"
  [ "$eye_risk" = "High" ] && eye_color="$ERROR_COLOR"

  local cog_color="$SUCCESS_COLOR"
  [ "${f[9]}" = "y" ] && cog_color="$WARNING_COLOR"
  [ "${f[10]}" = "y" ] && cog_color="$ERROR_COLOR"

  # One encoding per kind of value: bounded ratios get a bar the eye reads by
  # length, small counts get pips it reads by counting, rank labels carry the
  # severity in their colour. The number stays beside the bar for anyone who
  # wants it, but nothing depends on reading it.
  local bar_w=26
  local wb_bar_value="$wellbeing_val"
  [ "$wb_bar_value" = "—" ] && wb_bar_value=0
  local cog_bar_value="$cog_load"
  [ "$cog_bar_value" = "—" ] && cog_bar_value=0

  local eye_level=1
  [ "$eye_risk" = "Moderate" ] && eye_level=2
  [ "$eye_risk" = "High" ] && eye_level=3

  # Wellbeing is a "higher is better" score, so the ladder runs the other way.
  local wb_color="$ERROR_COLOR"
  [ "$wb_bar_value" -ge 34 ] && wb_color="$WARNING_COLOR"
  [ "$wb_bar_value" -ge 67 ] && wb_color="$SUCCESS_COLOR"

  # The driver moved to the Wellbeing card, which has room for it unclipped.
  printf '<span foreground="%s">%-11s</span>%s  <span weight="600">%3s</span>\n' \
    "$SUBTEXT_COLOR" "Wellbeing" \
    "$(bar_markup "$wb_bar_value" 100 "$bar_w" "$wb_color" "$BASE_COLOR")" \
    "$wellbeing_val"
  printf '<span foreground="%s">%-11s</span>%s  <span weight="600">%3s</span>\n' \
    "$SUBTEXT_COLOR" "Cognitive" \
    "$(bar_markup "$cog_bar_value" 100 "$bar_w" "$cog_color" "$BASE_COLOR")" \
    "$cog_load"
  printf '<span foreground="%s">%-11s</span>%s  <span foreground="%s" weight="600">%s</span>\n' \
    "$SUBTEXT_COLOR" "Eye strain" \
    "$(bar_markup "$eye_level" 3 "$bar_w" "$eye_color" "$BASE_COLOR")" \
    "$eye_color" "$eye_risk"
  printf '<span foreground="%s">%-11s</span>%s  <span weight="600">%2s%%</span>  <span foreground="%s" size="small">conf %s</span>\n' \
    "$SUBTEXT_COLOR" "Untracked" \
    "$(bar_markup "$untracked" 100 "$bar_w" "$(severity_color "$untracked" 15 30)" "$BASE_COLOR")" \
    "$untracked" "$SUBTEXT_COLOR" "$confidence"
  printf '<span foreground="%s">%-11s</span><span weight="600">%s</span>  <span foreground="%s">·</span>  <span foreground="%s">cycles</span> %s  <span foreground="%s">·</span>  <span foreground="%s">gaps</span> %s  <span foreground="%s">·</span>  <span foreground="%s">frag</span> <span weight="600">%s</span>' \
    "$SUBTEXT_COLOR" "Rhythm" "$circ_phase" \
    "$SUBTEXT_COLOR" "$SUBTEXT_COLOR" "$(pips_markup "$ultr_score" 5 "$CYAN_COLOR")" \
    "$SUBTEXT_COLOR" "$SUBTEXT_COLOR" "$(pips_markup "$rec_gaps" 3 "$WARNING_COLOR")" \
    "$SUBTEXT_COLOR" "$SUBTEXT_COLOR" "$afi"
}

note_health_alert_color() {
  local context_json="$1"
  # One jq answers the whole question; it was three.
  if [ "$(printf '%s' "$context_json" | jq -r '
        if (.today.metrics.eye_strain_risk // "Low") == "High"
           or (.today.metrics.cognitive_load_score // 0) > 70 then "y" else "n" end')" = "y" ]; then
    printf '%s' "$ERROR_COLOR"
  else
    printf '%s' "$BASE_COLOR"
  fi
}

render_goal_gauge() {
  local current_seconds="$1"
  local target_seconds="$2"
  local ratio
  local label=""
  local action_hint=""
  
  ratio="$(jq -nr --argjson c "$current_seconds" --argjson t "$target_seconds" 'if $t <= 0 then 0 else ($c / $t) end')"
  label="$(seconds_to_short "$current_seconds") / $(seconds_to_short "$target_seconds")"
  
  local remaining_sec
  remaining_sec=$((target_seconds - current_seconds))
  if [ "$remaining_sec" -gt 0 ]; then
    local blocks_left
    blocks_left=$(( (remaining_sec + 2999) / 3000 ))
    action_hint=" • Next: 50m block ($blocks_left left)"
  else
    action_hint=" • Goal achieved!"
  fi

  printf '<span foreground="%s">%s</span>\n%s\n' \
    "$SUBTEXT_COLOR" \
    "Study target: $(format_ratio_percent "$ratio") ($label)$action_hint" \
    "$(bar_markup "$current_seconds" "$target_seconds" 28 "$SUCCESS_COLOR" "$BASE_COLOR")"
}

action_row_markup() {
  local label="$1"
  local hint="${2:-}"
  if [ -n "$hint" ]; then
    printf '<span weight="600">%s</span>&#10;<span foreground="%s" size="small">%s</span>' \
      "$(escape_markup "$label")" \
      "$SUBTEXT_COLOR" \
      "$(escape_markup "$hint")"
  else
    printf '<span weight="600">%s</span>' "$(escape_markup "$label")"
  fi
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

# One jq per call instead of two; an empty score is "Unavailable" as before.
score_value_text() {
  local score_json="$1"
  if [ -z "$score_json" ]; then
    printf 'Unavailable\n'
    return 0
  fi
  printf '%s\n' "$(printf '%s' "$score_json" | jq -r '
    if .available == true then (.value | round | tostring) else "Unavailable" end')"
}

score_subtext() {
  local score_json="$1"
  if [ -z "$score_json" ]; then
    printf '\n'
    return 0
  fi
  printf '%s\n' "$(printf '%s' "$score_json" | jq -r '
    if .available == true then .label else (.reason // "Unavailable") end')"
}

render_category_bars() {
  local context_json="$1"
  local limit="${2:-0}"
  local hide_zero="${3:-false}"
  local output=""
  local max_seconds=0
  local name=""
  local seconds=0
  local share=0
  local hide_zero_json='false'

  if [ "$hide_zero" = "true" ]; then
    hide_zero_json='true'
  fi

  max_seconds="$(printf '%s' "$context_json" | jq -r \
    --argjson limit "$limit" \
    --argjson hide_zero "$hide_zero_json" '
      .today.categories.breakdown
      | if $hide_zero then map(select(.seconds > 0)) else . end
      | if $limit > 0 then .[:$limit] else . end
      | ([.[].seconds] | max) // 0
    ')"

  while IFS=$'\t' read -r name seconds share; do
    [ -n "$name" ] || continue
    # Same hue the 24-hour strip gives this category, so a colour means one
    # category across the whole dashboard instead of "this is a bar".
    output+="$(printf '%s  %s  %6s  %s' \
      "$(pad_right "$name" 13)" \
      "$(bar_markup "$seconds" "$max_seconds" 20 "$(category_color "$name")" "$BASE_COLOR")" \
      "$(seconds_to_short "$seconds")" \
      "$(format_ratio_percent "$share")")"$'\n'
  done < <(
    printf '%s' "$context_json" | jq -r \
      --argjson limit "$limit" \
      --argjson hide_zero "$hide_zero_json" '
        .today.categories.breakdown
        | if $hide_zero then map(select(.seconds > 0)) else . end
        | if $limit > 0 then .[:$limit] else . end
        | .[]
        | [ .name, (.seconds | tostring), (.share | tostring) ]
        | @tsv
      '
  )

  if [ -z "$output" ]; then
    printf '%s\n' "$(kv_markup "Categories" "No category data yet")"
  else
    printf '%s' "${output%$'\n'}"
  fi
}

render_app_usage_timeline() {
  local context_json="$1"
  local limit="${2:-6}"
  local output=""
  local name=""
  local category=""
  local seconds=0
  local share=0
  local peak_label=""
  local peak_index=0
  local slots_json=""
  local label=""
  local timeline=""

  while IFS=$'\t' read -r name category seconds share peak_label peak_index slots_json; do
    [ -n "$name" ] || continue
    label="$(clip_text "$name" 16)"
    timeline="$(sparkline_from_json "$slots_json" "$peak_index")"
    output+="$(printf '<span foreground="%s">%s</span> %s  <span weight="600">%6s</span> <span foreground="%s">%4s</span> <span foreground="%s" size="small">%s · busy %s</span>' \
      "$TEXT_COLOR" \
      "$(escape_markup "$(pad_right "$label" 16)")" \
      "$timeline" \
      "$(seconds_to_short "$seconds")" \
      "$SUBTEXT_COLOR" \
      "$(format_ratio_percent "$share")" \
      "$SUBTEXT_COLOR" \
      "$(escape_markup "$category")" \
      "$(escape_markup "$peak_label")")"$'\n'
  done < <(
    printf '%s' "$context_json" | jq -r \
      --argjson limit "$limit" '
        def pad2:
          tostring
          | if length < 2 then "0" + . else . end;
        def hour_label($index):
          if $index < 0 then
            "no peak"
          else
            (($index | tonumber) | pad2) + ":00"
          end;
        def hourly($slots):
          [range(0; 24) as $hour | (($slots[$hour * 2] // 0) + ($slots[($hour * 2) + 1] // 0))];
        (.today.total_seconds // 0) as $total
        | .today.app_entries
        | map(select((.seconds // 0) > 0))
        | .[:$limit][]
        | (.slots_30m | if length == 48 then . else ([range(0; 48)] | map(0)) end) as $slots30
        | (hourly($slots30)) as $slots
        | ([ $slots | to_entries[] | select(.value > 0) ] | if length == 0 then {key:-1, value:0} else max_by(.value) end) as $peak
        | [
            (.name // .key),
            (.category // "Unknown"),
            ((.seconds // 0) | tostring),
            (if $total > 0 then ((.seconds // 0) / $total) else 0 end | tostring),
            hour_label($peak.key),
            (($peak.key // -1) | tostring),
            ($slots | @json)
          ]
        | @tsv
      '
  )

  if [ -z "$output" ]; then
    printf '%s\n' "$(kv_markup "App usage" "No app data yet")"
  else
    printf '<span foreground="%s" size="small">                   00   06   12   18   24</span>\n%s' \
      "$SUBTEXT_COLOR" \
      "${output%$'\n'}"
  fi
}

render_top_app_bars() {
  local context_json="$1"
  local limit="${2:-5}"
  local output=""
  local name=""
  local category=""
  local seconds=0
  local share=0
  local max_seconds=0

  max_seconds="$(printf '%s' "$context_json" | jq -r \
    --argjson limit "$limit" '
      .today.app_entries
      | map(select((.seconds // 0) > 0))
      | .[:$limit]
      | ([.[].seconds] | max) // 0
    ')"

  # Same shape as render_app_usage_timeline below: one jq pass emits the row as
  # TSV, the loop forks nothing. This previously spent four jq processes per app
  # and re-read the constant .today.total_seconds inside the loop, nesting a
  # fifth process inside the fourth.
  while IFS=$'\t' read -r name category seconds share; do
    [ -n "$name" ] || continue
    output+="$(printf '<span foreground="%s">%s</span> %s  <span weight="600">%6s</span> <span foreground="%s">%4s</span> <span foreground="%s" size="small">%s</span>' \
      "$TEXT_COLOR" \
      "$(escape_markup "$(pad_right "$(clip_text "$name" 18)" 18)")" \
        "$(bar_markup "$seconds" "$max_seconds" 14 "$ACCENT_COLOR" "$BASE_COLOR")" \
      "$(seconds_to_short "$seconds")" \
      "$SUBTEXT_COLOR" \
      "$(format_ratio_percent "$share")" \
      "$SUBTEXT_COLOR" \
      "$(escape_markup "$category")")"$'\n'
  done < <(
    printf '%s' "$context_json" | jq -r \
      --argjson limit "$limit" '
        (.today.total_seconds // 0) as $total
        | .today.app_entries
        | map(select((.seconds // 0) > 0))
        | .[:$limit][]
        | [
            (.name // .key),
            (.category // "Unknown"),
            ((.seconds // 0) | tostring),
            (if $total > 0 then ((.seconds // 0) / $total) else 0 end | tostring)
          ]
        | @tsv
      '
  )

  if [ -z "$output" ]; then
    printf '%s\n' "$(kv_markup "Apps" "No tracked app data yet")"
  else
    printf '%s' "${output%$'\n'}"
  fi
}

render_priority_insights() {
  local context_json="$1"
  local limit="${2:-3}"
  local output=""
  local text=""

  while IFS= read -r text; do
    [ -n "$text" ] || continue
    output+="• $(escape_markup "$text")"$'\n'
  done < <(
    printf '%s' "$context_json" | jq -r \
      --argjson limit "$limit" '
        (.insights.all // [])
        | if length == 0 then
            ["No major insight available yet."]
          else
            map(.text)[:$limit]
          end
        | .[]
      '
  )

  printf '%s' "${output%$'\n'}"
}

render_baseline_summary() {
  local context_json="$1"
  local active_delta active_avg focus_delta frag_delta study_delta

  # Five context reads in one jq (NUL-separated) instead of five processes.
  local -a f
  mapfile -d '' -t f < <(printf '%s' "$context_json" | jq -j '
    [ (.baseline.deltas.total_seconds.vs_yesterday // 0),
      (.baseline.deltas.total_seconds.vs_avg7 // ""),
      (.baseline.deltas.focus_score.vs_avg7 // ""),
      (.baseline.deltas.fragmentation_score.vs_avg7 // ""),
      (.baseline.deltas.study_ratio.vs_avg7 // "")
    ] | map(tostring) | join(([0] | implode))')
  active_delta="${f[0]}"; active_avg="${f[1]}"; focus_delta="${f[2]}"; frag_delta="${f[3]}"; study_delta="${f[4]}"

  printf '%s\n%s\n%s\n%s' \
    "$(kv_markup "Compared with yesterday" "$(delta_label_seconds "$active_delta")")" \
    "$(kv_markup "Active time vs 7-day" "$( [ -n "$active_avg" ] && delta_label_seconds "$(round_number "$active_avg")" || printf 'Unavailable' )")" \
    "$(kv_markup "Focus vs 7-day" "$( [ -n "$focus_delta" ] && format_score_delta "$focus_delta" || printf 'Unavailable' )")" \
    "$(kv_markup "Study vs 7-day" "$( [ -n "$study_delta" ] && format_ratio_points_delta "$study_delta" || printf 'Unavailable' )")"

  if [ -n "$frag_delta" ]; then
    printf '\n%s' "$(kv_markup "Fragmentation vs 7-day" "$(format_score_delta "$frag_delta")")"
  fi
}

render_focus_breakdown() {
  local context_json="$1"
  # Value and label of the four scores from one jq (NUL-separated), with the
  # same rules as score_value_text / score_subtext; it was twelve processes.
  local -a f
  mapfile -d '' -t f < <(printf '%s' "$context_json" | jq -j '
    def score_value: if .available == true then (.value | round | tostring) else "Unavailable" end;
    def score_label: if .available == true then .label else (.reason // "Unavailable") end;
    [ (.today.scores.focus_score | score_value, score_label),
      (.today.scores.fragmentation_score | score_value, score_label),
      (.today.scores.distraction_load | score_value, score_label),
      (.today.scores.daily_consistency_score | score_value, score_label)
    ] | map(tostring) | join(([0] | implode))')

  printf '%s\n%s\n%s\n%s' \
    "$(kv_markup_aligned 18 "Focus" "${f[0]}/100 • ${f[1]}")" \
    "$(kv_markup_aligned 18 "Fragmentation" "${f[2]}/100 • ${f[3]}")" \
    "$(kv_markup_aligned 18 "Distraction load" "${f[4]}/100 • ${f[5]}")" \
    "$(kv_markup_aligned 18 "Consistency" "${f[6]}/100 • ${f[7]}")"
}

render_behavior_summary() {
  local context_json="$1"
  local longest current deep short top_label top_count switch_rate

  # All nine context reads in one jq (NUL-separated); each was a process
  # re-parsing the ~150 KB context.
  local -a f
  mapfile -d '' -t f < <(printf '%s' "$context_json" | jq -j '
    [ (.today.metrics.longest_focus_block_seconds // 0),
      (.today.metrics.current_focus_block_seconds // 0),
      (.today.metrics.deep_focus_block_count // 0),
      (.today.metrics.short_focus_block_count // 0),
      (.today.metrics.top_transition_label // "None yet"),
      (.today.metrics.top_transition_count // 0),
      (.today.metrics.switch_rate // ""),
      (.today.metrics.safe_total_seconds // .today.total_seconds // 0),
      (.today.behavior.classified_transitions.cross_context // 0),
      (.baseline.deltas.switch_rate.avg7 // "")
    ] | map(tostring) | join(([0] | implode))')
  longest="${f[0]}"; current="${f[1]}"; deep="${f[2]}"; short="${f[3]}"
  top_label="${f[4]}"; top_count="${f[5]}"; switch_rate="${f[6]}"

  # An arrow glyph instead of "->" so the direction is a mark, not two
  # characters the reader parses as text.
  if [ "$top_label" != "None yet" ]; then
    top_label="${top_label// -> / → }"
  fi

  local bar_w=26
  local day_seconds blocks_total cross_count
  day_seconds="${f[7]}"
  cross_count="${f[8]}"
  blocks_total=$((deep + short))

  # Two block lengths against the same day-long scale, so "best" and "right now"
  # are comparable by eye instead of by subtracting two durations. The deep
  # ratio is the line that matters and it was the one the reader had to compute:
  # "2 deep • 28 short" is a fraction written as two numbers.
  local deep_color="$SUCCESS_COLOR"
  [ "$blocks_total" -gt 0 ] && [ $((deep * 100 / blocks_total)) -lt 25 ] && deep_color="$WARNING_COLOR"
  [ "$blocks_total" -gt 0 ] && [ $((deep * 100 / blocks_total)) -lt 10 ] && deep_color="$ERROR_COLOR"

  printf '<span foreground="%s">%-11s</span>%s  <span weight="600">%s</span>\n' \
    "$SUBTEXT_COLOR" "Best block" \
    "$(bar_markup "$longest" "$day_seconds" "$bar_w" "$CYAN_COLOR" "$BASE_COLOR")" \
    "$(seconds_to_short "$longest")"
  printf '<span foreground="%s">%-11s</span>%s  <span weight="600">%s</span>\n' \
    "$SUBTEXT_COLOR" "Right now" \
    "$(bar_markup "$current" "$day_seconds" "$bar_w" "$CYAN_COLOR" "$BASE_COLOR")" \
    "$(seconds_to_short "$current")"
  printf '<span foreground="%s">%-11s</span>%s  <span weight="600">%s deep</span> <span foreground="%s" size="small">· %s short</span>\n' \
    "$SUBTEXT_COLOR" "Deep ratio" \
    "$(bar_markup "$deep" "$blocks_total" "$bar_w" "$deep_color" "$BASE_COLOR")" \
    "$deep" "$SUBTEXT_COLOR" "$short"
  if [ "$top_count" -gt 0 ]; then
    printf '<span foreground="%s">%-11s</span>%s  <span weight="600">%s×</span>\n' \
      "$SUBTEXT_COLOR" "Top switch" \
      "$(escape_markup "$(clip_text "$top_label" 30)")" "$top_count"
  else
    printf '<span foreground="%s">%-11s</span><span foreground="%s">None yet</span>\n' \
      "$SUBTEXT_COLOR" "Top switch" "$SUBTEXT_COLOR"
  fi
  # Pips are scaled against this user's own 7-day average, not a fixed ceiling.
  # A constant cap saturates: a 10/h ceiling shows ten filled pips every day for
  # someone who averages 35/h, which encodes nothing. Against the baseline the
  # same marks answer "busier or calmer than usual".
  local switch_avg switch_pips switch_note
  switch_avg="${f[9]}"
  if [ -n "$switch_avg" ]; then
    # Rates are non-negative, so int() is the floor jq computed here.
    switch_pips="$(awk -v r="${switch_rate:-0}" -v a="$switch_avg" \
      'BEGIN { if (a <= 0) print 0; else print int(r * 10 / a) }')"
    switch_note="vs usual $(format_decimal_label "$switch_avg" "/h")"
  else
    switch_pips=0
    switch_note="$(format_decimal_label "$switch_rate" "/h")"
  fi
  # The rate itself is on the App switching card; showing it again here is the
  # duplication this pass removes, so the row carries the comparison instead.
  printf '<span foreground="%s">%-11s</span>%s  <span weight="600">%s</span>  <span foreground="%s" size="small">%s cross-context</span>' \
    "$SUBTEXT_COLOR" "Switching" \
    "$(pips_markup "$switch_pips" 10 "$WARNING_COLOR")" \
    "$switch_note" \
    "$SUBTEXT_COLOR" "$cross_count"
}

render_focus_vs_baseline() {
  local context_json="$1"
  local output=""
  local metrics rows

  rows="$(
    printf '%s' "$context_json" \
      | jq -r '
        [
          ["Session density", .today.metrics.session_density, .baseline.averages.session_density],
          ["Switch rate", .today.metrics.switch_rate, .baseline.averages.switch_rate],
          ["Goal-aligned activity", .today.metrics.productive_ratio_v1, .baseline.averages.productive_ratio_v1],
          ["Browser ambiguity ratio", .today.metrics.browser_ambiguity_ratio, .baseline.averages.browser_ambiguity_ratio]
        ]
        | .[]
        | @tsv
      '
  )"

  while IFS=$'\t' read -r label current avg; do
    [ -n "$label" ] || continue
    if [ "$current" = "null" ]; then
      output+="$(kv_markup_aligned 24 "$label" "Unavailable")"$'\n'
      continue
    fi
    if [ "$label" = "Session density" ] || [ "$label" = "Switch rate" ]; then
      metrics="$(format_rate_with_avg "$current" "$avg")"
    else
      metrics="$(format_ratio_with_avg "$current" "$avg")"
    fi
    output+="$(kv_markup_aligned 24 "$label" "$metrics")"$'\n'
  done <<< "$rows"

  printf '%s' "${output%$'\n'}"
}

render_study_summary() {
  local context_json="$1"
  local study_seconds study_ratio active_label focus_window

  # All nine context reads in one jq (NUL-separated); it was up to nine.
  local -a f
  mapfile -d '' -t f < <(printf '%s' "$context_json" | jq -j '
    [ .today.study_seconds,
      .today.metrics.study_ratio,
      .today.metrics.focus_window,
      .study_active.active,
      (.study_active.mode // ""),
      (.study_active.current_session // ""),
      (.study_active.planned_sessions // ""),
      (.study_active.remaining_total_seconds // ""),
      (.study_active.elapsed_seconds // 0)
    ] | map(tostring) | join(([0] | implode))')
  study_seconds="${f[0]}"
  study_ratio="${f[1]}"
  focus_window="${f[2]}"

  if [ "${f[3]}" = "true" ]; then
    local mode current planned left elapsed

    mode="${f[4]}"
    current="${f[5]}"
    planned="${f[6]}"
    left="${f[7]}"
    elapsed="${f[8]}"

    if [ -n "$mode" ]; then
      active_label="$mode"
    else
      active_label="Active"
    fi

    if [ -n "$current" ] && [ -n "$planned" ] && [ "$planned" != "null" ]; then
      active_label+=" ($current/$planned)"
    fi

    if [ -n "$left" ] && [ "$left" != "null" ]; then
      active_label+=" • $(seconds_to_short "$left") left"
    else
      active_label+=" • $(seconds_to_short "$elapsed")"
    fi
  else
    active_label="Idle"
  fi

  printf '%s\n%s\n%s' \
    "$(kv_markup "Study today" "$(seconds_to_short "$study_seconds") • $(format_ratio_percent "$study_ratio")")" \
    "$(kv_markup "Timer" "$active_label")" \
    "$(kv_markup "Peak density window" "$focus_window")"
}

render_confidence_breakdown() {
  local context_json="$1"
  local conf mapped_pct unknown_time browser_pct unknown_raw

  # Every figure of this block from one jq (NUL-separated): it was twelve
  # processes, four of them re-parsing the ~150 KB context.
  local -a f
  mapfile -d '' -t f < <(printf '%s' "$context_json" | jq -j '
    (.data_quality.known_category_ratio // 0) as $mapped
    | (.today.categories.seconds["Unknown"] // 0) as $unknown
    | (.data_quality.browser_ambiguity_ratio // 0) as $browser
    | (.today.metrics.safe_total_seconds // .today.total_seconds // 0) as $t
    | [ (.data_quality.model_confidence // "Unknown"),
        $unknown,
        (($mapped * 100 | round | tostring) + "%"),
        (($browser * 100 | round | tostring) + "%"),
        (if $mapped >= 0.85 then "Good" else "\u2193 below 85% threshold" end),
        (if $browser < 0.30 then "OK" else "\u2193 high ambiguity" end),
        (if $unknown < 1800 then "OK" else "\u2193 significant" end),
        ($mapped * 100 | round),
        ($browser * 100 | round),
        ((if $t > 0 then (($unknown * 100 / $t) | round) else 0 end) | if . > 100 then 100 else . end)
      ] | map(tostring) | join(([0] | implode))')
  conf="${f[0]}"
  unknown_raw="${f[1]}"
  mapped_pct="${f[2]}"
  unknown_time="$(seconds_to_short "$unknown_raw")"
  browser_pct="${f[3]}"

  local mapped_status browser_status unknown_status
  mapped_status="${f[4]}"
  browser_status="${f[5]}"
  unknown_status="${f[6]}"

  # These three bars used to be blue, amber and purple -- one hue per metric, so
  # colour said "which row is this" while all three rows carried the same "this
  # is dragging the score down" arrow. They run through severity_color now, the
  # same ladder the summary view uses, so a hue means the same thing everywhere.
  # App mapping is "higher is better", so its ladder is inverted.
  local mapped_pct_num unknown_pct_num browser_pct_num
  mapped_pct_num="${f[7]}"
  browser_pct_num="${f[8]}"
  # Share of the tracked day, not seconds against a two-hour ceiling. The old
  # cap saturated: 3h27m and 5h29m are two hours apart and both drew a full bar,
  # so the row could not distinguish a bad day from a much worse one. This also
  # puts all three drivers on one scale -- percent of the day -- so their bar
  # lengths are comparable with each other.
  unknown_pct_num="${f[9]}"

  printf '%s\n%s\n%s\n%s\n%s' \
    "$(kv_markup_aligned 18 "Model confidence" "$conf")" \
    "$(kv_markup_raw_value_aligned 18 "App mapping" "$(printf '%s  %6s  %s' "$(bar_markup "$mapped_pct_num" 100 14 "$(severity_color "$((100 - mapped_pct_num))" 15 40)" "$BASE_COLOR")" "${mapped_pct}" "${mapped_status}")")" \
    "$(kv_markup_raw_value_aligned 18 "Unknown activity" "$(printf '%s  %6s  %s' "$(bar_markup "$unknown_pct_num" 100 14 "$(severity_color "$unknown_pct_num" 25 50)" "$BASE_COLOR")" "${unknown_time}" "${unknown_status}")")" \
    "$(kv_markup_raw_value_aligned 18 "Browser ambiguity" "$(printf '%s  %6s  %s' "$(bar_markup "$browser_pct_num" 100 14 "$(severity_color "$browser_pct_num" 30 60)" "$BASE_COLOR")" "${browser_pct}" "${browser_status}")")" \
    "$(kv_markup_aligned 18 "Tip" "Map top unknown app to raise score reliability.")"
}


render_unknown_apps() {
  local context_json="$1"
  local output="" mapping_note=""

  # Compute projected coverage if we map the top unknown app
  # The projection figures from one jq (NUL-separated) instead of seven.
  local top_name top_projected top_is_big
  local current_pct cur_val top_val max_val
  local -a f
  mapfile -d '' -t f < <(printf '%s' "$context_json" | jq -j '
    (.today.metrics.safe_total_seconds // 1) as $total
    | (.today.metrics.known_category_ratio // 0) as $mapped
    | (.today.app_entries | map(select(.category == "Unknown")) | sort_by(-.seconds)) as $unknown
    | (if ($unknown | length) > 0 then $unknown[0].seconds else 0 end) as $top
    | [ (if ($unknown | length) > 0 then $unknown[0].name else "" end),
        ((($mapped * $total + $top) / $total * 100 | round | tostring) + "%"),
        ((.data_quality.known_category_ratio // 0) * 100 | round | tostring),
        ((.data_quality.known_category_ratio // 0) * 100 | round),
        (($mapped * $total + $top) / $total * 100 | round),
        ($top > 600)
      ] | map(tostring) | join(([0] | implode))')
  top_name="${f[0]}"; top_projected="${f[1]}"; current_pct="${f[2]}"
  cur_val="${f[3]}"; top_val="${f[4]}"; top_is_big="${f[5]}"
  max_val=100

  if [ -n "$top_name" ] && [ "$top_name" != "null" ] && [ "$top_is_big" = "true" ]; then
    # Current coverage takes the severity ladder, inverted because more mapped
    # is better. The projection stays on the decorative accent: it used to be
    # green, which in every other block means "inside the safe threshold", so
    # the same hue was carrying two unrelated meanings. The projected bar is not
    # a state at all -- it is what would happen if you acted.
    mapping_note="$(kv_markup_raw_value_aligned 22 "Current coverage" "$(printf '%s  %6s' "$(bar_markup "$cur_val" "$max_val" 14 "$(severity_color "$((100 - cur_val))" 15 40)" "$BASE_COLOR")" "${current_pct}%")")"$'\n'
    mapping_note+="$(kv_markup_raw_value_aligned 22 "+ Map \"$(clip_text "$top_name" 14)\"" "$(printf '%s  %6s' "$(bar_markup "$top_val" "$max_val" 14 "$ACCENT_COLOR" "$BASE_COLOR")" "~${top_projected}")")"$'\n'
  fi

  while IFS=$'\t' read -r name seconds impact; do
    [ -n "$name" ] || continue
    local tag=""
    [ "$impact" = "high" ] && tag=" ●"
    output+="$(kv_markup_aligned 22 "$(clip_text "${name}${tag}" 22)" "$(printf '%6s' "$(seconds_to_short "$seconds")")")"$'\n'
  done < <(
    printf '%s' "$context_json" \
      | jq -r '
        (.today.metrics.safe_total_seconds // 1) as $total
        | .today.app_entries
        | map(select(.category == "Unknown"))
        | .[:6][]
        | [.name, (.seconds | tostring), (if (.seconds / $total) > 0.10 then "high" else "normal" end)]
        | @tsv
      '
  )

  if [ -z "$output" ]; then
    printf '%s\n' "$(kv_markup "Unknown apps" "All visible apps are mapped.")"
  else
    printf '%s' "${mapping_note}${output%$'\n'}"
  fi
}

build_navigation_json() {
  local view="$1"
  local target_date="$2"
  local today next_date
  today="$(date +%F)"
  next_date=""

  if [ "$target_date" != "$today" ]; then
    next_date="$(date -d "$target_date +1 day" +%F)"
  fi

  jq -n \
    --arg current_view "$view" \
    --arg target_date "$target_date" \
    --arg previous_date "$(date -d "$target_date -1 day" +%F)" \
    --arg next_date "$next_date" \
    --arg today "$today" \
    '{
      current_view: $current_view,
      target_date: $target_date,
      previous_date: $previous_date,
      next_date: $next_date,
      today: $today,
      views: [
        {id:"summary", key:"T", label:"Today"},
        {id:"activity", key:"A", label:"App timeline"},
        {id:"health", key:"F", label:"Focus & strain"},
        {id:"timer", key:"S", label:"Study timer"}
      ]
    }'
}

build_view_payload() {
  local view="$1"
  local context_json="$2"
  local target_date subtitle meta title note_text navigation_json
    local updated_time total_seconds study_ratio focus_json frag_json focus_value frag_value
    local longest_focus_seconds switch_rate_label
  local top_category peak_window main_insight summary_active summary_study_ratio
  local card1_label card1_value card1_sub
  local card2_label card2_value card2_sub
  local card3_label card3_value card3_sub
  local card4_label card4_value card4_sub
  local primary_title primary_body chart_b_title chart_b_body chart_c_title chart_c_body insight_title insight_body

  # The scalars every view needs, from one jq: this used to be eleven jq
  # processes, each re-parsing the whole context. NUL-separated because an
  # insight text may contain newlines.
  local -a scalars
  mapfile -d '' -t scalars < <(printf '%s' "$context_json" | jq -j '
    [ .target_date,
      .today.updated_at,
      .today.total_seconds,
      .today.metrics.study_ratio,
      (.today.scores.focus_score | tojson),
      (.today.scores.fragmentation_score | tojson),
      (.today.metrics.longest_focus_block_seconds // 0),
      (.today.metrics.switch_rate // ""),
      .today.categories.top_category,
      .today.metrics.peak_slot_label,
      (.insights.main.text // "No major insight available yet.")
    ] | map(tostring) | join(([0] | implode))')
  target_date="${scalars[0]}"
  updated_time="$(updated_time_label "${scalars[1]}")"
  total_seconds="${scalars[2]}"
  study_ratio="${scalars[3]}"
  focus_json="${scalars[4]}"
  frag_json="${scalars[5]}"
    focus_value="$(score_value_text "$focus_json")"
    frag_value="$(score_value_text "$frag_json")"
    longest_focus_seconds="${scalars[6]}"
    switch_rate_label="$(format_decimal_label "${scalars[7]}" "/h" "n/a")"
    top_category="${scalars[8]}"
  peak_window="${scalars[9]}"
  main_insight="${scalars[10]}"
  summary_active="$(seconds_to_compact "$total_seconds")"
  summary_study_ratio="$(format_ratio_percent "$study_ratio")"
  navigation_json="$(build_navigation_json "$view" "$target_date")"

  case "$view" in
    summary)
      title="Today"
      subtitle="$(date -d "$target_date" '+%A, %d %B %Y')"
      meta="$(kv_markup "Updated" "$updated_time")"
      card1_label="Screen time"
      card1_value="$summary_active"
      card1_sub="Busiest at $peak_window"
      card2_label="Best focus block"
      card2_value="$(seconds_to_short "$longest_focus_seconds")"
      # Not the deep-block count: the Deep ratio row already carries it, as a bar
      # that shows the ratio this number cannot. What no other element says is
      # how much of the tracked day that single best block accounts for.
      # The branch's eight context reads in one jq (NUL-separated).
      local -a s
      mapfile -d '' -t s < <(printf '%s' "$context_json" | jq -j \
        --argjson block "$longest_focus_seconds" '
        [ ((.today.metrics.safe_total_seconds // .today.total_seconds // 0) as $t
            | if $t > 0 then (($block * 100 / $t) | round | tostring) + "% of tracked day"
              else "no tracked time yet" end),
          (.today.switch_count // 0),
          (.today.scores.digital_wellbeing_score | tojson),
          ((.today.scores.digital_wellbeing_score.drivers // [])
            | if length > 0 then
                (.[0] | "\(if .type == "positive" then "+" else "−" end) \(.name) (\(.impact))")
              else "Balanced baseline" end),
          .today.study_seconds,
          .today.metrics.study_goal_seconds,
          .study_active.active,
          .study_active.elapsed_seconds
        ] | map(tostring) | join(([0] | implode))')
      card2_sub="${s[0]}"
      card3_label="App switching"
      card3_value="$switch_rate_label"
      card3_sub="${s[1]} switches today"
      card4_label="Wellbeing"
      local _wb_label
      _wb_label="$(score_subtext "${s[2]}")"
      card4_value="$_wb_label"
      # Not the two scores: the How-you-are-doing bars carry both, and a bar
      # says "how far along the range" in a way "34/100" cannot. What no bar can
      # say is *why*, so the card takes the driver -- with room for it, instead
      # of the 30-character stub the panel row was clipping it to.
      card4_sub="${s[3]}"

      primary_title="Today at a glance"
      primary_body="$(printf '%s\n\n<span foreground=\"%s\" weight=\"600\">24-Hour Activity Strip</span>\n%s\n\n<span foreground=\"%s\" weight=\"600\">Top Apps Today</span>\n%s' \
        "$(render_goal_gauge "${s[4]}" "${s[5]}")" \
        "$ACCENT_COLOR" \
        "$(render_hero_day_strip "$context_json")" \
        "$ACCENT_COLOR" \
        "$(render_top_app_bars "$context_json" 4)")"

      chart_b_title="How you are doing"
      chart_b_body="$(render_digital_health "$context_json")"

      chart_c_title="Focus pattern"
      chart_c_body="$(render_behavior_summary "$context_json")"

      insight_title="What stands out"
      insight_body="$(printf '%s\n\n<span foreground=\"%s\" weight=\"600\">Compared with your usual week</span>\n%s' \
        "$(render_priority_insights "$context_json" 3)" \
        "$ACCENT_COLOR" \
        "$(render_baseline_summary "$context_json")")"

      local study_status
      if [ "${s[6]}" = "true" ]; then
        study_status="Study session: $(seconds_to_short "${s[7]}") active."
      else
        study_status="Tracking Mode: Normal (Study inactive)."
      fi
      # Only the tracking mode survives here. The three facts that used to
      # follow it -- busiest window, best focus block, wellbeing label -- are all
      # already on screen above, two of them inside the stat cards, so the line
      # restated them without condensing anything.
      note_text="$study_status"
      ;;

    activity)
      title="App timeline"
      subtitle="$(date -d "$target_date" '+%A, %d %B %Y')"
      # The branch's eight context reads in one jq (NUL-separated).
      local -a a
      mapfile -d '' -t a < <(printf '%s' "$context_json" | jq -j '
        [ .today.categories.top_category,
          .today.categories.top_category_seconds,
          (.today.metrics.active_slot_count | tostring),
          .today.metrics.peak_slot_label,
          .today.metrics.peak_slot_seconds,
          .today.study_seconds,
          (.today.raw.slots_30m | tojson),
          .today.metrics.focus_window
        ] | map(tostring) | join(([0] | implode))')
      meta="$(kv_markup "Main category" "${a[0]}")"
      card1_label="Main category"
      card1_value="$(humanize_class "${a[0]}")"
      card1_sub="$(seconds_to_short "${a[1]}")"
      card2_label="Active half-hours"
      card2_value="${a[2]}"
      card2_sub="30-minute blocks"
      card3_label="Busiest 30-min"
      card3_value="${a[3]}"
      card3_sub="$(seconds_to_short "${a[4]}") active"
      card4_label="Study share"
      card4_value="$(format_ratio_percent "$study_ratio")"
      card4_sub="$(seconds_to_short "${a[5]}") total"
      
      primary_title="Apps across the day"
      primary_body="$(render_app_usage_timeline "$context_json" 8)"
      
      chart_b_title="Busy hours"
      chart_b_body="$(render_timeline_chart "${a[6]}" "Densest 90-min window: ${a[7]}")"$'\n'"$(kv_markup "Resolution" "Chart: 1-hour bins  |  Cards: 30-min  |  Collected: 5-min")"
      
      chart_c_title="Category breakdown"
      chart_c_body="$(render_category_bars "$context_json" 6 true)"
      
      insight_title="Top app transitions"
      insight_body="$(render_transition_bars "$context_json" 5)"
      note_text="Updated from the focused window every 5 minutes."
      ;;

    health)
      title="Focus & strain"
      subtitle="$(date -d "$target_date" '+%A, %d %B %Y')"
      # The branch's seven context reads in one jq (NUL-separated).
      local -a h
      mapfile -d '' -t h < <(printf '%s' "$context_json" | jq -j '
        [ ("Model confidence: " + (.data_quality.model_confidence // "Unknown")  + "  •  " + (if .data_quality.schema_ready then "v2 data" else "Legacy data" end)),
          (.today.metrics.switch_rate // ""),
          .today.metrics.known_category_ratio,
          (.today.scores.digital_wellbeing_score | tojson),
          (.today.metrics.eye_strain_risk // "Low"),
          (.insights.by_class.quality.text // "All systems operational."),
          ((.data_quality.unknown_share * 100 | round | tostring) + "%")
        ] | map(tostring) | join(([0] | implode))')
      meta="${h[0]}"
      card1_label="Focus structure"
      card1_value="${focus_value}/100"
      card1_sub="$(score_subtext "$focus_json")"
      card2_label="Fragmentation"
      card2_value="${frag_value}/100"
      card2_sub="$(score_subtext "$frag_json")"
      card3_label="App switching"
      card3_value="$(format_decimal_label "${h[1]}" "/h")"
      card3_sub="Switches per hour"
      card4_label="Mapped apps"
      card4_value="$(format_ratio_percent "${h[2]}")"
      card4_sub="Share with known type"
      
      primary_title="What the scores mean"
      primary_body="$(printf '%s\n\n<span foreground=\"%s\" weight=\"600\">Compared with your usual week</span>\n%s' \
        "$(render_focus_breakdown "$context_json")" \
        "$ACCENT_COLOR" \
        "$(render_focus_vs_baseline "$context_json")")"
        
      local _wb_score_health _wb_label_health
      _wb_score_health="$(score_value_text "${h[3]}")"
      _wb_label_health="$(score_subtext "${h[3]}")"
      chart_b_title="Score drivers"
      chart_b_body="$(printf '%s\n%s\n%s' \
        "$(kv_markup_aligned 18 "Wellbeing" "$_wb_score_health/100 • $_wb_label_health")" \
        "$(kv_markup_aligned 18 "Eye strain risk" "${h[4]}")" \
        "$(render_confidence_breakdown "$context_json" 18)")"

      chart_c_title="Unsorted apps"
      chart_c_body="$(render_unknown_apps "$context_json")"

      insight_title="Main issue"
      insight_body="${h[5]}"

      local unknown_pct_note
      unknown_pct_note="${h[6]}"
      note_text="${unknown_pct_note} of today's activity is unclassified — scores reflect mapped apps only."
      ;;
    timer)
      title="Study timer"
      subtitle="$(date -d "$target_date" '+%A, %d %B %Y')"
      meta="$(kv_markup "Updated" "$updated_time")"
      card1_label="Study today"
      # The branch's eight context reads in one jq (NUL-separated).
      local -a t
      mapfile -d '' -t t < <(printf '%s' "$context_json" | jq -j '
        [ .today.study_seconds,
          .today.metrics.study_goal_progress,
          .today.metrics.study_goal_seconds,
          .study_active.active,
          .study_active.elapsed_seconds,
          (.study_active.mode // "No plan active"),
          (.today.categories.slots | tojson),
          (.insights.main.text // "Start a session to track goal velocity.")
        ] | map(tostring) | join(([0] | implode))')
      card1_value="$(seconds_to_short "${t[0]}")"
      card1_sub="Total today"
      card2_label="Target hit"
      card2_value="$(format_ratio_percent "${t[1]}")"
      card2_sub="$(seconds_to_short "${t[2]}") target"
      card3_label="Current Session"
      card3_value="$(if [ "${t[3]}" = "true" ]; then seconds_to_short "${t[4]}"; else printf "Not running"; fi)"
      card3_sub="Elapsed"
      card4_label="Timer state"
      card4_value="$(if [ "${t[3]}" = "true" ]; then printf "Running"; else printf "Idle"; fi)"
      card4_sub="${t[5]}"
      
      primary_title=""
      primary_body="$(render_goal_gauge "${t[0]}" "${t[2]}")"
      
      chart_b_title="Plan"
      chart_b_body="$(render_study_summary "$context_json")"
      
      chart_c_title="Focus rhythm"
      chart_c_body="$(render_momentum_chart "${t[6]}")"
      
      insight_title="Next step"
      insight_body="${t[7]}"
      note_text="This screen reads the background study timer service."
      ;;
    *)
      # Default fallback to Dashboard
      view="summary"
      title="Today"
      # ... (logic already handled in summary case above if this is an initial call)
      ;;
  esac

  # The context arrives on stdin: it runs past the 128 KiB a single argument
  # may hold, so --argjson is not an option for it.
  printf '%s' "$context_json" | jq \
    --arg view "$view" \
    --arg target_date "$target_date" \
    --arg title "$title" \
    --arg subtitle "$subtitle" \
    --arg meta "$meta" \
    --arg card1_label "$card1_label" \
    --arg card1_value "$card1_value" \
    --arg card1_sub "$card1_sub" \
    --arg card2_label "$card2_label" \
    --arg card2_value "$card2_value" \
    --arg card2_sub "$card2_sub" \
    --arg card3_label "$card3_label" \
    --arg card3_value "$card3_value" \
    --arg card3_sub "$card3_sub" \
    --arg card4_label "$card4_label" \
    --arg card4_value "$card4_value" \
    --arg card4_sub "$card4_sub" \
    --arg primary_title "$primary_title" \
    --arg primary_body "$primary_body" \
    --arg chart_b_title "$chart_b_title" \
    --arg chart_b_body "$chart_b_body" \
    --arg chart_c_title "$chart_c_title" \
    --arg chart_c_body "$chart_c_body" \
    --arg insight_title "$insight_title" \
    --arg insight_body "$insight_body" \
    --arg note "$note_text" \
    --arg summary_active "$summary_active" \
    --arg summary_focus "$focus_value" \
    --arg summary_fragmentation "$frag_value" \
    --arg summary_study_ratio "$summary_study_ratio" \
    --arg summary_top_category "$top_category" \
    --arg summary_peak_window "$peak_window" \
    --arg summary_main_insight "$main_insight" \
    --argjson navigation "$navigation_json" \
    '
    # The six sub-objects used to be six jq processes each re-parsing the whole
    # context; the whole context comes in once and they are picked out here.
    . as $context
    | $context.today.metrics as $metrics
    | $context.today.scores as $scores
    | $context.today.categories as $categories
    | $context.data_quality as $data_quality
    | $context.insights as $insights
    | $context.baseline as $baseline
    | {
      view: $view,
      target_date: $target_date,
      title: $title,
      subtitle: $subtitle,
      meta: $meta,
      cards: [
        {label: $card1_label, value: $card1_value, sub: $card1_sub},
        {label: $card2_label, value: $card2_value, sub: $card2_sub},
        {label: $card3_label, value: $card3_value, sub: $card3_sub},
        {label: $card4_label, value: $card4_value, sub: $card4_sub}
      ],
      primary: {title: $primary_title, body: $primary_body},
      chart_b: {title: $chart_b_title, body: $chart_b_body},
      chart_c: {title: $chart_c_title, body: $chart_c_body},
      insight: {title: $insight_title, body: $insight_body},
      note: $note,
      summary: {
        active_time: $summary_active,
        focus_score: $summary_focus,
        fragmentation_score: $summary_fragmentation,
        study_ratio: $summary_study_ratio,
        top_category: $summary_top_category,
        peak_window: $summary_peak_window,
        main_insight: $summary_main_insight
      },
      metrics: $metrics,
      scores: $scores,
      categories: $categories,
      data_quality: $data_quality,
      insights: $insights,
      baseline: $baseline,
      navigation: $navigation
    }'
}

render_theme() {
  local json="$1"
  local note_border_color
  note_border_color="$(note_health_alert_color "$json")"
  # One jq pass emits every row. Each row used to cost two processes -- one to
  # pull the field out, one inside rasi_quote to JSON-quote it -- so a single
  # theme render forked about fifty times. `tostring` before @json keeps a
  # missing field rendering as the literal "null", which is what `jq -r` piped
  # into rasi_quote produced.
  printf '%s' "$json" | jq -r '
    def cell(f): (f | tostring | @json);
    "textbox-title { content: \(cell(.title)); }",
    "textbox-subtitle { content: \(cell(.subtitle)); }",
    "textbox-meta { content: \(cell(.meta)); }",
    "textbox-card-1-label { content: \(cell(.cards[0].label)); }",
    "textbox-card-1-value { content: \(cell(.cards[0].value)); }",
    "textbox-card-1-sub { content: \(cell(.cards[0].sub)); }",
    "textbox-card-2-label { content: \(cell(.cards[1].label)); }",
    "textbox-card-2-value { content: \(cell(.cards[1].value)); }",
    "textbox-card-2-sub { content: \(cell(.cards[1].sub)); }",
    "textbox-card-3-label { content: \(cell(.cards[2].label)); }",
    "textbox-card-3-value { content: \(cell(.cards[2].value)); }",
    "textbox-card-3-sub { content: \(cell(.cards[2].sub)); }",
    "textbox-card-4-label { content: \(cell(.cards[3].label)); }",
    "textbox-card-4-value { content: \(cell(.cards[3].value)); }",
    "textbox-card-4-sub { content: \(cell(.cards[3].sub)); }",
    "textbox-primary-title { content: \(cell(.primary.title)); }",
    "textbox-primary-body { content: \(cell(.primary.body)); }",
    "textbox-chart-b-title { content: \(cell(.chart_b.title)); }",
    "textbox-chart-b-body { content: \(cell(.chart_b.body)); }",
    "textbox-chart-c-title { content: \(cell(.chart_c.title)); }",
    "textbox-chart-c-body { content: \(cell(.chart_c.body)); }",
    "textbox-insight-title { content: \(cell(.insight.title)); }",
    "textbox-insight-body { content: \(cell(.insight.body)); }",
    "textbox-note { content: \(cell(.note)); }"
  '
  printf 'note-box { border-color: %s; }\n' "$(rasi_quote "$note_border_color")"
}

render_rows() {
  local json="$1"
  local view target_date next_date previous_date current_view key label hint

  # Read from the payload's navigation block instead of deriving the same three
  # dates a second time: build_navigation_json already computed them from the
  # same target_date, and nothing else read the block it produced. "none"
  # stands in for an absent next day because tab is IFS whitespace, so an empty
  # field would collapse and shift every column after it.
  IFS=$'\t' read -r view target_date previous_date next_date < <(
    printf '%s' "$json" | jq -r '
      [
        .view,
        .target_date,
        .navigation.previous_date,
        (if (.navigation.next_date // "") == "" then "none" else .navigation.next_date end)
      ] | @tsv'
  )
  if [ "$next_date" = "none" ]; then
    next_date=""
  fi

  emit_row "nav:prev-day:$previous_date:$view" "$(action_row_markup "[P] Previous day" "$(date -d "$previous_date" '+%a %d %b')")" "go-previous-symbolic"
  if [ -n "$next_date" ]; then
    emit_row "nav:next-day:$next_date:$view" "$(action_row_markup "[N] Next day" "$(date -d "$next_date" '+%a %d %b')")" "go-next-symbolic"
  else
    emit_row "refresh:$view:$target_date" "$(action_row_markup "[R] Refresh")" "view-refresh-symbolic"
  fi

  # The view list comes from the same navigation block, so there is one table of
  # view ids and labels rather than one here and one in build_navigation_json.
  while IFS=$'\t' read -r current_view key label; do
    hint=""
    if [ "$current_view" = "$view" ]; then
      hint="Current"
    fi
    emit_row "view:$current_view:$target_date" "$(action_row_markup "[$key] $label" "$hint")" "go-home-symbolic"
  done < <(printf '%s' "$json" | jq -r '.navigation.views[] | [.id, .key, .label] | @tsv')

  if [ -n "$next_date" ]; then
    emit_row "refresh:$view:$target_date" "$(action_row_markup "[R] Refresh")" "view-refresh-symbolic"
  fi
  emit_row "close" "$(action_row_markup "[Q] Close")" "window-close-symbolic"
}
