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

  mkScript = import ../assets/mk-script.nix {
    inherit pkgs lib;
    defaultDir = ../assets/local-bin;
  };

  scriptFile = pkg: {
    source = lib.getExe pkg;
    executable = true;
  };

  rofiScreenTimeLib = import ../assets/screen-time-lib.nix { inherit pkgs signal; };

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
    "rofi/screen-time.rasi".source = ../assets/rofi/screen-time.rasi;
    "rofi/study-timer.rasi".source = ../assets/rofi/study-timer.rasi;
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

      # swayidle supplies IdleHint so the tracker excludes time without input.
      # hypridle lacks idlehint support; leave display, lock, and suspend unchanged.
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
          # Cache rendering costs about 10 CPU seconds; the popup refreshes stale
          # data on open, so frequent background refreshes waste CPU.
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
