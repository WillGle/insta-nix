{ config, lib, pkgs, ... }:
{
  services.xserver = {
    enable = true;
    xkb.layout = "us";
  };

  programs.hyprland.enable = true;
  programs.hyprlock.enable = true;
  services.hypridle.enable = true;
  services.displayManager.sessionPackages = [ pkgs.hyprland ];
  services.displayManager.sddm = {
    enable = true;
    package = pkgs.kdePackages.sddm;
    wayland.enable = true;
    theme = "sddm-astronaut-theme";
    extraPackages = with pkgs; [
      kdePackages.qtmultimedia
      kdePackages.qtsvg
      kdePackages.qtvirtualkeyboard
      kdePackages.qt5compat
    ];
  };
  services.displayManager.defaultSession = "hyprland";

  xdg.portal = {
    enable = true;
    wlr.enable = false;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config.common.default = [ "hyprland" "gtk" ];
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = with pkgs; [ 
        qt6Packages.fcitx5-unikey 
        fcitx5-bamboo 
        fcitx5-gtk 
        libsForQt5.fcitx5-qt 
      ];
      waylandFrontend = true;
    };
  };

  # Session/UI variables (Qt scaling).
  environment.sessionVariables = {
    QT_FONT_DPI = "144";
    QT_SCALE_FACTOR = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "0";
  };
}
