is_supported_image() {
  local file="$1" ext magic

  [ -f "$file" ] && [ -r "$file" ] || return 1

  ext="${file##*.}"
  ext="${ext,,}"
  magic="$("$OD_BIN" -An -v -tx1 -N16 "$file" 2>/dev/null | "$TR_BIN" -d ' \n')" || return 1

  case "$ext" in
    png) [ "${magic:0:16}" = "89504e470d0a1a0a" ] ;;
    jpg | jpeg) [ "${magic:0:6}" = "ffd8ff" ] ;;
    webp) [ "${magic:0:8}" = "52494646" ] && [ "${magic:16:8}" = "57454250" ] ;;
    *) return 1 ;;
  esac
}
