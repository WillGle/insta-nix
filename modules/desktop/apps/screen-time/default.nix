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

  mkScript = import ../../../../lib/mk-script.nix {
    inherit pkgs lib;
    defaultDir = ./assets;
  };

  scriptFile = pkg: {
    source = lib.getExe pkg;
    executable = true;
  };

  screenTimeLib = import ./lib.nix { inherit pkgs signal; };

  screenTimeLibVar = {
    screenTimeLib = "${screenTimeLib}";
  };
in
{
  home = {
    file = {
      ".local/bin/rofi-screen-time" = scriptFile (mkScript {
        name = "rofi-screen-time";
        vars = screenTimeLibVar;
        runtimeInputs = with pkgs; [
          coreutils
          jq
          util-linux
        ];
      });
      ".local/bin/rofi-screen-time-stats" = scriptFile (mkScript {
        name = "rofi-screen-time-stats";
        vars = screenTimeLibVar;
        runtimeInputs = with pkgs; [
          coreutils
          gawk
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
            "${screenTimeLib}/category-map.default.json" \
            "${config.xdg.configHome}/rofi-screen-time/category-map.json"
        else
          ${pkgs.jq}/bin/jq -s '.[0] as $defaults | .[1] as $current | $defaults + {categories: ($defaults.categories + $current.categories)}' \
            "${screenTimeLib}/category-map.default.json" \
            "${config.xdg.configHome}/rofi-screen-time/category-map.json" \
            > "${config.xdg.configHome}/rofi-screen-time/category-map.json.tmp" && \
          ${pkgs.coreutils}/bin/mv "${config.xdg.configHome}/rofi-screen-time/category-map.json.tmp" "${config.xdg.configHome}/rofi-screen-time/category-map.json"
        fi
      '';
    };
  };

  xdg.configFile = {
    "rofi/screen-time.rasi".source = ./assets/screen-time.rasi;
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
    };
  };
}
