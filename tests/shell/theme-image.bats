#!/usr/bin/env bats

setup() {
  OD_BIN="$(command -v od)"
  TR_BIN="$(command -v tr)"
  # shellcheck source=/dev/null
  source "$REPO_ROOT/theme/scripts/lib/is-supported-image.sh"

  tmp="$BATS_TEST_TMPDIR"
  printf '\x89PNG\r\n\x1a\n' >"$tmp/valid.png"
  printf '\xff\xd8\xff\xe0JFIF' >"$tmp/valid.jpg"
  printf '\xff\xd8\xff\xe0JFIF' >"$tmp/valid.jpeg"
  printf 'RIFFxxxxWEBP' >"$tmp/valid.webp"
  printf 'not an image' >"$tmp/invalid.png"
  printf '\x89PNG\r\n\x1a\n' >"$tmp/mismatch.webp"
}

@test "accepts every supported magic and extension pair" {
  for image in valid.png valid.jpg valid.jpeg valid.webp; do
    run is_supported_image "$tmp/$image"
    [ "$status" -eq 0 ]
  done
}

@test "rejects a file whose extension does not match its content" {
  run is_supported_image "$tmp/mismatch.webp"
  [ "$status" -eq 1 ]
}

@test "rejects a file without a supported magic header" {
  run is_supported_image "$tmp/invalid.png"
  [ "$status" -eq 1 ]
}

@test "rejects a missing or unreadable path" {
  run is_supported_image "$tmp/missing.png"
  [ "$status" -eq 1 ]
}
