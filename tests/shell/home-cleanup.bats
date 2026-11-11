#!/usr/bin/env bats

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export XDG_DATA_HOME="$BATS_TEST_TMPDIR/data"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  apps="$XDG_DATA_HOME/applications"
  mkdir -p "$HOME" "$apps"
  cleanup="${HOME_CLEANUP_BIN:?HOME_CLEANUP_BIN must point to home-cleanup}"
}

write_entry() {
  local file="$apps/$1.desktop" body="$2"
  printf '[Desktop Entry]\nType=Application\nName=%s\n%s\n' "$1" "$body" >"$file"
}

quarantined_path() {
  find "$XDG_STATE_HOME/home-cleanup/quarantined-desktop-entries" \
    -name "$1.desktop" -print -quit 2>/dev/null
}

@test "home-cleanup keeps working desktop entries" {
  write_entry valid 'TryExec=true
Exec=true --version'

  run "$cleanup" --desktop-entries
  [ "$status" -eq 0 ]
  [ -f "$apps/valid.desktop" ]
}

@test "home-cleanup quarantines an entry whose Exec is missing" {
  write_entry broken 'Exec=home-cleanup-missing-command'

  run "$cleanup" --desktop-entries
  [ "$status" -eq 0 ]
  [ ! -e "$apps/broken.desktop" ]
  [ -n "$(quarantined_path broken)" ]
  [[ "$output" == *"quarantined:"* ]]
}

@test "home-cleanup skips hidden and no-display entries" {
  write_entry hidden 'Exec=home-cleanup-missing-command
Hidden=true'
  write_entry nodisplay 'Exec=home-cleanup-missing-command
NoDisplay = true'

  run "$cleanup" --desktop-entries
  [ "$status" -eq 0 ]
  [ -f "$apps/hidden.desktop" ]
  [ -f "$apps/nodisplay.desktop" ]
}

@test "home-cleanup leaves entries on external paths alone" {
  write_entry external 'Exec=/media/external/home-cleanup-missing-command'

  run "$cleanup" --desktop-entries
  [ "$status" -eq 0 ]
  [ -f "$apps/external.desktop" ]
}

@test "home-cleanup leaves entries under an absent home mount point alone" {
  write_entry unmounted "Exec=$HOME/media/usb/home-cleanup-missing-command"

  run "$cleanup" --desktop-entries
  [ "$status" -eq 0 ]
  [ -f "$apps/unmounted.desktop" ]
}

@test "home-cleanup quarantines dangling desktop symlinks" {
  ln -s "$BATS_TEST_TMPDIR/missing.desktop" "$apps/dangling.desktop"

  run "$cleanup" --desktop-entries
  [ "$status" -eq 0 ]
  [ ! -L "$apps/dangling.desktop" ]
  [ -L "$(quarantined_path dangling)" ]
}

@test "home-cleanup checks Exec even when TryExec exists" {
  write_entry stale-tryexec 'TryExec=true
Exec=home-cleanup-missing-command'

  run "$cleanup" --desktop-entries
  [ "$status" -eq 0 ]
  [ ! -e "$apps/stale-tryexec.desktop" ]
  [ -n "$(quarantined_path stale-tryexec)" ]
}

@test "home-cleanup quarantines an entry whose TryExec is missing" {
  write_entry stale 'TryExec=home-cleanup-missing-command
Exec=true'

  run "$cleanup" --desktop-entries
  [ "$status" -eq 0 ]
  [ ! -e "$apps/stale.desktop" ]
  [ -n "$(quarantined_path stale)" ]
}

@test "home-cleanup --desktop-entries leaves unrelated caches alone" {
  mkdir -p "$HOME/.cache/unrelated-cache"
  touch -d '30 days ago' "$HOME/.cache/unrelated-cache/data"

  run "$cleanup" --desktop-entries
  [ "$status" -eq 0 ]
  [ -f "$HOME/.cache/unrelated-cache/data" ]
}

@test "home-cleanup --dry-run reports broken entries without moving them" {
  write_entry broken 'Exec=home-cleanup-missing-command'

  run "$cleanup" --dry-run
  [ "$status" -eq 0 ]
  [ -f "$apps/broken.desktop" ]
  [[ "$output" == *"would quarantine:"* ]]
}
