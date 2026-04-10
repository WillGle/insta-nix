{ config, osConfig, ... }:
let
  homeDir = config.home.homeDirectory;
  themeFallbackDir = "${config.xdg.configHome}/theme/fallback";
  themeRuntimeDir = "${config.xdg.configHome}/theme/runtime";
  renderHostConfig =
    path:
    builtins.replaceStrings
      [
        "/home/will"
        "__CURSOR_NAME__"
        "__CURSOR_SIZE__"
        "__THEME_FALLBACK_DIR__"
        "__THEME_RUNTIME_DIR__"
      ]
      [
        homeDir
        osConfig.theme.cursor.name
        (toString osConfig.theme.cursor.size)
        themeFallbackDir
        themeRuntimeDir
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
    ".local/bin/waybar-atomic-note" = {
      source = ../../dotfiles/hosts/ryzen14/local-bin/waybar-atomic-note;
      executable = true;
    };
    ".local/bin/waybar-memory-info" = {
      source = ../../dotfiles/hosts/ryzen14/local-bin/waybar-memory-info;
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
  };
}
