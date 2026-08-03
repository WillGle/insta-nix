{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  themeGeneratedDir = "${config.xdg.configHome}/theme/generated";
  renderHostConfig =
    path:
    builtins.replaceStrings
      [
        "/home/will"
        "__CURSOR_NAME__"
        "__CURSOR_SIZE__"
        "__THEME_GENERATED_DIR__"
      ]
      [
        homeDir
        osConfig.theme.cursor.name
        (toString osConfig.theme.cursor.size)
        themeGeneratedDir
      ]
      (builtins.readFile path);
in
{
  home.file = {
    ".local/bin/atomic-note" = {
      source = ./assets/local-bin/atomic-note;
      executable = true;
    };
    ".local/bin/rofi-code" = {
      source = ./assets/local-bin/rofi-code;
      executable = true;
    };
    ".local/bin/monitor-setup" = {
      source = ./assets/local-bin/monitor-setup;
      executable = true;
    };
    ".local/bin/rofi-network" = {
      source = ./assets/local-bin/rofi-network;
      executable = true;
    };
    ".local/bin/rofi-screen-time" = {
      source = ./assets/local-bin/rofi-screen-time;
      executable = true;
    };
    ".local/lib/rofi-screen-time".source = ./assets/rofi-screen-time;
    ".local/bin/rofi-screen-time-cache" = {
      source = ./assets/local-bin/rofi-screen-time-cache;
      executable = true;
    };
    ".local/bin/rofi-screen-time-stats" = {
      source = ./assets/local-bin/rofi-screen-time-stats;
      executable = true;
    };
    ".local/bin/rofi-screen-time-track" = {
      source = ./assets/local-bin/rofi-screen-time-track;
      executable = true;
    };
    ".local/bin/screen-time-behavior-export" = {
      source = ./assets/local-bin/screen-time-behavior-export;
      executable = true;
    };
    ".local/bin/rofi-study-timer" = {
      source = ./assets/local-bin/rofi-study-timer;
      executable = true;
    };
    ".local/bin/study-timer" = {
      source = ./assets/local-bin/study-timer;
      executable = true;
    };
    ".local/bin/waybar-memory-info" = {
      source = ./assets/local-bin/waybar-memory-info;
      executable = true;
    };
    ".local/bin/waybar-network-info" = {
      source = ./assets/local-bin/waybar-network-info;
      executable = true;
    };
    ".local/bin/waybar-screen-time" = {
      source = ./assets/local-bin/waybar-screen-time;
      executable = true;
    };
    ".local/bin/waybar-power-monitor" = {
      source = ./assets/local-bin/waybar-power-monitor;
      executable = true;
    };
    ".local/bin/waybar-refresh-label" = {
      source = ./assets/local-bin/waybar-refresh-label;
      executable = true;
    };
    ".local/bin/waybar-refresh-toggle" = {
      source = ./assets/local-bin/waybar-refresh-toggle;
      executable = true;
    };
    ".local/bin/waybar-systemd-failed" = {
      source = ./assets/local-bin/waybar-systemd-failed;
      executable = true;
    };
  };

  xdg.configFile = {
    "hypr/hyprland.conf".text = renderHostConfig ./assets/hypr/hyprland.conf;
    "hypr/hypridle.conf".source = ./assets/hypr/hypridle.conf;
    "hypr/autostart.conf" = {
      source = ./assets/hypr/autostart.conf;
      executable = true;
    };
    "hypr/toggle_waybar.sh" = {
      source = ./assets/hypr/toggle_waybar.sh;
      executable = true;
    };
    "hypr/rotate_select.sh" = {
      source = ./assets/hypr/rotate_select.sh;
      executable = true;
    };
    "hypr/toggle_touchpad.sh" = {
      source = ./assets/hypr/toggle_touchpad.sh;
      executable = true;
    };
    "rofi/screen-time.rasi".source = ./assets/rofi/screen-time.rasi;
    "rofi/study-timer.rasi".source = ./assets/rofi/study-timer.rasi;
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
          OnBootSec = "20s";
          OnUnitActiveSec = "2m";
          Unit = "rofi-screen-time-cache.service";
        };
        Install = {
          WantedBy = [ "timers.target" ];
        };
      };
    };
  };

  home.activation.rofiScreenTimeCategoryMapSeed = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${pkgs.coreutils}/bin/mkdir -p "${config.xdg.configHome}/rofi-screen-time"
    if [ ! -e "${config.xdg.configHome}/rofi-screen-time/category-map.json" ]; then
      ${pkgs.coreutils}/bin/cp \
        "${homeDir}/.local/lib/rofi-screen-time/category-map.default.json" \
        "${config.xdg.configHome}/rofi-screen-time/category-map.json"
    else
      ${pkgs.jq}/bin/jq -s '.[0] as $defaults | .[1] as $current | $defaults + {categories: ($defaults.categories + $current.categories)}' \
        "${homeDir}/.local/lib/rofi-screen-time/category-map.default.json" \
        "${config.xdg.configHome}/rofi-screen-time/category-map.json" \
        > "${config.xdg.configHome}/rofi-screen-time/category-map.json.tmp" && \
      ${pkgs.coreutils}/bin/mv "${config.xdg.configHome}/rofi-screen-time/category-map.json.tmp" "${config.xdg.configHome}/rofi-screen-time/category-map.json"
    fi
  '';

  xdg.dataFile."applications/org.rnd2.cpupower_gui.desktop".text = ''
    [Desktop Entry]
    Version=1.1
    Name=cpupower-gui
    GenericName=CPU frequency settings
    Comment=Sets the frequency limits of the CPU
    Exec=/run/current-system/sw/bin/cpupower-gui
    Icon=org.rnd2.cpupower_gui
    Terminal=false
    Type=Application
    StartupNotify=true
    Categories=GNOME;GTK;Settings;HardwareSettings;
  '';
}
