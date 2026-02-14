{
  pkgs,
  lib,
  config,
  ...
}:
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
}
