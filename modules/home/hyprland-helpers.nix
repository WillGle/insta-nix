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
in
{
  home = {
    file = {
      ".local/bin/monitor-setup" = scriptFile (mkScript {
        name = "monitor-setup";
        runtimeInputs = with pkgs; [
          gnugrep
          hyprland
          jq
          libnotify
        ];
      });

      ".local/bin/screenshot" = scriptFile (mkScript {
        name = "screenshot";
        runtimeInputs = with pkgs; [
          coreutils
          grim
          libnotify
          slurp
          wl-clipboard
        ];
      });

    };

    activation = {
      hyprTouchpadState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        state_file="${touchpadStateConf}"
        if [ ! -e "$state_file" ]; then
          run mkdir -p "$(dirname "$state_file")"
          run install -m 0644 /dev/null "$state_file"
        fi
      '';
    };
  };

  xdg.configFile = {
    "hypr/hyprland.conf".text = renderHostConfig ../../hosts/think14gryzen/assets/hypr/hyprland.conf;
    "hypr/autostart.conf" = {
      source = ../../hosts/think14gryzen/assets/hypr/autostart.conf;
      executable = true;
    };
    "hypr/toggle_waybar.sh" = scriptFile (mkScript {
      name = "toggle_waybar.sh";
      dir = ../../hosts/think14gryzen/assets/hypr;
      runtimeInputs = with pkgs; [ systemd ];
    });
    "hypr/rotate_select.sh" = scriptFile (mkScript {
      name = "rotate_select.sh";
      dir = ../../hosts/think14gryzen/assets/hypr;
      runtimeInputs = with pkgs; [
        gawk
        hyprland
        jq
        libnotify
        procps
      ];
    });
    "hypr/toggle_touchpad.sh" = scriptFile (mkScript {
      name = "toggle_touchpad.sh";
      dir = ../../hosts/think14gryzen/assets/hypr;
      vars = { touchpadStateConf = touchpadStateConf; };
      runtimeInputs = with pkgs; [
        coreutils
        gnugrep
        hyprland
        jq
        libnotify
        util-linux
      ];
    });
  };

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
  };

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
