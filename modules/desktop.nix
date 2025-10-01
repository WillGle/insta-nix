{ pkgs, ... }:
{
  # XKB layout
  services.xserver = {
    enable = true;
    xkb = { layout = "us"; variant = ""; };
  };

  # Hyprland + SDDM
  programs.hyprland.enable = true;
  services.displayManager.sessionPackages = [ pkgs.hyprland ];
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "sugar-dark";
  };
  services.displayManager.defaultSession = "hyprland";

  # XDG portals (ưu tiên hyprland + gtk) như bản gốc
  xdg.portal = {
    enable = true;
    wlr.enable = false;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config = {
      common.default = [ "hyprland" "gtk" ];
    };
  };

  # Input method (fcitx5 + addons đúng như bản gốc)
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-unikey
      fcitx5-configtool
      fcitx5-gtk
      libsForQt5.fcitx5-qt
      qt6Packages.fcitx5-qt
    ];
  };
}
