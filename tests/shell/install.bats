#!/usr/bin/env bats

setup() {
  install="$REPO_ROOT/install.sh"
}

@test "install.sh prints usage" {
  run bash "$install" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "install.sh requires a disk" {
  run bash "$install"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "install.sh rejects unknown arguments" {
  run bash "$install" --unknown
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown argument"* ]]
}
