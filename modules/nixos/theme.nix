{
  lib,
  config,
  ...
}:
let
  themeDefaults = import ../../theme/default.nix;
  hexColor = lib.types.strMatching "^#[0-9a-fA-F]{6}$";
in
{
  options.theme = {
    colors = lib.mkOption {
      type = lib.types.submodule {
        options = {
          base = lib.mkOption {
            type = hexColor;
            default = themeDefaults.colors.base;
            description = "Base background color.";
          };
          mantle = lib.mkOption {
            type = hexColor;
            default = themeDefaults.colors.mantle;
            description = "Elevated surface background.";
          };
          text = lib.mkOption {
            type = hexColor;
            default = themeDefaults.colors.text;
            description = "Primary foreground text.";
          };
          subtext = lib.mkOption {
            type = hexColor;
            default = themeDefaults.colors.subtext;
            description = "Secondary/muted text.";
          };
          accent = lib.mkOption {
            type = hexColor;
            default = themeDefaults.colors.accent;
            description = "Primary accent color.";
          };
          success = lib.mkOption {
            type = hexColor;
            default = themeDefaults.colors.success;
            description = "Success state color.";
          };
          warning = lib.mkOption {
            type = hexColor;
            default = themeDefaults.colors.warning;
            description = "Warning state color.";
          };
          error = lib.mkOption {
            type = hexColor;
            default = themeDefaults.colors.error;
            description = "Error state color.";
          };
          purple = lib.mkOption {
            type = hexColor;
            default = themeDefaults.colors.purple;
            description = "Secondary accent: purple.";
          };
          cyan = lib.mkOption {
            type = hexColor;
            default = themeDefaults.colors.cyan;
            description = "Secondary accent: cyan.";
          };
        };
      };
      default = themeDefaults.colors;
      description = "Shared system color palette";
    };

    fonts = lib.mkOption {
      type = lib.types.submodule {
        options = {
          ui = lib.mkOption {
            type = lib.types.submodule {
              options = {
                family = lib.mkOption {
                  type = lib.types.str;
                  default = themeDefaults.fonts.ui.family;
                  description = "Default UI font family for launcher and bar surfaces.";
                };
                size = lib.mkOption {
                  type = lib.types.int;
                  default = themeDefaults.fonts.ui.size;
                  description = "Default UI font size.";
                };
              };
            };
            default = themeDefaults.fonts.ui;
          };

          mono = lib.mkOption {
            type = lib.types.submodule {
              options = {
                family = lib.mkOption {
                  type = lib.types.str;
                  default = themeDefaults.fonts.mono.family;
                  description = "Default monospace font family.";
                };
                size = lib.mkOption {
                  type = lib.types.int;
                  default = themeDefaults.fonts.mono.size;
                  description = "Default monospace font size.";
                };
              };
            };
            default = themeDefaults.fonts.mono;
          };

          lock = lib.mkOption {
            type = lib.types.submodule {
              options = {
                family = lib.mkOption {
                  type = lib.types.str;
                  default = themeDefaults.fonts.lock.family;
                  description = "Lockscreen primary font family.";
                };
                boldFamily = lib.mkOption {
                  type = lib.types.str;
                  default = themeDefaults.fonts.lock.boldFamily;
                  description = "Lockscreen bold font family.";
                };
                clockSize = lib.mkOption {
                  type = lib.types.int;
                  default = themeDefaults.fonts.lock.clockSize;
                  description = "Lockscreen clock font size.";
                };
                textSize = lib.mkOption {
                  type = lib.types.int;
                  default = themeDefaults.fonts.lock.textSize;
                  description = "Lockscreen supporting text size.";
                };
              };
            };
            default = themeDefaults.fonts.lock;
          };
        };
      };
      default = themeDefaults.fonts;
      description = "Shared font settings for themed surfaces.";
    };

    cursor = lib.mkOption {
      type = lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            default = themeDefaults.cursor.name;
            description = "Cursor theme name.";
          };
          size = lib.mkOption {
            type = lib.types.int;
            default = themeDefaults.cursor.size;
            description = "Cursor size.";
          };
        };
      };
      default = themeDefaults.cursor;
      description = "Shared cursor settings.";
    };

    wallpaper = lib.mkOption {
      type = lib.types.submodule {
        options = {
          source = lib.mkOption {
            type = lib.types.path;
            default = themeDefaults.wallpaper.source;
            description = "Default wallpaper asset path.";
          };
          name = lib.mkOption {
            type = lib.types.str;
            default = themeDefaults.wallpaper.name;
            description = "Wallpaper asset filename in the themed config directory.";
          };
        };
      };
      default = themeDefaults.wallpaper;
      description = "Wallpaper asset settings.";
    };

    runtime = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = themeDefaults.runtime.enable;
            description = "Enable runtime palette generation.";
          };
          cacheDir = lib.mkOption {
            type = lib.types.str;
            default = themeDefaults.runtime.cacheDir;
            description = "User-home-relative cache directory for runtime theme state.";
          };
        };
      };
      default = themeDefaults.runtime;
      description = "Runtime theme generation settings.";
    };
  };

  config.console =
    let
      c = config.theme.colors;
    in
    {
      font = "Lat2-Terminus16";
      colors = [
        (lib.removePrefix "#" c.base)
        (lib.removePrefix "#" c.error)
        (lib.removePrefix "#" c.success)
        (lib.removePrefix "#" c.warning)
        (lib.removePrefix "#" c.accent)
        (lib.removePrefix "#" c.purple)
        (lib.removePrefix "#" c.cyan)
        "b1b8c0"
        "6e7681"
        (lib.removePrefix "#" c.error)
        (lib.removePrefix "#" c.success)
        (lib.removePrefix "#" c.warning)
        (lib.removePrefix "#" c.accent)
        (lib.removePrefix "#" c.purple)
        (lib.removePrefix "#" c.cyan)
        (lib.removePrefix "#" c.text)
      ];
    };
}
