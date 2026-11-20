#!/usr/bin/env bats

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"

  note="$REPO_ROOT/modules/desktop/apps/atomic-note/assets/atomic-note"
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
