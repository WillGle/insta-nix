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
  touchpadStateConf = "${config.xdg.stateHome}/hypr/touchpad.conf";
  renderHostConfig =
    path:
    builtins.replaceStrings
      [
        "/home/will"
        "__CURSOR_NAME__"
        "__CURSOR_SIZE__"
        "__THEME_GENERATED_DIR__"
        "__TOUCHPAD_STATE_CONF__"
      ]
      [
        homeDir
        osConfig.theme.cursor.name
        (toString osConfig.theme.cursor.size)
        themeGeneratedDir
        touchpadStateConf
      ]
      (builtins.readFile path);

  # Signal palette injected into scripts as @name@ placeholders. Scripts must
  # never carry a semantic color literal of their own: theme.signal is the one
  # source, and replaceVars fails the build on an unsubstituted placeholder, so
  # a drifted copy cannot ship.
  # replaceVars is strict both ways: an unsubstituted @var@ fails the build, and
  # so does an entry the file never uses. Each script therefore declares exactly
  # the palette it needs, and a color it stops using cannot linger unnoticed.
  signal = osConfig.theme.signal;
  # Decorative only — tooltip headings. Kept separate so it is never mistaken
  # for a token that may encode a state.
  themeAccent = osConfig.theme.colors.accent;

  # Package a local-bin script instead of copying it verbatim. Three guarantees
  # the plain `source =` install cannot give:
  #   - shellcheck runs at build time and a real defect fails the build
  #   - `set -euo pipefail` is applied by the builder, not by remembering to type it
  #   - PATH is closed over runtimeInputs, so a script can no longer degrade
  #     silently when a tool is absent from the session environment
  mkScript =
    {
      name,
      runtimeInputs ? [ ],
      vars ? { },
      excludeShellChecks ? [ ],
    }:
    let
      source = ./assets/local-bin + "/${name}";
      rendered = if vars == { } then source else pkgs.replaceVars source vars;
      # writeShellApplication supplies its own shebang; keep the asset runnable
      # standalone but drop its line here so the output has exactly one.
      body = lib.concatStringsSep "\n" (lib.drop 1 (lib.splitString "\n" (builtins.readFile rendered)));
    in
    pkgs.writeShellApplication {
      inherit name runtimeInputs excludeShellChecks;
      text = body;
    };

  # Same install path as before so waybar's config.jsonc keeps working unchanged.
  scriptFile = pkg: {
    source = lib.getExe pkg;
    executable = true;
  };

  # Build-time substitution without full packaging, for scripts whose runtime
  # dependency set has not been audited yet. Weaker than mkScript — no
  # shellcheck, no closed PATH — but it still removes the color literal, which
  # is what makes a severity ladder drift.
  substScript = name: vars: {
    source = pkgs.replaceVars (./assets/local-bin + "/${name}") vars;
    executable = true;
  };

  # The tracker library is installed as a whole directory, so the one file that
  # carries semantic colors is re-rendered over the copy.
  rofiScreenTimeLib = pkgs.runCommand "rofi-screen-time-lib" { } ''
    cp -r ${./assets/rofi-screen-time} "$out"
    chmod -R u+w "$out"
    cp ${
      pkgs.replaceVars ./assets/rofi-screen-time/lib/common.sh {
        signalOk = signal.ok;
        signalWarning = signal.warning;
        signalCritical = signal.critical;
      }
    } "$out/lib/common.sh"
  '';
in
{
  home.file = {
    ".local/bin/atomic-note" = substScript "atomic-note" {
      signalOk = signal.ok;
      signalNotice = signal.notice;
      signalWarning = signal.warning;
      signalCritical = signal.critical;
      monoFont = osConfig.theme.fonts.mono.family;
      rofiFontSize = toString osConfig.theme.fonts.rofi.size;
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
    ".local/lib/rofi-screen-time".source = rofiScreenTimeLib;
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
    ".local/bin/waybar-memory-info" = scriptFile (mkScript {
      name = "waybar-memory-info";
      runtimeInputs = with pkgs; [
        coreutils
        gawk
        gnused
        jq
        procps
      ];
      vars = { inherit themeAccent; };
    });
    ".local/bin/waybar-network-info" = scriptFile (mkScript {
      name = "waybar-network-info";
      runtimeInputs = with pkgs; [
        bluez
        coreutils
        gawk
        gnugrep
        gnused
        iproute2
        jq
        networkmanager
        wireguard-tools
      ];
      vars = { inherit themeAccent; };
      # A helper reads a variable the caller sets; shellcheck cannot see across
      # that boundary.
      excludeShellChecks = [ "SC2034" ];
    });
    ".local/bin/waybar-screen-time" = scriptFile (mkScript {
      name = "waybar-screen-time";
      runtimeInputs = with pkgs; [
        coreutils
        gnused
        hyprland
        jq
        procps
      ];
      vars = { inherit themeAccent; };
    });
    ".local/bin/waybar-power-monitor" = scriptFile (mkScript {
      name = "waybar-power-monitor";
      runtimeInputs = with pkgs; [
        coreutils
        findutils
        gawk
        gnused
        procps
      ];
      vars = {
        inherit themeAccent;
        signalWarning = signal.warning;
        signalEco = signal.eco;
      };
      excludeShellChecks = [ "SC2034" ];
    });
    ".local/bin/waybar-refresh-label" = scriptFile (mkScript {
      name = "waybar-refresh-label";
      runtimeInputs = with pkgs; [
        hyprland
        jq
      ];
    });
    ".local/bin/waybar-refresh-toggle" = scriptFile (mkScript {
      name = "waybar-refresh-toggle";
      runtimeInputs = with pkgs; [
        hyprland
        jq
        libnotify
      ];
    });
    ".local/bin/waybar-systemd-failed" = scriptFile (mkScript {
      name = "waybar-systemd-failed";
      runtimeInputs = with pkgs; [
        coreutils
        gawk
        gnused
        jq
        systemd
      ];
      vars = {
        signalOk = signal.ok;
        signalWarning = signal.warning;
        signalCritical = signal.critical;
      };
    });
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

  # hyprland.conf sources this file, and toggle_touchpad.sh rewrites it. Seed it
  # here so the source never dangles on a fresh machine; it must stay writable,
  # hence an activation script rather than an xdg.configFile symlink.
  home.activation.hyprTouchpadState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    state_file="${touchpadStateConf}"
    if [ ! -e "$state_file" ]; then
      run mkdir -p "$(dirname "$state_file")"
      run install -m 0644 /dev/null "$state_file"
    fi
  '';

  systemd.user = {
    targets.hyprland-session = {
      Unit = {
        Description = "Hyprland graphical session";
        BindsTo = [ "graphical-session.target" ];
        Wants = [ "graphical-session-pre.target" ];
        After = [ "graphical-session-pre.target" ];
        PropagatesStopTo = [ "graphical-session.target" ];
      };
    };

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
          OnUnitActiveSec = "2m";
          Unit = "rofi-screen-time-cache.service";
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
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
