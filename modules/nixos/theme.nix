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
      description = ''
        Shared decorative color palette. Overwritten at runtime by the
        wallpaper-driven generator, so it must never be used to encode a state,
        a severity or an indicator line — use {option}`theme.signal` for that.
      '';
    };

    signal = lib.mkOption {
      type = lib.types.submodule {
        options = {
          ok = lib.mkOption {
            type = hexColor;
            default = themeDefaults.signal.ok;
            description = "Signal: healthy / lowest severity step.";
          };
          notice = lib.mkOption {
            type = hexColor;
            default = themeDefaults.signal.notice;
            description = "Signal: informational / moderate severity step.";
          };
          warning = lib.mkOption {
            type = hexColor;
            default = themeDefaults.signal.warning;
            description = "Signal: warning severity step.";
          };
          critical = lib.mkOption {
            type = hexColor;
            default = themeDefaults.signal.critical;
            description = "Signal: critical severity step and error states.";
          };
          eco = lib.mkOption {
            type = hexColor;
            default = themeDefaults.signal.eco;
            description = "Signal: charging / actively-good state, brightest token.";
          };
          muted = lib.mkOption {
            type = hexColor;
            default = themeDefaults.signal.muted;
            description = "Signal: idle / disconnected / disabled state.";
          };
        };
      };
      default = themeDefaults.signal;
      description = ''
        Protected signal palette: the only colors permitted to encode state,
        severity or an indicator line. Never touched by the runtime
        wallpaper-driven theme generator.
      '';
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

          rofi = lib.mkOption {
            type = lib.types.submodule {
              options = {
                size = lib.mkOption {
                  type = lib.types.int;
                  default = themeDefaults.fonts.rofi.size;
                  description = ''
                    Rofi font size in Pango points. Deliberately not shared with
                    {option}`theme.fonts.ui.size`, which Waybar consumes as CSS
                    pixels — the same number means a ~30% larger glyph here.
                  '';
                };
              };
            };
            default = themeDefaults.fonts.rofi;
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

  # Two signal tokens sharing a value silently merges two distinct meanings on
  # the same indicator line, which is exactly the failure the split is meant to
  # prevent. Catch it at build time rather than on the bar.
  config.assertions =
    let
      s = config.theme.signal;
      names = [
        "ok"
        "notice"
        "warning"
        "critical"
        "eco"
        "muted"
      ];
      pairs = lib.concatMap (
        a: map (b: { inherit a b; }) (lib.remove a names)
      ) names;
      unordered = lib.filter (p: p.a < p.b) pairs;
    in
    map (p: {
      assertion = s.${p.a} != s.${p.b};
      message = "theme.signal.${p.a} and theme.signal.${p.b} are both ${s.${p.a}}; every signal color must stay distinct.";
    }) unordered;

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
