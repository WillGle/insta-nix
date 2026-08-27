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

      # Lives here rather than in waybar-helpers because it is a capture tool
      # first — sibling of screenshot, bound to a key — and a bar module second.
      ".local/bin/screen-rec" = scriptFile (mkScript {
        name = "screen-rec";
        runtimeInputs = with pkgs; [
          coreutils
          gnugrep
          jq
          libnotify
          procps
          slurp
          wf-recorder
          wireplumber
        ];
        vars = {
          signalCritical = osConfig.theme.signal.critical;
        };
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

      # Fcitx can drop an installed input method from its mutable profile when
      # the daemon is restarted while the addon set is being rebuilt. Keep the
      # user's other groups/items intact and restore only the missing Unikey item.
      fcitxUnikeyProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        profile="${config.xdg.configHome}/fcitx5/profile"
        if [ -f "$profile" ] && ! ${pkgs.gnugrep}/bin/grep -Fqx 'Name=unikey' "$profile"; then
          temporary="$(${pkgs.coreutils}/bin/mktemp "$(${pkgs.coreutils}/bin/dirname "$profile")/.fcitx5-profile.XXXXXX")"
          if ${pkgs.gawk}/bin/awk '
            BEGIN { max = -1; inserted = 0 }
            /^\[Groups\/0\/Items\/[0-9]+\]$/ {
              item = $0
              sub(/^\[Groups\/0\/Items\//, "", item)
              sub(/\]$/, "", item)
              if ((item + 0) > max) max = item + 0
            }
            /^\[GroupOrder\]$/ && !inserted && max >= 0 {
              print "[Groups/0/Items/" (max + 1) "]"
              print "# Name"
              print "Name=unikey"
              print "# Layout"
              print "Layout="
              print ""
              inserted = 1
            }
            { print }
            END { exit !inserted }
          ' "$profile" > "$temporary"; then
            run ${pkgs.coreutils}/bin/install -m 0600 "$temporary" "$profile"
          fi
          run ${pkgs.coreutils}/bin/rm -f "$temporary"
        fi
      '';
    };
  };

  xdg.configFile = {
    "hypr/hyprland.conf".text = renderHostConfig ../../hosts/think14gryzen/assets/hypr/hyprland.conf;
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

    services = {
      hyprpaper = {
        Unit = {
          Description = "Hyprland wallpaper daemon";
          After = [ "hyprland-session.target" ];
          PartOf = [ "hyprland-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.hyprpaper}/bin/hyprpaper";
          Restart = "on-failure";
          RestartSec = "2s";
        };
        Install.WantedBy = [ "hyprland-session.target" ];
      };

      dunst = {
        Unit = {
          Description = "Dunst notification daemon";
          After = [ "hyprland-session.target" ];
          PartOf = [ "hyprland-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.dunst}/bin/dunst";
          Restart = "on-failure";
          RestartSec = "2s";
        };
        Install.WantedBy = [ "hyprland-session.target" ];
      };

      fcitx5 = {
        Unit = {
          Description = "Fcitx 5 input method daemon";
          After = [ "hyprland-session.target" ];
          PartOf = [ "hyprland-session.target" ];
        };
        Service = {
          ExecStart = "${osConfig.i18n.inputMethod.package}/bin/fcitx5 -r";
          Restart = "on-failure";
          RestartSec = "2s";
        };
        Install.WantedBy = [ "hyprland-session.target" ];
      };

      sxhkd = {
        Unit = {
          Description = "Simple X hotkey daemon";
          ConditionPathExists = "${config.xdg.configHome}/sxhkd/sxhkdrc";
          After = [ "hyprland-session.target" ];
          PartOf = [ "hyprland-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.sxhkd}/bin/sxhkd -c ${config.xdg.configHome}/sxhkd/sxhkdrc";
          Restart = "on-failure";
          RestartSec = "2s";
        };
        Install.WantedBy = [ "hyprland-session.target" ];
      };

      udiskie = {
        Unit = {
          Description = "Udiskie removable-device tray";
          After = [ "hyprland-session.target" ];
          PartOf = [ "hyprland-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.udiskie}/bin/udiskie --tray";
          Restart = "on-failure";
          RestartSec = "2s";
        };
        Install.WantedBy = [ "hyprland-session.target" ];
      };

      blueman-applet = {
        Unit = {
          Description = "Blueman Bluetooth applet";
          After = [ "hyprland-session.target" ];
          PartOf = [ "hyprland-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.blueman}/bin/blueman-applet";
          Restart = "on-failure";
          RestartSec = "2s";
        };
        Install.WantedBy = [ "hyprland-session.target" ];
      };

      cliphist = {
        Unit = {
          Description = "Wayland clipboard history watcher";
          After = [ "hyprland-session.target" ];
          PartOf = [ "hyprland-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store -max-items 100";
          Restart = "on-failure";
          RestartSec = "2s";
        };
        Install.WantedBy = [ "hyprland-session.target" ];
      };
    };
  };

}
