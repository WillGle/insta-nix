{ lib, ... }:
{
  options.theme = {
    colors = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        base = "#001f3f"; # Navy Blue (Background)
        mantle = "#004080"; # Lighter Navy (Secondary Background)
        text = "#ffffff"; # White
        subtext = "#a0a0a0"; # Grey
        accent = "#ffff00"; # Yellow (Highlight)
        success = "#00ff00"; # Green
        warning = "#ff8000"; # Orange
        error = "#ff0000"; # Red
        purple = "#c678dd"; # Purple (Extra)
      };
      description = "System color palette";
    };
  };
}
