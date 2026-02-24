{ pkgs, lib, ... }:
{
  options.theme = {
    colors = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        base = "#0d1117"; # Deep GitHub Dark Dimmed
        mantle = "#161b22"; # Darker Mantle for contrast
        text = "#f0f6fc"; # Crisp White
        subtext = "#8b949e"; # Clear Grey
        accent = "#58a6ff"; # Bright Blue
        success = "#3fb950"; # Vivid Green
        warning = "#d29922"; # Deep Gold
        error = "#f85149"; # Vivid Red
        purple = "#bc8cff"; # Bright Purple
      };
      description = "System color palette";
    };
  };

  config = {
    # Centralized UI Metadata
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

    # Session/UI variables (Qt scaling).
    environment.sessionVariables = {
      QT_FONT_DPI = "144";
      QT_SCALE_FACTOR = "1";
      QT_AUTO_SCREEN_SCALE_FACTOR = "0";
    };
  };
}
