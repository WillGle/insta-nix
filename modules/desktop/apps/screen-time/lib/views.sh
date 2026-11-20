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

# Keep category colours consistent and separate from severity colours.
# Assign the colour to avoid subshells in slot loops; category_color prints it.
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

sparkline_from_json() {
  local values_json="$1"
  local highlight_index="${2:-}"
  local index=0
  local out=""
  local chars=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
  local color=""
  local glyph_index=0
  local positive=""

  # Emit glyph indices and signs in one jq pass; empty arrays emit no rows.
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
  local slots_bundle_json
  slots_bundle_json="$(printf '%s' "$context_json" | jq -c '.today.categories.slots // {}')"

  # Four rows of twelve half-hour slots; shades range from empty (0) to max (4).
  local shade_chars=("░" "░" "▒" "▓" "█")
  local out="" segment_out="" slot_idx active dominant_cat shade_idx
  local start_h end_h

  while IFS=$'\t' read -r slot_idx active dominant_cat shade_idx; do
    if (( slot_idx % 12 == 0 )); then
      if [ -n "$segment_out" ]; then
        out+="${segment_out}"$'\n'
      fi
      start_h=$(( slot_idx / 2 ))
      end_h=$(( start_h + 6 ))
      segment_out="$(printf '<span foreground="%s">%02d─%02d</span>  ' \
        "$SUBTEXT_COLOR" "$start_h" "$end_h")"
    fi

    if [ "$active" = "0" ]; then
      CATEGORY_COLOR="$BASE_COLOR"
    else
      set_category_color "$dominant_cat"
    fi
    segment_out+="<span foreground=\"${CATEGORY_COLOR}\">${shade_chars[$shade_idx]}</span>"
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
          "\($i)\t0\tUnknown\t0"
        else
          # Scale intensity to 1–4 with ceil(value*4/max).
          "\($i)\t1\t\($dominant)\t\(
            if $max <= 0 then 4
            else (($value * 4 / $max) | ceil | if . < 1 then 1 elif . > 4 then 4 else . end)
            end
          )"
        end
    '
  )
  out+="${segment_out}"

  printf '%s\n%s\n%s' \
    "$(printf '<span foreground="%s" size="small">shade = activity level · color = app type · each cell = 30 min</span>' \
        "$SUBTEXT_COLOR")" \
    "$out" \
    "$(printf '<span size="small" foreground="%s">■ <span foreground="%s">Work</span>  ■ <span foreground="%s">Study</span>  ■ <span foreground="%s">Browser</span>  ■ <span foreground="%s">Comm</span>  ■ <span foreground="%s">Leisure</span></span>' \
        "$SUBTEXT_COLOR" \
        "$CYAN_COLOR" "$SUCCESS_COLOR" "$PURPLE_COLOR" "$WARNING_COLOR" "$ERROR_COLOR")"
}

kv_markup() {
  local label="$1"
  local value="$2"
  printf '<span foreground="%s">%s</span> <span weight="600">%s</span>' \
    "$SUBTEXT_COLOR" \
    "$(escape_markup "$label")" \
    "$(escape_markup "$value")"
}

# Bash printf pads by bytes; pad by characters for Unicode labels.
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
    # Match category colours in the 24-hour strip.
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

  # Emit TSV in one jq pass to avoid subprocesses per app.
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

render_unknown_apps() {
  local context_json="$1"
  local output=""

  while IFS=$'\t' read -r name seconds; do
    [ -n "$name" ] || continue
    output+="$(printf '%s  %6s' \
      "$(escape_markup "$(pad_right "$(clip_text "$name" 28)" 28)")" \
      "$(seconds_to_short "$seconds")")"$'\n'
  done < <(
    printf '%s' "$context_json" \
      | jq -r '
        .today.app_entries
        | map(select(.category == "Unknown" and (.seconds // 0) > 0))
        | .[:6][]
        | [.name, (.seconds | tostring)]
        | @tsv
      '
  )

  if [ -z "$output" ]; then
    printf '%s\n' "$(kv_markup "Unknown apps" "All visible apps are mapped.")"
  else
    printf '%s' "${output%$'\n'}"
  fi
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
        {id:"activity", key:"A", label:"App timeline"}
      ]
    }'
}

build_view_payload() {
  local view="$1"
  local context_json="$2"
  local target_date subtitle meta title note_text navigation_json
  local updated_time total_seconds top_category top_category_seconds
  local active_slot_count peak_slot_label peak_slot_seconds focus_window
  local unknown_seconds unknown_share sample_seconds slots_json
  local card1_label card1_value card1_sub
  local card2_label card2_value card2_sub
  local card3_label card3_value card3_sub
  local card4_label card4_value card4_sub
  local primary_title primary_body chart_b_title chart_b_body chart_c_title chart_c_body
  local insight_title insight_body

  # Read shared scalars once; NUL separators preserve empty fields.
  local -a scalars
  mapfile -d '' -t scalars < <(printf '%s' "$context_json" | jq -j '
    [ .target_date,
      .today.updated_at,
      .today.total_seconds,
      .today.categories.top_category,
      .today.categories.top_category_seconds,
      .today.metrics.active_slot_count,
      .today.metrics.peak_slot_label,
      .today.metrics.peak_slot_seconds,
      .today.metrics.focus_window,
      .today.metrics.unknown_seconds,
      .today.metrics.unknown_share,
      .today.sample_seconds
    ] | map(tostring) | join(([0] | implode))')
  target_date="${scalars[0]}"
  updated_time="$(updated_time_label "${scalars[1]}")"
  total_seconds="${scalars[2]}"
  top_category="${scalars[3]}"
  top_category_seconds="${scalars[4]}"
  active_slot_count="${scalars[5]}"
  peak_slot_label="${scalars[6]}"
  peak_slot_seconds="${scalars[7]}"
  focus_window="${scalars[8]}"
  unknown_seconds="${scalars[9]}"
  unknown_share="${scalars[10]}"
  sample_seconds="${scalars[11]}"
  slots_json="$(printf '%s' "$context_json" | jq -c '.today.slots_30m')"
  navigation_json="$(build_navigation_json "$view" "$target_date")"

  case "$view" in
    activity)
      title="App timeline"
      subtitle="$(date -d "$target_date" '+%A, %d %B %Y')"
      meta="$(kv_markup "Main category" "$top_category")"
      card1_label="Main category"
      card1_value="$(humanize_class "$top_category")"
      card1_sub="$(seconds_to_short "$top_category_seconds")"
      card2_label="Active half-hours"
      card2_value="$active_slot_count"
      card2_sub="30-minute blocks"
      card3_label="Busiest 30-min"
      card3_value="$peak_slot_label"
      card3_sub="$(seconds_to_short "$peak_slot_seconds") active"
      card4_label="Unknown share"
      card4_value="$(format_ratio_percent "$unknown_share")"
      card4_sub="$(seconds_to_short "$unknown_seconds") unclassified"

      primary_title="Apps across the day"
      primary_body="$(render_app_usage_timeline "$context_json" 8)"

      chart_b_title="Busy hours"
      chart_b_body="$(render_timeline_chart "$slots_json" "Densest 90-min window: ${focus_window}")"

      chart_c_title="Category breakdown"
      chart_c_body="$(render_category_bars "$context_json" 6 true)"

      insight_title="Unknown apps"
      insight_body="$(render_unknown_apps "$context_json")"
      note_text="Updated from the focused window every ${sample_seconds} seconds."
      ;;
    *)
      view="summary"
      title="Today"
      subtitle="$(date -d "$target_date" '+%A, %d %B %Y')"
      meta="$(kv_markup "Updated" "$updated_time")"
      card1_label="Screen time"
      card1_value="$(seconds_to_compact "$total_seconds")"
      card1_sub="Tracked today"
      card2_label="Top category"
      card2_value="$(humanize_class "$top_category")"
      card2_sub="$(seconds_to_short "$top_category_seconds")"
      card3_label="Active half-hours"
      card3_value="$active_slot_count"
      card3_sub="30-minute blocks"
      card4_label="Busiest 30-min"
      card4_value="$peak_slot_label"
      card4_sub="$(seconds_to_short "$peak_slot_seconds") active"

      primary_title="Today at a glance"
      primary_body="$(printf '%s\n\n<span foreground=\"%s\" weight=\"600\">Top Apps Today</span>\n%s' \
        "$(render_hero_day_strip "$context_json")" \
        "$ACCENT_COLOR" \
        "$(render_top_app_bars "$context_json" 4)")"

      chart_b_title="Category breakdown"
      chart_b_body="$(render_category_bars "$context_json" 6 true)"

      chart_c_title="Busy hours"
      chart_c_body="$(render_timeline_chart "$slots_json" "Densest 90-min window: ${focus_window}")"

      insight_title="Unknown apps"
      insight_body="$(render_unknown_apps "$context_json")"
      note_text="Updated from the focused window every ${sample_seconds} seconds."
      ;;
  esac

  # Pass context on stdin because it can exceed the 128 KiB argument limit.
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
    --argjson navigation "$navigation_json" \
    '
    . as $context
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
      metrics: $context.today.metrics,
      categories: $context.today.categories,
      navigation: $navigation
    }'
}

render_theme() {
  local json="$1"
  # Quote all fields in one jq pass; tostring preserves missing fields as "null".
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
  printf 'note-box { border-color: %s; }\n' "$(rasi_quote "$ACCENT_COLOR")"
}

render_rows() {
  local json="$1"
  local view target_date next_date previous_date current_view key label hint

  # Reuse navigation dates; "none" prevents empty TSV fields from collapsing.
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

  # Reuse the navigation view list to keep IDs and labels consistent.
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
