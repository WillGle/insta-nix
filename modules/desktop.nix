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
    type = "fcitx5";
    enable = true;
    fcitx5 = {
      addons = with pkgs; [ fcitx5-unikey fcitx5-bamboo fcitx5-gtk ];
      waylandFrontend = true;
    };
  };

  environment.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
  };
}
