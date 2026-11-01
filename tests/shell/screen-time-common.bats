#!/usr/bin/env bats

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  unset THEME_STATIC_BASE THEME_STATIC_TEXT THEME_STATIC_SUBTEXT
  unset THEME_STATIC_ACCENT THEME_STATIC_PURPLE THEME_STATIC_CYAN

  # shellcheck source=/dev/null
  source "$REPO_ROOT/hosts/think14gryzen/assets/rofi-screen-time/lib/common.sh"
}

@test "normalize_class lowercases and strips launcher suffixes" {
  [ "$(normalize_class '  Foo.EXE  ')" = "foo" ]
  [ "$(normalize_class 'Bar-updater')" = "bar" ]
  [ "$(normalize_class 'Baz_updater')" = "baz" ]
  [ "$(normalize_class 'Qux Updater')" = "qux" ]
}

@test "resolve_screen_time_view maps aliases to views" {
  [ "$(resolve_screen_time_view app)" = "activity" ]
  [ "$(resolve_screen_time_view time-windows)" = "activity" ]
  [ "$(resolve_screen_time_view focus)" = "health" ]
  [ "$(resolve_screen_time_view study-timer)" = "timer" ]
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

@test "delta_label_seconds reports direction and magnitude" {
  [ "$(delta_label_seconds 90)" = "↑ 1m" ]
  [ "$(delta_label_seconds -90)" = "↓ 1m" ]
  [ "$(delta_label_seconds 0)" = "→ 0m" ]
}
