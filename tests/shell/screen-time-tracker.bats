#!/usr/bin/env bats

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export XDG_DATA_HOME="$HOME/.local/share"
  export XDG_CACHE_HOME="$HOME/.cache"
  mkdir -p "$HOME"
  state="$BATS_TEST_TMPDIR/state"
  tracker="$BATS_TEST_TMPDIR/rofi-screen-time-track"
  sed "s|@screenTimeLib@|$REPO_ROOT/modules/desktop/apps/screen-time|g" \
    "$REPO_ROOT/modules/desktop/apps/screen-time/assets/rofi-screen-time-track" >"$tracker"
  chmod +x "$tracker"

  export SCREEN_TIME_HOME="$state"
  export SCREEN_TIME_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
  export SCREEN_TIME_TEST_IDLE_HINT=no
  export SCREEN_TIME_TEST_LOCKED=0
}

run_tracker() {
  run env SCREEN_TIME_TEST_ACTIVEWINDOW_JSON="$1" bash "$tracker" --once
}

@test "tracker writes minimal v3 day data" {
  run_tracker '{"initialClass":"firefox","initialTitle":"Mozilla Firefox"}'
  [ "$status" -eq 0 ]

  day="$state/days/$(date +%F).json"
  [ -f "$day" ]
  [ "$(jq -r '.version' "$day")" = "3" ]
  [ "$(jq -r '.total_seconds' "$day")" = "5" ]
  [ "$(jq -r '.apps.firefox.seconds' "$day")" = "5" ]
  [ "$(jq -r '.slots_30m | length' "$day")" = "48" ]
  [ "$(jq -r 'has("study") or has("behavior") or has("session_count")' "$day")" = "false" ]
}

@test "tracker accumulates the same app across samples" {
  run_tracker '{"initialClass":"firefox","initialTitle":"Mozilla Firefox"}'
  run_tracker '{"initialClass":"firefox","initialTitle":"Mozilla Firefox"}'

  day="$state/days/$(date +%F).json"
  [ "$(jq -r '.sample_count' "$day")" = "2" ]
  [ "$(jq -r '.total_seconds' "$day")" = "10" ]
  [ "$(jq -r '.apps.firefox.seconds' "$day")" = "10" ]
  [ "$(jq -r '.apps.firefox.sample_count' "$day")" = "2" ]
}
