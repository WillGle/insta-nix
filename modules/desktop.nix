{ pkgs, ... }:

{
  services = {
    xserver = {
      enable = true;
      xkb.layout = "us";
    };

    hypridle.enable = true;

    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
        theme = "sddm-astronaut-theme";
        extraPackages = with pkgs; [
          kdePackages.qtmultimedia
          kdePackages.qtsvg
          kdePackages.qtvirtualkeyboard
          kdePackages.qt5compat
          sddm-astronaut
        ];
      };
      defaultSession = "hyprland";
    };
  };

  programs.hyprland = {
    enable = true;
    # package = inputs.hyprland.packages.${pkgs.system}.hyprland; # Use if using flake input
    # portalPackage = inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland; # Use if using flake input
  };

  xdg.portal = {
    enable = true;
    wlr.enable = false;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config.common.default = [
      "hyprland"
      "gtk"
    ];
  };

  # ───────── Input Method (Vietnamese) ─────────
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = with pkgs; [
        qt6Packages.fcitx5-unikey
        fcitx5-gtk
        libsForQt5.fcitx5-qt
      ];
      waylandFrontend = true;
    };
  };

}
