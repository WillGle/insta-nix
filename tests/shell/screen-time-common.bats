#!/usr/bin/env bats

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  unset THEME_STATIC_BASE THEME_STATIC_TEXT THEME_STATIC_SUBTEXT
  unset THEME_STATIC_ACCENT THEME_STATIC_PURPLE THEME_STATIC_CYAN

  # shellcheck source=/dev/null
  source "$REPO_ROOT/modules/desktop/apps/screen-time/lib/common.sh"
  # shellcheck source=/dev/null
  source "$REPO_ROOT/modules/desktop/rofi/lib/menu.sh"
}

@test "normalize_class lowercases and strips launcher suffixes" {
  [ "$(normalize_class '  Foo.EXE  ')" = "foo" ]
  [ "$(normalize_class 'Bar-updater')" = "bar" ]
  [ "$(normalize_class 'Baz_updater')" = "baz" ]
  [ "$(normalize_class 'Qux Updater')" = "qux" ]
}

@test "resolve_screen_time_view maps aliases to the two views" {
  [ "$(resolve_screen_time_view app)" = "activity" ]
  [ "$(resolve_screen_time_view time-windows)" = "activity" ]
  [ "$(resolve_screen_time_view activity)" = "activity" ]
  [ "$(resolve_screen_time_view summary)" = "summary" ]
  [ "$(resolve_screen_time_view unknown)" = "summary" ]
  [ "$(resolve_screen_time_view)" = "summary" ]
}

@test "seconds_to_short keeps sub-minute values visible" {
  [ "$(seconds_to_short 0)" = "0m" ]
  [ "$(seconds_to_short 30)" = "~1m" ]
  [ "$(seconds_to_short 3660)" = "1h 1m" ]
  [ "$(seconds_to_short 7200)" = "2h" ]
}

@test "seconds_to_compact pads minutes when hours are present" {
  [ "$(seconds_to_compact 30)" = "~1m" ]
  [ "$(seconds_to_compact 3661)" = "1h 01m" ]
  [ "$(seconds_to_compact 59)" = "~1m" ]
}

@test "format_ratio_percent rounds and handles missing values" {
  [ "$(format_ratio_percent 0.5)" = "50%" ]
  [ "$(format_ratio_percent 0.005)" = "1%" ]
  [ "$(format_ratio_percent '')" = "Unavailable" ]
  [ "$(format_ratio_percent null)" = "Unavailable" ]
  [ "$(format_ratio_percent nonsense)" = "Unavailable" ]
}

@test "escape_markup escapes Rofi markup characters" {
  [ "$(escape_markup '<a&b>')" = '&lt;a&amp;b&gt;' ]
}

@test "default_day_json emits schema v3 without study or behavior" {
  day="$(default_day_json 2026-11-21 2026-11-21T00:00:00+07:00 5)"
  [ "$(jq -r '.version' <<<"$day")" = "3" ]
  [ "$(jq -r '.slots_30m | length' <<<"$day")" = "48" ]
  [ "$(jq -r 'has("study") or has("behavior")' <<<"$day")" = "false" ]
}

@test "normalize_day_json drops legacy fields and keeps app totals" {
  legacy='{"version":2,"date":"2026-11-21","updated_at":"x","sample_seconds":5,"sample_count":3,"first_seen":"a","last_seen":"b","total_seconds":15,"slots_30m":[15],"apps":{"foo":{"class":"Foo","name":"Foo App","icon":"icon","seconds":15,"sample_count":3,"session_count":1,"first_seen":"a","last_seen":"b","slots_30m":[15]}},"study":{"total_seconds":5},"behavior":{"transitions":{"a -> b":{"count":1}}}}'
  normalized="$(normalize_day_json 2026-11-21 2026-11-21T00:00:00+07:00 5 <<<"$legacy")"
  [ "$(jq -r '.version' <<<"$normalized")" = "3" ]
  [ "$(jq -r '.apps.foo.seconds' <<<"$normalized")" = "15" ]
  [ "$(jq -r '.apps.foo.session_count // "absent"' <<<"$normalized")" = "absent" ]
  [ "$(jq -r 'has("study") or has("behavior")' <<<"$normalized")" = "false" ]
  [ "$(jq -r '.slots_30m | length' <<<"$normalized")" = "48" ]
}
