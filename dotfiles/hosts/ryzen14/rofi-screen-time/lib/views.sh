#!/usr/bin/env bash

bar_markup() {
  local value="${1:-0}"
  local max="${2:-0}"
  local width="${3:-12}"
  local fill_color="${4:-$ACCENT_COLOR}"
  local empty_color="${5:-$MANTLE_COLOR}"
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

sparkline_from_json() {
  local values_json="$1"
  local highlight_index="${2:-}"
  local length
  local max
  local index=0
  local value=""
  local glyph=""
  local out=""
  local glyph_index=0
  local chars=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
  local color=""

  length="$(printf '%s' "$values_json" | jq 'length')"
  max="$(printf '%s' "$values_json" | jq 'max // 0')"
  if [ "$length" -le 0 ]; then
    printf '\n'
    return 0
  fi

  while [ "$index" -lt "$length" ]; do
    value="$(printf '%s' "$values_json" | jq -r ".[$index] // 0")"
    glyph_index="$(jq -nr --argjson value "$value" --argjson max "$max" '
      if $max <= 0 then 0 else (($value * 7 / $max) | floor) end
    ')"
    glyph="${chars[$glyph_index]}"

    if [ "$(jq -nr --argjson value "$value" '$value > 0')" = "true" ]; then
      color="$CYAN_COLOR"
    else
      color="$MANTLE_COLOR"
    fi
    if [ -n "$highlight_index" ] && [ "$index" -eq "$highlight_index" ]; then
      color="$ACCENT_COLOR"
    fi
    out+="<span foreground=\"$color\">$glyph</span>"
    index=$((index + 1))
  done

  printf '%s\n' "$out"
}

render_momentum_chart() {
  local slots_bundle_json="$1"
  printf '<span foreground="%s" weight="600">Daily Momentum</span>\n<span foreground="%s" size="small">00        06        12        18        24</span>\n%s\n' \
    "$ACCENT_COLOR" \
    "$SUBTEXT_COLOR" \
    "$(momentum_sparkline_from_json "$slots_bundle_json")"
}

momentum_sparkline_from_json() {
  local slots_bundle_json="$1"
  local index=0
  local out=""
  local glyph_index=0
  local chars=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
  local category=""
  local color=""
  local value=0
  local max_value=0
  local dominant_cat=""
  local max_cat_seconds=0
  
  max_value="$(printf '%s' "$slots_bundle_json" | jq '[.[] | .[]] | max // 0')"
  
  while [ "$index" -lt 48 ]; do
    dominant_cat="Unknown"
    max_cat_seconds=0
    value=0
    
    while IFS=$'\t' read -r category cat_seconds; do
      if [ "$cat_seconds" -gt "$max_cat_seconds" ]; then
        max_cat_seconds="$cat_seconds"
        dominant_cat="$category"
      fi
      value=$((value + cat_seconds))
    done < <(printf '%s' "$slots_bundle_json" | jq -r "to_entries[] | \"\(.key)\t\(.value[$index] // 0)\"")
    
    case "$dominant_cat" in
      Study) color="$SUCCESS_COLOR" ;;
      Work) color="$CYAN_COLOR" ;;
      Communication) color="$WARNING_COLOR" ;;
      Entertainment|Media) color="$ERROR_COLOR" ;;
      Browser) color="$PURPLE_COLOR" ;;
      System) color="$SUBTEXT_COLOR" ;;
      *) color="$MANTLE_COLOR" ;;
    esac
    
    if [ "$value" -le 0 ]; then
      color="$MANTLE_COLOR"
      glyph_index=0
    else
      glyph_index="$(jq -nr --argjson value "$value" --argjson max "$max_value" '
        if $max <= 0 then 1 else (($value * 6 / $max) | floor + 1) end
      ')"
    fi
    
    out+="<span foreground=\"$color\">${chars[$glyph_index]}</span>"
    index=$((index + 1))
  done
  
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

kv_markup() {
  local label="$1"
  local value="$2"
  printf '<span foreground="%s">%s</span> <span weight="600">%s</span>' \
    "$SUBTEXT_COLOR" \
    "$(escape_markup "$label")" \
    "$(escape_markup "$value")"
}

render_goal_gauge() {
  local current_seconds="$1"
  local target_seconds="$2"
  local ratio
  local label=""
  
  ratio="$(jq -nr --argjson c "$current_seconds" --argjson t "$target_seconds" 'if $t <= 0 then 0 else ($c / $t) end')"
  label="$(seconds_to_short "$current_seconds") / $(seconds_to_short "$target_seconds")"
  
  printf '<span foreground="%s">%s</span>\n%s\n' \
    "$SUBTEXT_COLOR" \
    "Study Goal: $(format_ratio_percent "$ratio") ($label)" \
    "$(bar_markup "$current_seconds" "$target_seconds" 40 "$SUCCESS_COLOR" "$MANTLE_COLOR")"
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

score_value_text() {
  local score_json="$1"
  if [ "$(printf '%s' "$score_json" | jq -r '.available')" != "true" ]; then
    printf 'Unavailable\n'
    return 0
  fi
  printf '%s\n' "$(printf '%s' "$score_json" | jq -r '(.value | round | tostring)')"
}

score_subtext() {
  local score_json="$1"
  if [ "$(printf '%s' "$score_json" | jq -r '.available')" != "true" ]; then
    printf '%s\n' "$(printf '%s' "$score_json" | jq -r '.reason // "Unavailable"')"
    return 0
  fi
  printf '%s\n' "$(printf '%s' "$score_json" | jq -r '.label')"
}

render_insight_console() {
  local context_json="$1"
  local output=""
  local line=""
  local count=0

  if [ "$(printf '%s' "$context_json" | jq -r '.study_active.active')" = "true" ]; then
    local elapsed
    elapsed="$(printf '%s' "$context_json" | jq -r '.study_active.elapsed_seconds')"
    output+="<span foreground=\"$ACCENT_COLOR\" weight=\"bold\">TIMER: Active study session ($(seconds_to_short "$elapsed"))</span>"$'\n'
  fi

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    output+="• $line"$'\n'
  done < <(
    printf '%s' "$context_json" \
      | jq -r '
        (.insights.all // [])
        | if length == 0 then
            ["No major insight available yet."]
          else
            map("\(.text)")
          end
        | .[]
      '
  )

  printf '%s' "${output%$'\n'}"
}

render_category_bars() {
  local context_json="$1"
  local limit="${2:-0}"
  local hide_zero="${3:-false}"
  local output=""
  local item=""
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
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    name="$(printf '%s' "$item" | jq -r '.name')"
    seconds="$(printf '%s' "$item" | jq -r '.seconds')"
    share="$(printf '%s' "$item" | jq -r '.share')"
    output+="$(printf '%-13s  %s  %6s  %s' \
      "$name" \
      "$(bar_markup "$seconds" "$max_seconds" 20 "$ACCENT_COLOR" "$MANTLE_COLOR")" \
      "$(seconds_to_short "$seconds")" \
      "$(format_ratio_percent "$share")")"$'\n'
  done < <(
    printf '%s' "$context_json" | jq -c \
      --argjson limit "$limit" \
      --argjson hide_zero "$hide_zero_json" '
        .today.categories.breakdown
        | if $hide_zero then map(select(.seconds > 0)) else . end
        | if $limit > 0 then .[:$limit] else . end
        | .[]
      '
  )

  if [ -z "$output" ]; then
    printf '%s\n' "$(kv_markup "Categories" "No category data yet")"
  else
    printf '%s' "${output%$'\n'}"
  fi
}

render_top_apps_by_category() {
  local context_json="$1"
  local output=""
  local category=""
  local name=""
  local seconds=""

  while IFS=$'\t' read -r category name seconds; do
    [ -n "$category" ] || continue
    output+="$(kv_markup "$category" "$name • $(seconds_to_short "$seconds")")"$'\n'
  done < <(
    printf '%s' "$context_json" \
      | jq -r '
        .today.categories.breakdown[]
        | select(.seconds > 0)
        | .name as $category
        | (.apps[0] // empty)
        | select(. != null)
        | "\($category)\t\(.name)\t\(.seconds)"
      '
  )

  if [ -z "$output" ]; then
    printf '%s\n' "$(kv_markup "Top apps" "No category data yet")"
  else
    printf '%s' "${output%$'\n'}"
  fi
}

render_baseline_summary() {
  local context_json="$1"
  local active_delta active_avg focus_delta frag_delta study_delta

  active_delta="$(printf '%s' "$context_json" | jq -r '.baseline.deltas.total_seconds.vs_yesterday // 0')"
  active_avg="$(printf '%s' "$context_json" | jq -r '.baseline.deltas.total_seconds.vs_avg7 // empty')"
  focus_delta="$(printf '%s' "$context_json" | jq -r '.baseline.deltas.focus_score.vs_avg7 // empty')"
  frag_delta="$(printf '%s' "$context_json" | jq -r '.baseline.deltas.fragmentation_score.vs_avg7 // empty')"
  study_delta="$(printf '%s' "$context_json" | jq -r '.baseline.deltas.study_ratio.vs_avg7 // empty')"

  printf '%s\n%s\n%s\n%s' \
    "$(kv_markup "Vs yesterday" "$(delta_label_seconds "$active_delta")")" \
    "$(kv_markup "Vs 7-day active" "$( [ -n "$active_avg" ] && delta_label_seconds "$(printf '%.0f' "$active_avg")" || printf 'Unavailable' )")" \
    "$(kv_markup "Vs 7-day focus" "$( [ -n "$focus_delta" ] && format_score_delta "$focus_delta" || printf 'Unavailable' )")" \
    "$(kv_markup "Vs 7-day study" "$( [ -n "$study_delta" ] && format_ratio_points_delta "$study_delta" || printf 'Unavailable' )")"

  if [ -n "$frag_delta" ]; then
    printf '\n%s' "$(kv_markup "Vs 7-day fragmentation" "$(format_score_delta "$frag_delta")")"
  fi
}

render_focus_breakdown() {
  local context_json="$1"
  local focus_json frag_json dist_json consistency_json

  focus_json="$(printf '%s' "$context_json" | jq -c '.today.scores.focus_score')"
  frag_json="$(printf '%s' "$context_json" | jq -c '.today.scores.fragmentation_score')"
  dist_json="$(printf '%s' "$context_json" | jq -c '.today.scores.distraction_load')"
  consistency_json="$(printf '%s' "$context_json" | jq -c '.today.scores.daily_consistency_score')"

  printf '%s\n%s\n%s\n%s' \
    "$(kv_markup "Focus Score" "$(score_value_text "$focus_json") • $(score_subtext "$focus_json")")" \
    "$(kv_markup "Fragmentation Score" "$(score_value_text "$frag_json") • $(score_subtext "$frag_json")")" \
    "$(kv_markup "Distraction Load" "$(score_value_text "$dist_json") • $(score_subtext "$dist_json")")" \
    "$(kv_markup "Daily Consistency" "$(score_value_text "$consistency_json") • $(score_subtext "$consistency_json")")"
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
          ["Productive Ratio v1", .today.metrics.productive_ratio_v1, .baseline.averages.productive_ratio_v1],
          ["Browser Ambiguity Ratio", .today.metrics.browser_ambiguity_ratio, .baseline.averages.browser_ambiguity_ratio]
        ]
        | .[]
        | @tsv
      '
  )"

  while IFS=$'\t' read -r label current avg; do
    [ -n "$label" ] || continue
    if [ "$current" = "null" ]; then
      output+="$(kv_markup "$label" "Unavailable")"$'\n'
      continue
    fi
    if [ "$label" = "Session density" ] || [ "$label" = "Switch rate" ]; then
      metrics="$(format_rate_with_avg "$current" "$avg")"
    else
      metrics="$(format_ratio_with_avg "$current" "$avg")"
    fi
    output+="$(kv_markup "$label" "$metrics")"$'\n'
  done <<< "$rows"

  printf '%s' "${output%$'\n'}"
}

render_windows_top_slots() {
  local context_json="$1"
  local output=""
  local label=""
  local seconds=""

  while IFS=$'\t' read -r label seconds; do
    [ -n "$label" ] || continue
    output+="$(kv_markup "$label" "$(seconds_to_short "$seconds")")"$'\n'
  done < <(printf '%s' "$context_json" | jq -r '.today.metrics.top_slots[]? | "\(.label)\t\(.seconds)"')

  if [ -z "$output" ]; then
    printf '%s\n' "$(kv_markup "Peak windows" "No tracked time yet")"
  else
    printf '%s' "${output%$'\n'}"
  fi
}

render_study_summary() {
  local context_json="$1"
  local study_seconds study_ratio active_label focus_window

  study_seconds="$(printf '%s' "$context_json" | jq -r '.today.study_seconds')"
  study_ratio="$(printf '%s' "$context_json" | jq -r '.today.metrics.study_ratio')"
  focus_window="$(printf '%s' "$context_json" | jq -r '.today.metrics.focus_window')"

  if [ "$(printf '%s' "$context_json" | jq -r '.study_active.active')" = "true" ]; then
    local mode="$(printf '%s' "$context_json" | jq -r '.study_active.mode // empty')"
    local current="$(printf '%s' "$context_json" | jq -r '.study_active.current_session // empty')"
    local planned="$(printf '%s' "$context_json" | jq -r '.study_active.planned_sessions // empty')"
    local left="$(printf '%s' "$context_json" | jq -r '.study_active.remaining_total_seconds // empty')"
    local elapsed="$(printf '%s' "$context_json" | jq -r '.study_active.elapsed_seconds // 0')"

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
    "$(kv_markup "Study time" "$(seconds_to_short "$study_seconds") • $(format_ratio_percent "$study_ratio")")" \
    "$(kv_markup "Study timer" "$active_label")" \
    "$(kv_markup "Focus window" "$focus_window")"
}

render_trend_table() {
  local context_json="$1"
  local output=""

  while IFS=$'\t' read -r date total focus frag; do
    [ -n "$date" ] || continue
    output+="$(kv_markup "$date" "$(seconds_to_short "$total") • focus ${focus:-n/a} • frag ${frag:-n/a}")"$'\n'
  done < <(
    printf '%s' "$context_json" \
      | jq -r '
        .trailing[]
        | [
            .date,
            .total_seconds,
            (if .scores.focus_score.value == null then "n/a" else (.scores.focus_score.value | tostring) end),
            (if .scores.fragmentation_score.value == null then "n/a" else (.scores.fragmentation_score.value | tostring) end)
          ]
        | @tsv
      '
  )

  printf '%s' "${output%$'\n'}"
}

render_metric_sparklines() {
  local context_json="$1"
  local active_json focus_json frag_json study_json productive_json browser_json

  active_json="$(printf '%s' "$context_json" | jq -c '[.trailing[].total_seconds]')"
  focus_json="$(printf '%s' "$context_json" | jq -c '[.trailing[] | (.scores.focus_score.value // 0)]')"
  frag_json="$(printf '%s' "$context_json" | jq -c '[.trailing[] | (.scores.fragmentation_score.value // 0)]')"
  study_json="$(printf '%s' "$context_json" | jq -c '[.trailing[] | ((.metrics.study_ratio // 0) * 100 | round)]')"
  productive_json="$(printf '%s' "$context_json" | jq -c '[.trailing[] | ((.metrics.productive_ratio_v1 // 0) * 100 | round)]')"
  browser_json="$(printf '%s' "$context_json" | jq -c '[.trailing[] | ((.metrics.browser_ambiguity_ratio // 0) * 100 | round)]')"

  printf '%s\n%s\n%s' \
    "$(kv_markup "Active" "$(sparkline_from_json "$active_json")")" \
    "$(kv_markup "Focus / Frag" "$(sparkline_from_json "$focus_json")  $(sparkline_from_json "$frag_json")")" \
    "$(kv_markup "Study / Productive / Browser" "$(sparkline_from_json "$study_json")  $(sparkline_from_json "$productive_json")  $(sparkline_from_json "$browser_json")")"
}

render_recommendations() {
  local context_json="$1"
  local output=""

  while IFS=$'\t' read -r metric text; do
    [ -n "$text" ] || continue
    output+="$(kv_markup "$(humanize_metric "$metric")" "$text")"$'\n'
  done < <(
    printf '%s' "$context_json" \
      | jq -r '
        (.insights.recommendation_candidates // [])
        | if length == 0 then
            [["status", "No urgent recommendation triggered."]]
          else
            map([.metric, .text])
          end
        | .[]
        | @tsv
      '
  )

  printf '%s' "${output%$'\n'}"
}

render_triggered_thresholds() {
  local context_json="$1"
  printf '%s\n%s\n%s\n%s' \
    "$(kv_markup "Browser ambiguity" "$(format_ratio_percent "$(printf '%s' "$context_json" | jq -r '.today.metrics.browser_ambiguity_ratio')")")" \
    "$(kv_markup "Unknown share" "$(format_ratio_percent "$(printf '%s' "$context_json" | jq -r '.today.categories.unknown_share')")")" \
    "$(kv_markup "Switch rate" "$(if [ "$(printf '%s' "$context_json" | jq -r '.today.metrics.switch_rate != null')" = "true" ]; then printf '%.1f/h' "$(printf '%s' "$context_json" | jq -r '.today.metrics.switch_rate // 0')"; else printf 'Unavailable'; fi)")" \
    "$(kv_markup "Study ratio" "$(format_ratio_percent "$(printf '%s' "$context_json" | jq -r '.today.metrics.study_ratio')")")"
}

render_quality_reasons() {
  local context_json="$1"
  local output=""

  while IFS= read -r reason; do
    [ -n "$reason" ] || continue
    output+="$(kv_markup "Reason" "$reason")"$'\n'
  done < <(printf '%s' "$context_json" | jq -r '.data_quality.unavailable_metrics[]?')

  if [ -z "$output" ]; then
    printf '%s\n' "$(kv_markup "Quality" "No blocking data-quality warnings.")"
  else
    printf '%s' "${output%$'\n'}"
  fi
}

render_unknown_apps() {
  local context_json="$1"
  local output=""

  while IFS=$'\t' read -r name seconds; do
    [ -n "$name" ] || continue
    output+="$(kv_markup "$name" "$(seconds_to_short "$seconds")")"$'\n'
  done < <(
    printf '%s' "$context_json" \
      | jq -r '
        .today.app_entries
        | map(select(.category == "Unknown"))
        | .[:6][]
        | "\(.name)\t\(.seconds)"
      '
  )

  if [ -z "$output" ]; then
    printf '%s\n' "$(kv_markup "Unknown apps" "All visible apps are mapped.")"
  else
    printf '%s' "${output%$'\n'}"
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
        {id:"summary", label:"Dashboard"},
        {id:"activity", label:"Activity"},
        {id:"health", label:"Health"},
        {id:"timer", label:"Timer"}
      ]
    }'
}

build_view_payload() {
  local view="$1"
  local context_json="$2"
  local target_date subtitle meta title note_text navigation_json
  local updated_time total_seconds study_ratio focus_json frag_json focus_value frag_value
  local top_category peak_window main_insight summary_active summary_study_ratio
  local card1_label card1_value card1_sub
  local card2_label card2_value card2_sub
  local card3_label card3_value card3_sub
  local card4_label card4_value card4_sub
  local primary_title primary_body chart_b_title chart_b_body chart_c_title chart_c_body insight_title insight_body

  target_date="$(printf '%s' "$context_json" | jq -r '.target_date')"
  updated_time="$(updated_time_label "$(printf '%s' "$context_json" | jq -r '.today.updated_at')")"
  total_seconds="$(printf '%s' "$context_json" | jq -r '.today.total_seconds')"
  study_ratio="$(printf '%s' "$context_json" | jq -r '.today.metrics.study_ratio')"
  focus_json="$(printf '%s' "$context_json" | jq -c '.today.scores.focus_score')"
  frag_json="$(printf '%s' "$context_json" | jq -c '.today.scores.fragmentation_score')"
  focus_value="$(score_value_text "$focus_json")"
  frag_value="$(score_value_text "$frag_json")"
  top_category="$(printf '%s' "$context_json" | jq -r '.today.categories.top_category')"
  peak_window="$(printf '%s' "$context_json" | jq -r '.today.metrics.peak_slot_label')"
  main_insight="$(printf '%s' "$context_json" | jq -r '.insights.main.text // "No major insight available yet."')"
  summary_active="$(seconds_to_compact "$total_seconds")"
  summary_study_ratio="$(format_ratio_percent "$study_ratio")"
  navigation_json="$(build_navigation_json "$view" "$target_date")"

  case "$view" in
    summary)
      title="Dashboard"
      subtitle="$(date -d "$target_date" '+%A, %d %B %Y')"
      meta="$(kv_markup "Updated" "$updated_time")"
      card1_label="Total Use"
      card1_value="$summary_active"
      card1_sub="Peak $peak_window"
      card2_label="Focus"
      card2_value="$focus_value"
      card2_sub="$(score_subtext "$focus_json")"
      card3_label="Switching"
      card3_value="$frag_value"
      card3_sub="$(score_subtext "$frag_json")"
      if [ "$(printf '%s' "$context_json" | jq -r '.study_active.active')" = "true" ]; then
        card4_label="Deep Work [ACTIVE]"
      else
        card4_label="Deep Work"
      fi
      card4_value="$summary_study_ratio"
      card4_sub="$(seconds_to_short "$(printf '%s' "$context_json" | jq -r '.today.study_seconds')") total"
      
      primary_title=""
      primary_body="$(printf '%s\n\n%s\n\n<span foreground=\"%s\" weight=\"600\">Primary Advice</span>\n%s' \
        "$(render_goal_gauge "$(printf '%s' "$context_json" | jq -r '.today.study_seconds')" "$(printf '%s' "$context_json" | jq -r '.today.metrics.study_goal_seconds')")" \
        "$(render_momentum_chart "$(printf '%s' "$context_json" | jq -c '.today.categories.slots')")" \
        "$ACCENT_COLOR" \
        "$(render_recommendations "$context_json")")"
      
      chart_b_title="7-Day Trend"
      chart_b_body="$(render_metric_sparklines "$context_json")"
      
      chart_c_title="Compared to Usual"
      chart_c_body="$(render_baseline_summary "$context_json")"
      
      insight_title="Active Insights"
      insight_body="$(render_insight_console "$context_json")"
      
      local study_status
      if [ "$(printf '%s' "$context_json" | jq -r '.study_active.active')" = "true" ]; then
        study_status="Study session: $(seconds_to_short "$(printf '%s' "$context_json" | jq -r '.study_active.elapsed_seconds')") active."
      else
        study_status="Study session: Idle."
      fi
      note_text="$study_status  Main blocker: $(printf '%s' "$context_json" | jq -r '.insights.by_class.recommendation.metric // "none"')."
      ;;

    activity)
      title="Activity Hub"
      subtitle="$(date -d "$target_date" '+%A, %d %B %Y')"
      meta="$(kv_markup "Top" "$(printf '%s' "$context_json" | jq -r '.today.categories.top_category')")"
      card1_label="Top Category"
      card1_value="$(humanize_class "$(printf '%s' "$context_json" | jq -r '.today.categories.top_category')")"
      card1_sub="$(seconds_to_short "$(printf '%s' "$context_json" | jq -r '.today.categories.top_category_seconds')")"
      card2_label="Active Spread"
      card2_value="$(printf '%s' "$context_json" | jq -r '.today.metrics.active_slot_count | tostring')"
      card2_sub="30-min active blocks"
      card3_label="Peak Usage"
      card3_value="$(printf '%s' "$context_json" | jq -r '.today.metrics.peak_slot_label')"
      card3_sub="$(seconds_to_short "$(printf '%s' "$context_json" | jq -r '.today.metrics.peak_slot_seconds')")"
      card4_label="Study Ratio"
      card4_value="$(format_ratio_percent "$study_ratio")"
      card4_sub="$(seconds_to_short "$(printf '%s' "$context_json" | jq -r '.today.study_seconds')") total"
      
      primary_title="Usage Breakdown"
      primary_body="$(render_category_bars "$context_json" 0 false)"
      
      chart_b_title="Busy Times"
      chart_b_body="$(render_timeline_chart "$(printf '%s' "$context_json" | jq -c '.today.raw.slots_30m')" "focus window $(printf '%s' "$context_json" | jq -r '.today.metrics.focus_window')")"
      
      chart_c_title="Momentum Check"
      chart_c_body="$(render_momentum_chart "$(printf '%s' "$context_json" | jq -c '.today.categories.slots')")"
      
      insight_title="Top Apps"
      insight_body="$(render_top_apps_by_category "$context_json")"
      note_text="Activity insights are updated every 5 minutes based on window focus."
      ;;

    health)
      title="Health & Quality"
      subtitle="$(date -d "$target_date" '+%A, %d %B %Y')"
      meta="$(kv_markup "Data Schema" "$(printf '%s' "$context_json" | jq -r 'if .data_quality.schema_ready then "Version 2" else "Legacy" end')")"
      card1_label="Focus Score"
      card1_value="$focus_value"
      card1_sub="$(score_subtext "$focus_json")"
      card2_label="Fragmentation"
      card2_value="$frag_value"
      card2_sub="$(score_subtext "$frag_json")"
      card3_label="Switch Rate"
      card3_value="$(if [ "$(printf '%s' "$context_json" | jq -r '.today.metrics.switch_rate != null')" = "true" ]; then printf '%.1f/h' "$(printf '%s' "$context_json" | jq -r '.today.metrics.switch_rate // 0')" ; else printf 'Unavailable'; fi)"
      card3_sub="Context pressure"
      card4_label="Coverage"
      card4_value="$(format_ratio_percent "$(printf '%s' "$context_json" | jq -r '.today.metrics.known_category_ratio')")"
      card4_sub="Mapped category share"
      
      primary_title="Diagnostic Breakdown"
      primary_body="$(printf '%s\n\n<span foreground=\"%s\" weight=\"600\">Data Health</span>\n%s' \
        "$(render_focus_breakdown "$context_json")" \
        "$ACCENT_COLOR" \
        "$(render_focus_vs_baseline "$context_json")")"
        
      chart_b_title="Mapping Gaps"
      chart_b_body="$(render_unknown_apps "$context_json")"
      
      chart_c_title="Trust Factors"
      chart_c_body="$(printf '%s\n%s\n%s' \
        "$(kv_markup "Cat ratio" "$(format_ratio_percent "$(printf '%s' "$context_json" | jq -r '.data_quality.known_category_ratio')")")" \
        "$(kv_markup "Ambiguity" "$(format_ratio_percent "$(printf '%s' "$context_json" | jq -r '.data_quality.browser_ambiguity_ratio')")")" \
        "$(kv_markup "Unknown" "$(format_ratio_percent "$(printf '%s' "$context_json" | jq -r '.data_quality.unknown_share')")")")"
        
      insight_title="System Insight"
      insight_body="$(printf '%s' "$context_json" | jq -r '.insights.by_class.quality.text // "All systems operational."')"
      note_text="Metric health depends on the size of your category map."
      ;;
    timer)
      title="Timer Control"
      subtitle="$(date -d "$target_date" '+%A, %d %B %Y')"
      meta="$(kv_markup "Updated" "$updated_time")"
      card1_label="Active Study"
      card1_value="$(seconds_to_short "$(printf '%s' "$context_json" | jq -r '.today.study_seconds')")"
      card1_sub="Total today"
      card2_label="Study Goal"
      card2_value="$(format_ratio_percent "$(printf '%s' "$context_json" | jq -r '.today.metrics.study_goal_progress')")"
      card2_sub="$(seconds_to_short "$(printf '%s' "$context_json" | jq -r '.today.metrics.study_goal_seconds')") target"
      card3_label="Current Session"
      card3_value="$(if [ "$(printf '%s' "$context_json" | jq -r '.study_active.active')" = "true" ]; then seconds_to_short "$(printf '%s' "$context_json" | jq -r '.study_active.elapsed_seconds')"; else printf "None"; fi)"
      card3_sub="Elapsed time"
      card4_label="Status"
      card4_value="$(if [ "$(printf '%s' "$context_json" | jq -r '.study_active.active')" = "true" ]; then printf "ACTIVE"; else printf "IDLE"; fi)"
      card4_sub="$(printf '%s' "$context_json" | jq -r '.study_active.mode // "No plan active"')"
      
      primary_title=""
      primary_body="$(render_goal_gauge "$(printf '%s' "$context_json" | jq -r '.today.study_seconds')" "$(printf '%s' "$context_json" | jq -r '.today.metrics.study_goal_seconds')")"
      
      chart_b_title="Session Strategy"
      chart_b_body="$(render_study_summary "$context_json")"
      
      chart_c_title="Concentration Rhythm"
      chart_c_body="$(render_momentum_chart "$(printf '%s' "$context_json" | jq -c '.today.categories.slots')")"
      
      insight_title="Efficiency Note"
      insight_body="$(printf '%s' "$context_json" | jq -r '.insights.main.text // "Start a session to track goal velocity."')"
      note_text="Timer data is synchronized with the background study-timer service."
      ;;
    *)
      # Default fallback to Dashboard
      view="summary"
      title="Dashboard"
      # ... (logic already handled in summary case above if this is an initial call)
      ;;
  esac

  jq -n \
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
    --argjson metrics "$(printf '%s' "$context_json" | jq -c '.today.metrics')" \
    --argjson scores "$(printf '%s' "$context_json" | jq -c '.today.scores')" \
    --argjson categories "$(printf '%s' "$context_json" | jq -c '.today.categories')" \
    --argjson data_quality "$(printf '%s' "$context_json" | jq -c '.data_quality')" \
    --argjson insights "$(printf '%s' "$context_json" | jq -c '.insights')" \
    --argjson baseline "$(printf '%s' "$context_json" | jq -c '.baseline')" \
    --argjson navigation "$navigation_json" \
    '{
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
  cat <<EOF
textbox-title { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.title')"); }
textbox-subtitle { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.subtitle')"); }
textbox-meta { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.meta')"); }
textbox-card-1-label { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.cards[0].label')"); }
textbox-card-1-value { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.cards[0].value')"); }
textbox-card-1-sub { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.cards[0].sub')"); }
textbox-card-2-label { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.cards[1].label')"); }
textbox-card-2-value { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.cards[1].value')"); }
textbox-card-2-sub { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.cards[1].sub')"); }
textbox-card-3-label { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.cards[2].label')"); }
textbox-card-3-value { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.cards[2].value')"); }
textbox-card-3-sub { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.cards[2].sub')"); }
textbox-card-4-label { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.cards[3].label')"); }
textbox-card-4-value { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.cards[3].value')"); }
textbox-card-4-sub { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.cards[3].sub')"); }
textbox-primary-title { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.primary.title')"); }
textbox-primary-body { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.primary.body')"); }
textbox-chart-b-title { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.chart_b.title')"); }
textbox-chart-b-body { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.chart_b.body')"); }
textbox-chart-c-title { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.chart_c.title')"); }
textbox-chart-c-body { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.chart_c.body')"); }
textbox-insight-title { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.insight.title')"); }
textbox-insight-body { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.insight.body')"); }
textbox-note { content: $(rasi_quote "$(printf '%s' "$json" | jq -r '.note')"); }
EOF
}

render_rows() {
  local json="$1"
  local view target_date today next_date previous_date current_view label hint

  view="$(printf '%s' "$json" | jq -r '.view')"
  target_date="$(printf '%s' "$json" | jq -r '.target_date')"
  today="$(date +%F)"
  previous_date="$(date -d "$target_date -1 day" +%F)"
  next_date=""
  if [ "$target_date" != "$today" ]; then
    next_date="$(date -d "$target_date +1 day" +%F)"
  fi

  emit_row "nav:prev-day:$previous_date:$view" "$(action_row_markup "Previous day" "$(date -d "$previous_date" '+%a %d %b')")" "go-previous-symbolic"
  if [ -n "$next_date" ]; then
    emit_row "nav:next-day:$next_date:$view" "$(action_row_markup "Next day" "$(date -d "$next_date" '+%a %d %b')")" "go-next-symbolic"
  else
    emit_row "refresh:$view:$target_date" "$(action_row_markup "Refresh")" "view-refresh-symbolic"
  fi

  while IFS=$'\t' read -r current_view label; do
    hint=""
    if [ "$current_view" = "$view" ]; then
      hint="Current"
    fi
    emit_row "view:$current_view:$target_date" "$(action_row_markup "$label" "$hint")" "go-home-symbolic"
  done <<'EOF'
summary	Dashboard
activity	Activity Hub
health	Health Hub
timer	Timer Hub
EOF

  if [ -n "$next_date" ]; then
    emit_row "refresh:$view:$target_date" "$(action_row_markup "Refresh")" "view-refresh-symbolic"
  fi
  emit_row "close" "$(action_row_markup "Close")" "window-close-symbolic"
}
