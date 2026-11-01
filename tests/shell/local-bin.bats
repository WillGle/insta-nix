#!/usr/bin/env bats

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"

  note="$REPO_ROOT/hosts/think14gryzen/assets/local-bin/atomic-note"
  study_source="$REPO_ROOT/hosts/think14gryzen/assets/local-bin/study-timer"
  screen_lib="$REPO_ROOT/hosts/think14gryzen/assets/rofi-screen-time"
  study="$BATS_TEST_TMPDIR/study-timer"
  sed "s|@screenTimeLib@|$screen_lib|g" "$study_source" >"$study"
  chmod +x "$study"
}

@test "atomic-note parses quick-add priority prefixes" {
  bash "$note" add '!! critical task'
  bash "$note" add '! high task'
  bash "$note" add '- low task'
  bash "$note" add 'moderate task'

  run bash "$note" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"[Critical] critical task"* ]]
  [[ "$output" == *"[High] high task"* ]]
  [[ "$output" == *"[Low] low task"* ]]
  [[ "$output" == *"[Moderate] moderate task"* ]]
}

@test "atomic-note accepts an explicit priority argument" {
  bash "$note" add 'Body text' high

  run bash "$note" list
  [ "$status" -eq 0 ]
  [ "$output" = "[High] Body text" ]
}

@test "atomic-note falls back to text priority for an unknown name" {
  bash "$note" add 'Body text' urgent

  run bash "$note" list
  [ "$status" -eq 0 ]
  [ "$output" = "[Moderate] Body text" ]
}

@test "study-timer rejects non-positive durations" {
  run bash "$study" start --duration-minutes 0 --state-dir "$BATS_TEST_TMPDIR/state"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--duration-minutes must be a positive integer"* ]]
}

@test "study-timer requires a duration for session counts" {
  run bash "$study" start --session-count 3 --state-dir "$BATS_TEST_TMPDIR/state"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--session-count requires --duration-minutes"* ]]
}

@test "study-timer records a planned session in its status JSON" {
  state="$BATS_TEST_TMPDIR/state"

  run bash "$study" start --duration-minutes 25 --state-dir "$state" --format json
  [ "$status" -eq 0 ]

  run bash "$study" status --state-dir "$state" --format json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.active' <<<"$output")" = "true" ]
  [ "$(jq -r '.duration_minutes' <<<"$output")" = "25" ]
  [ "$(jq -r '.planned_sessions' <<<"$output")" = "1" ]

  run bash "$study" stop --state-dir "$state" --format json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.active' <<<"$output")" = "false" ]
}
