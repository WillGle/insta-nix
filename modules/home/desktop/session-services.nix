{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  themeApplyPath = "${config.xdg.configHome}/theme/theme-apply";
in
{
  systemd.user.services = {
    theme-apply = lib.mkIf osConfig.theme.runtime.enable {
      Unit = {
        Description = "Generate runtime theme palette for core Wayland surfaces";
      };
      Service = {
        Type = "oneshot";
        # Absolute interpreter: the unit starts with an empty PATH, so a
        # `/usr/bin/env bash` shebang would fail before the script runs.
        ExecStart = "${pkgs.bash}/bin/bash ${themeApplyPath}";
        TimeoutStartSec = "120s";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    polkit-agent = {
      Unit = {
        Description = "Polkit Authentication Agent";
        After = [ "hyprland-session.target" ];
        PartOf = [ "hyprland-session.target" ];
        StartLimitBurst = 3;
        StartLimitIntervalSec = "30s";
      };
      Service = {
        ExecStart = "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent";
        Restart = "on-failure";
        RestartSec = "3s";
        RestartPreventExitStatus = [ "SIGABRT" ];
      };
      Install = {
        WantedBy = [ "hyprland-session.target" ];
      };
    };

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
}
