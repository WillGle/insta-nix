{
  config,
  lib,
  pkgs,
  ...
}:
let
  cacheMaxAgeDays = 14;
  historyKeepDays = 180;
  logMaxAgeDays = 14;

  # Use a denylist because application cache names vary. Protect history,
  # expensive rebuilds, editor state, and browser data from the broad sweep.
  protectedCaches = [
    "cliphist"
    "nix"
    "zed"
    "Zed"
    "Code"
    "vscode"
    "brave"
    "BraveSoftware"
    "firefox"
    "mozilla"
    "chromium"
    "google-chrome"
    "fontconfig"
    "mesa_shader_cache"
    "obs-studio"
    "darktable"
    "rawtherapee"
    "tauon"
    "mpv"
  ];

  cleanup = pkgs.writeShellApplication {
    name = "home-cleanup";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
    ];
    text = ''
      dry_run=false
      case "''${1:-}" in
        --dry-run) dry_run=true ;;
        "") ;;
        *)
          printf 'Usage: home-cleanup [--dry-run]\n' >&2
          exit 2
          ;;
      esac

      cache_dir="$HOME/.cache"
      history_dir="$HOME/.local/share/rofi-screen-time/days"
      zed_log_dir="$HOME/.local/share/zed/logs"

      remove_path() {
        if [ "$dry_run" = true ]; then
          printf 'would remove: %s\n' "$1"
        else
          rm -rf -- "$1"
        fi
      }

      prune_old_cache_entries() {
        [ -d "$cache_dir" ] || return 0
        local entry name protected_name
        while IFS= read -r -d "" entry; do
          name="''${entry##*/}"
          [ -L "$entry" ] && continue
          protected=false
          for protected_name in ${lib.escapeShellArgs protectedCaches}; do
            if [ "$name" = "$protected_name" ]; then
              protected=true
              break
            fi
          done
          [ "$protected" = true ] && continue

          # Keep an entry if anything inside it changed within the window.
          if [ -z "$(find "$entry" -mtime -"${toString cacheMaxAgeDays}" -print -quit 2>/dev/null)" ]; then
            remove_path "$entry"
          fi
        done < <(find "$cache_dir" -mindepth 1 -maxdepth 1 -print0)
      }

      prune_generated_caches() {
        # rofi rebuilds this on the next launcher open.
        if [ -e "$HOME/.cache/rofi-drun-desktop.cache" ]; then
          remove_path "$HOME/.cache/rofi-drun-desktop.cache"
        fi
        if [ -d "$HOME/.cache/rofi-screen-time" ]; then
          while IFS= read -r -d "" file; do
            remove_path "$file"
          done < <(find "$HOME/.cache/rofi-screen-time" -type f -mtime +7 -print0)
        fi
      }

      prune_logs() {
        [ -d "$zed_log_dir" ] || return 0
        while IFS= read -r -d "" file; do
          remove_path "$file"
        done < <(find "$zed_log_dir" -type f -mtime +"${toString logMaxAgeDays}" -print0)
      }

      prune_screen_time_history() {
        [ -d "$history_dir" ] || return 0
        while IFS= read -r -d "" file; do
          remove_path "$file"
        done < <(find "$history_dir" -maxdepth 1 -type f -name '*.json' \
          -mtime +"${toString historyKeepDays}" -print0)
      }

      prune_old_cache_entries
      prune_generated_caches
      prune_logs
      prune_screen_time_history
    '';
  };
in
{
  home.file.".local/bin/home-cleanup" = {
    source = lib.getExe cleanup;
    executable = true;
  };

  # One-time elimination of configuration left by the pre-rofi desktop setup.
  # A sentinel keeps later user-created files from being removed on every switch.
  home.activation.removeObsoleteDesktopConfigs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    obsolete_marker="${config.xdg.stateHome}/home-cleanup/obsolete-desktop-configs-removed"
    if [ ! -e "$obsolete_marker" ]; then
      run rm -f -- \
        "${config.xdg.configHome}/wofi/config-app.ini.backup" \
        "${config.xdg.configHome}/wofi/config-clip.ini.backup" \
        "${config.xdg.configHome}/wofi/style.css.backup" \
        "${config.xdg.configHome}/sway/config"
      run rmdir --ignore-fail-on-non-empty \
        "${config.xdg.configHome}/wofi" \
        "${config.xdg.configHome}/sway" 2>/dev/null || true
      run mkdir -p "$(dirname "$obsolete_marker")"
      run touch "$obsolete_marker"
    fi
  '';

  systemd.user.services.home-cleanup = {
    Unit.Description = "Prune old caches, logs, and generated rofi state";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe cleanup;
      Nice = 19;
    };
  };

  systemd.user.timers.home-cleanup = {
    Unit.Description = "Weekly user cache and log cleanup";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
