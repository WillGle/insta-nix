{ config, lib, pkgs, ... }:
{
  services.xserver = {
    enable = true;
    xkb.layout = "us";
  };

  programs.hyprland.enable = true;
  services.displayManager.sessionPackages = [ pkgs.hyprland ];
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "sugar-dark";
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
      addons = with pkgs; [ qt6Packages.fcitx5-unikey fcitx5-bamboo fcitx5-gtk ];
      waylandFrontend = true;
    };
  };

  # Session/UI variables (cursor and Qt scaling).
  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
    QT_FONT_DPI = "144";
    QT_SCALE_FACTOR = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "0";
    XMODIFIERS = "@im=fcitx";
  };
}
