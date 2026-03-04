_: {
  home.file = {
    ".local/bin/atomic-note" = {
      source = ../../dotfiles/hosts/ryzen14/local-bin/atomic-note;
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
    "hypr/hyprland.conf".source = ../../dotfiles/hosts/ryzen14/hypr/hyprland.conf;
    "hypr/hyprpaper.conf".source = ../../dotfiles/hosts/ryzen14/hypr/hyprpaper.conf;
    "hypr/hyprlock.conf".source = ../../dotfiles/hosts/ryzen14/hypr/hyprlock.conf;
    "hypr/hypridle.conf".source = ../../dotfiles/hosts/ryzen14/hypr/hypridle.conf;
    "hypr/wallpaper.png".source = ../../dotfiles/hosts/ryzen14/hypr/wallpaper.png;
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
