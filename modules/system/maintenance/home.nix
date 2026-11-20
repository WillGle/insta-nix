{
  config,
  lib,
  pkgs,
  ...
}:
let
  mkScript = import ../../../lib/mk-script.nix {
    inherit pkgs lib;
    defaultDir = ./assets;
  };

  cleanup = mkScript {
    name = "home-cleanup";
    file = "home-cleanup.sh";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gnugrep
      gnused
    ];
    vars = {
      homeUsername = config.home.username;
    };
  };
in
{
  home = {
    file.".local/bin/home-cleanup" = {
      source = lib.getExe cleanup;
      executable = true;
    };

    # One-time elimination of configuration left by the pre-rofi desktop setup.
    # A sentinel keeps later user-created files from being removed on every switch.
    activation.removeObsoleteDesktopConfigs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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

    # Revalidate mutable user shortcuts after every switch. Broken entries are
    # quarantined instead of deleted, so a launch menu cannot keep showing them.
    activation.pruneBrokenDesktopEntries = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${lib.getExe' pkgs.coreutils "env"} \
        XDG_DATA_HOME="${config.xdg.dataHome}" \
        XDG_STATE_HOME="${config.xdg.stateHome}" \
        ${lib.getExe cleanup} --desktop-entries
      run rm -f "${config.xdg.cacheHome}/rofi-drun-desktop.cache"
    '';
  };

  systemd.user.services.home-cleanup = {
    Unit.Description = "Prune old caches and logs, and quarantine broken desktop entries";
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
