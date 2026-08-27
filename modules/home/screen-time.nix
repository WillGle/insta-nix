{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}:
let
  homeDir = config.home.homeDirectory;

  inherit (osConfig.theme) signal;

  mkScript =
    {
      name,
      dir ? ../../hosts/think14gryzen/assets/local-bin,
      runtimeInputs ? [ ],
      vars ? { },
      excludeShellChecks ? [ ],
    }:
    let
      source = dir + "/${name}";
      rendered = if vars == { } then source else pkgs.replaceVars source vars;
      body = lib.concatStringsSep "\n" (lib.drop 1 (lib.splitString "\n" (builtins.readFile rendered)));
    in
    pkgs.writeShellApplication {
      inherit name runtimeInputs excludeShellChecks;
      text = body;
    };

  scriptFile = pkg: {
    source = lib.getExe pkg;
    executable = true;
  };

  rofiScreenTimeLib = pkgs.runCommand "rofi-screen-time-lib" { } ''
    cp -r ${../../hosts/think14gryzen/assets/rofi-screen-time} "$out"
    chmod -R u+w "$out"
    cp ${
      pkgs.replaceVars ../../hosts/think14gryzen/assets/rofi-screen-time/lib/common.sh {
        signalOk = signal.ok;
        signalWarning = signal.warning;
        signalCritical = signal.critical;
      }
    } "$out/lib/common.sh"
  '';

  screenTimeLibVar = {
    screenTimeLib = "${rofiScreenTimeLib}";
  };
in
{
  home = {
    file = {
      ".local/bin/atomic-note" = scriptFile (mkScript {
        name = "atomic-note";
        runtimeInputs = with pkgs; [
          coreutils
          jq
          procps
          util-linux
        ];
        vars = {
          signalOk = signal.ok;
          signalNotice = signal.notice;
          signalWarning = signal.warning;
          signalCritical = signal.critical;
          monoFont = osConfig.theme.fonts.mono.family;
          rofiFontSize = toString osConfig.theme.fonts.rofi.size;
        };
      });
      ".local/bin/rofi-screen-time" = scriptFile (mkScript {
        name = "rofi-screen-time";
        vars = screenTimeLibVar;
        runtimeInputs = with pkgs; [
          coreutils
          jq
          util-linux
        ];
      });
      ".local/bin/rofi-screen-time-cache" = scriptFile (mkScript {
        name = "rofi-screen-time-cache";
        runtimeInputs = with pkgs; [
          coreutils
          util-linux # flock
        ];
      });
      ".local/bin/rofi-screen-time-stats" = scriptFile (mkScript {
        name = "rofi-screen-time-stats";
        vars = screenTimeLibVar;
        runtimeInputs = with pkgs; [
          coreutils
          jq
        ];
      });
      ".local/bin/rofi-screen-time-track" = scriptFile (mkScript {
        name = "rofi-screen-time-track";
        vars = screenTimeLibVar;
        runtimeInputs = with pkgs; [
          coreutils
          findutils
          gawk
          gnugrep
          hyprland
          jq
          procps
          util-linux
        ];
      });
      ".local/bin/screen-time-behavior-export" = scriptFile (mkScript {
        name = "screen-time-behavior-export";
        runtimeInputs = with pkgs; [
          coreutils
          jq
        ];
      });
      ".local/bin/rofi-study-timer" = scriptFile (mkScript {
        name = "rofi-study-timer";
        runtimeInputs = with pkgs; [
          coreutils
          gnused
          jq
          util-linux
        ];
      });
      ".local/bin/study-timer" = scriptFile (mkScript {
        name = "study-timer";
        vars = screenTimeLibVar;
        runtimeInputs = with pkgs; [
          coreutils
          jq
          libnotify
          procps
          systemd
          util-linux
        ];
      });
    };

    activation = {
      rofiScreenTimeCategoryMapSeed = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        ${pkgs.coreutils}/bin/mkdir -p "${config.xdg.configHome}/rofi-screen-time"
        if [ ! -e "${config.xdg.configHome}/rofi-screen-time/category-map.json" ]; then
          ${pkgs.coreutils}/bin/cp \
            "${rofiScreenTimeLib}/category-map.default.json" \
            "${config.xdg.configHome}/rofi-screen-time/category-map.json"
        else
          ${pkgs.jq}/bin/jq -s '.[0] as $defaults | .[1] as $current | $defaults + {categories: ($defaults.categories + $current.categories)}' \
            "${rofiScreenTimeLib}/category-map.default.json" \
            "${config.xdg.configHome}/rofi-screen-time/category-map.json" \
            > "${config.xdg.configHome}/rofi-screen-time/category-map.json.tmp" && \
          ${pkgs.coreutils}/bin/mv "${config.xdg.configHome}/rofi-screen-time/category-map.json.tmp" "${config.xdg.configHome}/rofi-screen-time/category-map.json"
        fi
      '';
    };
  };

  xdg.configFile = {
    "rofi/screen-time.rasi".source = ../../hosts/think14gryzen/assets/rofi/screen-time.rasi;
    "rofi/study-timer.rasi".source = ../../hosts/think14gryzen/assets/rofi/study-timer.rasi;
  };

  systemd.user = {
    services = {
      rofi-screen-time-tracker = {
        Unit = {
          Description = "Track active application usage for the rofi screen-time dashboard";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${homeDir}/.local/bin/rofi-screen-time-track --interval-seconds 5";
          Restart = "always";
          RestartSec = "2s";
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };

      # The tracker pauses when logind reports the session idle (or hyprlock is
      # up). Idle management is off by design on this host: hypridle is not
      # enabled, so nothing ever set IdleHint and screen time was really
      # "unlocked time" — a 20-minute coffee break counted for whatever window
      # was focused. swayidle here does exactly one thing:
      # flag the session idle after 5 minutes without input. No DPMS, no lock,
      # no suspend; hypridle has no equivalent option, which is why it is
      # swayidle. Restarting on failure keeps a compositor hiccup from leaving
      # the tracker blind for the rest of the session.
      rofi-screen-time-idlehint = {
        Unit = {
          Description = "Mark the session idle for the screen-time tracker";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.swayidle}/bin/swayidle -w idlehint 300";
          Restart = "on-failure";
          RestartSec = "5s";
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };

      rofi-screen-time-cache = {
        Unit = {
          Description = "Warm the default rofi screen-time popup cache";
          After = [
            "graphical-session.target"
            "rofi-screen-time-tracker.service"
          ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${homeDir}/.local/bin/rofi-screen-time-cache";
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    };

    timers = {
      rofi-screen-time-cache = {
        Unit = {
          Description = "Refresh the default rofi screen-time popup cache";
          PartOf = [ "graphical-session.target" ];
        };
        Timer = {
          OnActiveSec = "20s";
          # A warm costs ~10 s of CPU (four views rendered by bash+jq). At 2 m
          # that was ~9% of a core all day for a popup opened a few times a
          # day; the popup now refreshes a stale cache itself on open, so the
          # timer only has to keep it from going cold.
          OnUnitActiveSec = "5m";
          Unit = "rofi-screen-time-cache.service";
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    };
  };
}
