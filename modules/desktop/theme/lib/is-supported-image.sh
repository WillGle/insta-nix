image_extension() {
  local file="$1" magic

  [ -f "$file" ] && [ -r "$file" ] || return 1

  magic="$("$OD_BIN" -An -v -tx1 -N16 "$file" 2>/dev/null | "$TR_BIN" -d ' \n')" || return 1

  if [ "${magic:0:16}" = "89504e470d0a1a0a" ]; then
    printf 'png\n'
  elif [ "${magic:0:6}" = "ffd8ff" ]; then
    printf 'jpg\n'
  elif [ "${magic:0:8}" = "52494646" ] && [ "${magic:16:8}" = "57454250" ]; then
    printf 'webp\n'
  else
    return 1
  fi
}

is_supported_image() {
  local file="$1" ext detected
  ext="${file##*.}"
  ext="${ext,,}"
  [ "$ext" != "jpeg" ] || ext=jpg
  detected="$(image_extension "$file")" || return 1
  [ "$ext" = "$detected" ]
}
