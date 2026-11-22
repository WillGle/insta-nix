#!/usr/bin/env bash

cache_max_age_days=14
log_max_age_days=14

# Use a denylist because application cache names vary. Protect history,
# expensive rebuilds, editor state, and browser data from the broad sweep.
protected_caches=(
  cliphist
  nix
  zed
  Zed
  Code
  vscode
  brave
  BraveSoftware
  firefox
  mozilla
  chromium
  google-chrome
  fontconfig
  mesa_shader_cache
  obs-studio
  darktable
  rawtherapee
  tauon
  mpv
)

dry_run=false
desktop_entries_only=false
case "${1:-}" in
  --dry-run) dry_run=true ;;
  --desktop-entries) desktop_entries_only=true ;;
  "") ;;
  *)
    printf 'Usage: home-cleanup [--dry-run | --desktop-entries]\n' >&2
    exit 2
    ;;
esac

cache_dir="$HOME/.cache"
zed_log_dir="$HOME/.local/share/zed/logs"
applications_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
quarantine_root="${XDG_STATE_HOME:-$HOME/.local/state}/home-cleanup/quarantined-desktop-entries"
desktop_path="$HOME/.local/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/@homeUsername@/bin:/run/current-system/sw/bin:$HOME/.local/share/flatpak/exports/bin:${PATH:-}"
quarantine_session=""

remove_path() {
  if [ "$dry_run" = true ]; then
    printf 'would remove: %s\n' "$1"
  else
    rm -rf -- "$1"
  fi
}

desktop_entry_value() {
  local key="$1" file="$2"
  sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "$file" \
    | head -n 1 | tr -d '\r' || true
}

command_available() {
  local cmd="$1"
  case "$cmd" in
    /* | */*) [ -x "$cmd" ] ;;
    *) PATH="$desktop_path" command -v -- "$cmd" >/dev/null 2>&1 ;;
  esac
}

first_exec_word() {
  local line="$1" word
  line="${line#"${line%%[![:space:]]*}"}"
  case "$line" in
    \"*) word="${line#\"}"; word="${word%%\"*}" ;;
    \'*) word="${line#\'}"; word="${word%%\'*}" ;;
    *) word="${line%%[[:space:]]*}" ;;
  esac
  printf '%s\n' "$word"
}

# Only quarantine shortcuts whose missing target is owned by Nix or the
# user. A shortcut on an unmounted external drive is left untouched.
desktop_entry_is_prunable() {
  local cmd="$1"
  case "$cmd" in
    /*)
      case "$cmd" in
        /nix/store/*) return 0 ;;
        "$HOME"/*)
          # Keep entries whose parent directory is absent; it may be an
          # unmounted mount point inside the home directory.
          [ -d "${cmd%/*}" ]
          ;;
        *) return 1 ;;
      esac
      ;;
    */*) return 1 ;;
    *) return 0 ;;
  esac
}

quarantine_desktop_entry() {
  local path="$1" reason="$2" stamp destination
  if [ "$dry_run" = true ]; then
    printf 'would quarantine: %s (%s)\n' "$path" "$reason"
    return 0
  fi
  if [ -z "$quarantine_session" ]; then
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    quarantine_session="$quarantine_root/$stamp"
    if ! mkdir -p "$quarantine_session"; then
      printf 'warning: cannot create quarantine directory: %s\n' "$quarantine_session" >&2
      quarantine_session=""
      return 0
    fi
  fi
  destination="$quarantine_session/${path##*/}"
  if [ -e "$destination" ] || [ -L "$destination" ]; then
    destination="$destination.$$"
  fi
  if mv -- "$path" "$destination"; then
    printf 'quarantined: %s (%s) -> %s\n' "$path" "$reason" "$destination"
  else
    printf 'warning: could not quarantine: %s\n' "$path" >&2
  fi
}

prune_broken_desktop_entries() {
  [ -d "$applications_dir" ] || return 0
  local path type try_exec exec_line command_word
  while IFS= read -r -d "" path; do
    if [ -L "$path" ] && [ ! -e "$path" ]; then
      quarantine_desktop_entry "$path" "dangling symlink"
      continue
    fi
    if [ ! -f "$path" ] || [ ! -r "$path" ]; then
      continue
    fi

    type="$(desktop_entry_value Type "$path")"
    [ "$type" = "Application" ] || continue
    if grep -Eq '^[[:space:]]*(Hidden|NoDisplay)[[:space:]]*=[[:space:]]*true' "$path"; then
      continue
    fi

    try_exec="$(desktop_entry_value TryExec "$path")"
    try_exec="${try_exec#"${try_exec%%[![:space:]]*}"}"
    if [ -n "$try_exec" ] && ! command_available "$try_exec" \
      && desktop_entry_is_prunable "$try_exec"; then
      quarantine_desktop_entry "$path" "TryExec not found: $try_exec"
      continue
    fi

    exec_line="$(desktop_entry_value Exec "$path")"
    command_word="$(first_exec_word "$exec_line")"
    [ -n "$command_word" ] || continue
    # Environment assignments are not commands; leave such lines alone.
    case "$command_word" in
      /*) ;;
      *=*) continue ;;
    esac
    if ! command_available "$command_word" && desktop_entry_is_prunable "$command_word"; then
      quarantine_desktop_entry "$path" "Exec not found: $command_word"
    fi
  done < <(find "$applications_dir" -maxdepth 1 -name '*.desktop' -print0)
}

prune_old_cache_entries() {
  [ -d "$cache_dir" ] || return 0
  local entry name protected_name
  while IFS= read -r -d "" entry; do
    name="${entry##*/}"
    [ -L "$entry" ] && continue
    protected=false
    for protected_name in "${protected_caches[@]}"; do
      if [ "$name" = "$protected_name" ]; then
        protected=true
        break
      fi
    done
    [ "$protected" = true ] && continue

    # Keep an entry if anything inside it changed within the window.
    if [ -z "$(find "$entry" -mtime -"${cache_max_age_days}" -print -quit 2>/dev/null)" ]; then
      remove_path "$entry"
    fi
  done < <(find "$cache_dir" -mindepth 1 -maxdepth 1 -print0)
}

prune_generated_caches() {
  # rofi rebuilds this on the next launcher open.
  if [ -e "$HOME/.cache/rofi-drun-desktop.cache" ]; then
    remove_path "$HOME/.cache/rofi-drun-desktop.cache"
  fi
}

prune_logs() {
  [ -d "$zed_log_dir" ] || return 0
  while IFS= read -r -d "" file; do
    remove_path "$file"
  done < <(find "$zed_log_dir" -type f -mtime +"${log_max_age_days}" -print0)
}

if [ "$desktop_entries_only" = false ]; then
  prune_old_cache_entries
  prune_generated_caches
  prune_logs
fi
prune_broken_desktop_entries
