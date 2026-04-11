{ config, osConfig, ... }:
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
      source = ../../dotfiles/hosts/ryzen14/local-bin/atomic-note;
      executable = true;
    };
    ".local/bin/monitor-setup" = {
      source = ../../dotfiles/hosts/ryzen14/local-bin/monitor-setup;
      executable = true;
    };
    ".local/bin/rofi-network" = {
      source = ../../dotfiles/hosts/ryzen14/local-bin/rofi-network;
      executable = true;
    };
    ".local/bin/rofi-screen-time" = {
      source = ../../dotfiles/hosts/ryzen14/local-bin/rofi-screen-time;
      executable = true;
    };
    ".local/bin/rofi-screen-time-stats" = {
      source = ../../dotfiles/hosts/ryzen14/local-bin/rofi-screen-time-stats;
      executable = true;
    };
    ".local/bin/rofi-screen-time-track" = {
      source = ../../dotfiles/hosts/ryzen14/local-bin/rofi-screen-time-track;
      executable = true;
    };
    ".local/bin/study-timer" = {
      source = ../../dotfiles/hosts/ryzen14/local-bin/study-timer;
      executable = true;
    };
    ".local/bin/waybar-memory-info" = {
      source = ../../dotfiles/hosts/ryzen14/local-bin/waybar-memory-info;
      executable = true;
    };
    ".local/bin/waybar-network-info" = {
      source = ../../dotfiles/hosts/ryzen14/local-bin/waybar-network-info;
      executable = true;
    };
    ".local/bin/waybar-power-monitor" = {
      source = ../../dotfiles/hosts/ryzen14/local-bin/waybar-power-monitor;
      executable = true;
    };
    ".local/bin/waybar-refresh-label" = {
      source = ../../dotfiles/hosts/ryzen14/local-bin/waybar-refresh-label;
      executable = true;
    };
    ".local/bin/waybar-refresh-toggle" = {
      source = ../../dotfiles/hosts/ryzen14/local-bin/waybar-refresh-toggle;
      executable = true;
    };
  };

  xdg.configFile = {
    "hypr/hyprland.conf".text = renderHostConfig ../../dotfiles/hosts/ryzen14/hypr/hyprland.conf;
    "hypr/hypridle.conf".source = ../../dotfiles/hosts/ryzen14/hypr/hypridle.conf;
    "hypr/autostart.conf" = {
      source = ../../dotfiles/hosts/ryzen14/hypr/autostart.conf;
      executable = true;
    };
    "hypr/toggle_waybar.sh" = {
      source = ../../dotfiles/hosts/ryzen14/hypr/toggle_waybar.sh;
      executable = true;
    };
    "hypr/rotate_select.sh" = {
      source = ../../dotfiles/hosts/ryzen14/hypr/rotate_select.sh;
      executable = true;
    };

    "kanshi/config".source = ../../dotfiles/hosts/ryzen14/kanshi/config;
    "rofi/screen-time.rasi".source = ../../dotfiles/common/rofi/screen-time.rasi;
  };

  systemd.user.services.rofi-screen-time-tracker = {
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
    ".local/bin/rofi-study-timer" = {
      source = ../../dotfiles/hosts/ryzen14/local-bin/rofi-study-timer;
      executable = true;
    };
