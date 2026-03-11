{ lib, ... }:
{
  options.theme = {
    colors = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        base = "#0d1117";
        mantle = "#161b22";
        text = "#f0f6fc";
        subtext = "#8b949e";
        accent = "#58a6ff";
        success = "#3fb950";
        warning = "#d29922";
        error = "#f85149";
        purple = "#bc8cff";
        cyan = "#39c5cf";
      };
      description = "Shared system color palette";
    };
  };
}
