{ lib, config, pkgs, pkgsUnstable, ... }:
let
  themeDefaults = import ../../theme/default.nix;
  hexColor = lib.types.strMatching "^#[0-9a-fA-F]{6}$";
  hasThemeColors = config ? theme && config.theme ? colors;
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

  config = {
    assertions = [
      {
        assertion = hasThemeColors;
        message = "profiles/shared/base.nix requires theme.colors.";
      }
    ];

    # Locale / Time
    time.timeZone = "Asia/Ho_Chi_Minh";
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "vi_VN";
      LC_IDENTIFICATION = "vi_VN";
      LC_MEASUREMENT = "vi_VN";
      LC_MONETARY = "vi_VN";
      LC_NAME = "vi_VN";
      LC_NUMERIC = "vi_VN";
      LC_PAPER = "vi_VN";
      LC_TELEPHONE = "vi_VN";
      LC_TIME = "vi_VN";
    };

    # Core Nix settings
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = lib.mkAfter [ "https://cache.nixos.org" ];
      trusted-public-keys = lib.mkAfter [
        "cache.nixos.org-1:6NCHdD59X3yjrwW3CvkxuV2L0GyGq5qF5S727Z6IQkQ="
      ];
      auto-optimise-store = true;
      max-jobs = "auto";
      cores = 0;
      keep-outputs = true;
      keep-derivations = true;
    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    nixpkgs.config.allowUnfree = true;

    console = lib.mkIf hasThemeColors (
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
      }
    );

    # Shared connectivity defaults
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
    };

    networking = {
      networkmanager = {
        enable = true;
        dns = "systemd-resolved";
        settings = {
          connection = {
            "ipv4.route-metric" = 50;
            "ipv6.route-metric" = 50;
          };
        };
      };

      firewall.enable = true;
      resolvconf.enable = false;
    };

    services = {
      blueman.enable = true;

      resolved = {
        enable = true;
        dnssec = "allow-downgrade";
        dnsovertls = "opportunistic";
        llmnr = "false";
        fallbackDns = [
          "1.1.1.1"
          "8.8.8.8"
        ];
        extraConfig = ''
          DNS=1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4
          MulticastDNS=no
        '';
      };

      # Shared system services across hosts.
      dbus.enable = true;
      flatpak.enable = true;
      upower.enable = true;
      udev.enable = true;
      acpid.enable = true;
      udisks2.enable = true;
      gvfs.enable = true;
      tailscale.enable = true;
    };

    security.polkit.enable = true;
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      fuse3
      icu
      nss
      openssl
      curl
      expat
    ];

    environment.etc."resolv.conf".source = "/run/systemd/resolve/stub-resolv.conf";

    system.stateVersion = "25.11";
  };
}
