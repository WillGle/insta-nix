{ lib, ... }:
let
  hexColor = lib.types.strMatching "^#[0-9a-fA-F]{6}$";
in
{
  options.theme = {
    colors = lib.mkOption {
      type = lib.types.submodule {
        options = {
          base = lib.mkOption {
            type = hexColor;
            default = "#0d1117";
            description = "Base background color.";
          };
          mantle = lib.mkOption {
            type = hexColor;
            default = "#161b22";
            description = "Elevated surface background.";
          };
          text = lib.mkOption {
            type = hexColor;
            default = "#f0f6fc";
            description = "Primary foreground text.";
          };
          subtext = lib.mkOption {
            type = hexColor;
            default = "#8b949e";
            description = "Secondary/muted text.";
          };
          accent = lib.mkOption {
            type = hexColor;
            default = "#58a6ff";
            description = "Primary accent color.";
          };
          success = lib.mkOption {
            type = hexColor;
            default = "#3fb950";
            description = "Success state color.";
          };
          warning = lib.mkOption {
            type = hexColor;
            default = "#d29922";
            description = "Warning state color.";
          };
          error = lib.mkOption {
            type = hexColor;
            default = "#f85149";
            description = "Error state color.";
          };
          purple = lib.mkOption {
            type = hexColor;
            default = "#bc8cff";
            description = "Secondary accent: purple.";
          };
          cyan = lib.mkOption {
            type = hexColor;
            default = "#39c5cf";
            description = "Secondary accent: cyan.";
          };
        };
      };
      default = { };
      description = "Shared system color palette";
    };
  };
}
