#!/usr/bin/env bash

allowed_screen_time_categories_json() {
  jq -nc '[
    "Work",
    "Study",
    "Communication",
    "Browser",
    "Entertainment",
    "Media",
    "System",
    "Unknown"
  ]'
}

load_category_map_json() {
  local allowed_json=""
  local invalid_lines=""
  local category_json=""

  allowed_json="$(allowed_screen_time_categories_json)"

  if [ ! -r "$CATEGORY_MAP_FILE" ]; then
    printf '{}\n'
    return 0
  fi

  if ! jq empty "$CATEGORY_MAP_FILE" >/dev/null 2>&1; then
    printf 'rofi-screen-time: invalid category map JSON at %s\n' "$CATEGORY_MAP_FILE" >&2
    printf '{}\n'
    return 0
  fi

  invalid_lines="$(
    jq -r \
      --argjson allowed "$allowed_json" \
      '
      (.categories // {})
      | to_entries[]
      | . as $entry
      | select(($allowed | index($entry.value)) | not)
      | "\(.key)\t\(.value)"
      ' \
      "$CATEGORY_MAP_FILE"
  )"

  if [ -n "$invalid_lines" ]; then
    while IFS=$'\t' read -r key value; do
      [ -n "$key" ] || continue
      printf 'rofi-screen-time: ignoring invalid category %s for %s\n' "$value" "$key" >&2
    done <<< "$invalid_lines"
  fi

  category_json="$(
    jq -c \
      --argjson allowed "$allowed_json" \
      '
      (.categories // {})
      | with_entries(.key |= (ascii_downcase | gsub("^\\s+|\\s+$"; "")))
      | with_entries(. as $entry | select($allowed | index($entry.value)))
      ' \
      "$CATEGORY_MAP_FILE"
  )"

  if [ -n "$category_json" ]; then
    printf '%s\n' "$category_json"
  else
    printf '{}\n'
  fi
}
